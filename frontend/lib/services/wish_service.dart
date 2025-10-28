import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'storage_service.dart';
import 'sync_service.dart';
import '../models/wish.dart';

class WishService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Get local storage directory for wish cover images
  static Future<Directory> _getLocalStorageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final wishesDir = Directory('${appDir.path}/wishes');
    if (!await wishesDir.exists()) {
      await wishesDir.create(recursive: true);
    }
    return wishesDir;
  }

  /// Copy cover image to local storage
  static Future<String?> _copyCoverImageToLocalStorage(File? coverImage, int wishId) async {
    if (coverImage == null) return null;
    
    try {
      final storageDir = await _getLocalStorageDir();
      final fileName = path.basename(coverImage.path);
      final localPath = '${storageDir.path}/${wishId}_$fileName';
      final localFile = await coverImage.copy(localPath);
      print('[WishService] Copied cover image to local storage: $localPath');
      return localFile.path;
    } catch (e) {
      print('[WishService] Error copying cover image: $e');
      return null;
    }
  }

  // Create wish (PURELY LOCAL - offline-first approach)
  static Future<bool> createWish({
    required String title,
    required String description,
    DateTime? targetDate,
    String? consequence,
    File? coverImage,
    List<String>? tags,
    bool useMilestones = false,
    List<Map<String, String>>? milestones,
    String visibility = 'public',
    List<int>? verifierIds,
  }) async {
    try {
      print('[WishService] Creating wish locally: $title');
      print('[WishService] DEBUG: useMilestones=$useMilestones, milestones=$milestones');
      
      final wishId = DateTime.now().millisecondsSinceEpoch;
      
      // Copy cover image to local storage if provided
      String? localCoverImagePath;
      if (coverImage != null) {
        localCoverImagePath = await _copyCoverImageToLocalStorage(coverImage, wishId);
      }
      
      // ALWAYS store locally first (offline-first)
      final wishData = {
        'title': title,
        'description': description,
        'target_date': targetDate?.toIso8601String(),
        'consequence': consequence,
        'progress': 0,
        'is_completed': false,
        'status': 'current',
        'created_at': DateTime.now().toIso8601String(),
        'id': wishId, // Temporary local ID
        'local_cover_image': localCoverImagePath, // Store local path
        'tags': tags ?? [],
        'progress_mode': useMilestones ? 'milestone' : 'manual',
        'milestones': milestones ?? [],
        'visibility': visibility,
        'verifier_ids': verifierIds ?? [],
        'synced': false,
      };

      await SyncService.addToPendingSync(wishData);
      print('[WishService] Wish stored locally with ID: $wishId');
      
      // Try to sync in background if online and authenticated
      final hasToken = await StorageService.hasToken();
      final online = await SyncService.isOnline();
      
      if (hasToken && online) {
        print('[WishService] Attempting background sync');
        SyncService.syncPendingWishes(); // Fire and forget
      } else {
        print('[WishService] Offline or not authenticated - will sync later');
      }
      
      return true;
    } catch (e) {
      print('[WishService] Error creating wish: $e');
      return false;
    }
  }

  // Get all wishes (offline-first)
  static Future<List<Wish>> getWishesByStatus(String status) async {
    print('[WishService] Getting wishes by status: $status');
    final isOnline = await SyncService.isOnline();
    final isAuthenticated = await StorageService.hasToken();
    final isOfflineMode = await StorageService.isOfflineMode();

    print('[WishService] Online: $isOnline, Auth: $isAuthenticated, OfflineMode: $isOfflineMode');

    // Always get cached and pending wishes
    final cachedWishes = await StorageService.getCachedWishes() ?? [];
    final pendingWishes = await StorageService.getPendingWishes() ?? [];

    print('[WishService] Cached: ${cachedWishes.length}, Pending: ${pendingWishes.length}');

    // If online and authenticated, fetch fresh data from backend (it will update cache)
    if (isOnline && isAuthenticated && !isOfflineMode) {
      final wishData = await SyncService.fetchWishesFromBackend(status: status);
      if (wishData != null) {
        print('[WishService] Fetched ${wishData.length} wishes from backend');
        // Backend data is already cached by SyncService
        // Merge with pending wishes that haven't synced yet
        final backendWishObjects = wishData.map((json) => Wish.fromJson(json)).toList();
        final pendingWishObjects = pendingWishes
            .where((w) => w['status'] == status && w['synced'] != true)
            .map((json) => Wish.fromJson(json))
            .toList();
        
        return [...backendWishObjects, ...pendingWishObjects];
      }
    }

    // Offline mode or fetch failed - use cached + pending wishes
    print('[WishService] Using cached/pending wishes (offline or fetch failed)');
    final cachedWishObjects = cachedWishes
        .where((w) => w['status'] == status)
        .map((json) => Wish.fromJson(json))
        .toList();
    final pendingWishObjects = pendingWishes
        .where((w) => w['status'] == status)
        .map((json) => Wish.fromJson(json))
        .toList();
    
    final allWishes = [...cachedWishObjects, ...pendingWishObjects];
    print('[WishService] Returning ${allWishes.length} wishes for status $status');
    return allWishes;
  }

  static Future<List<Wish>> getWishes() async {
    final hasToken = await StorageService.hasToken();
    final isOffline = await StorageService.isOfflineMode();
    List<Wish> allWishes = [];

    if (!isOffline && hasToken) {
      // Try to fetch from backend
      final backendWishes = await SyncService.fetchWishesFromBackend();
      if (backendWishes != null) {
        allWishes.addAll(backendWishes.map((w) => Wish.fromJson(w)));
      }
    } else {
      // Return cached wishes if logged in before
      final cachedWishes = await StorageService.getCachedWishes();
      if (cachedWishes != null) {
        allWishes.addAll(cachedWishes.map((w) => Wish.fromJson(w)));
      }
    }

    // Always add pending wishes (local-only)
    final pendingWishes = await StorageService.getPendingWishes();
    if (pendingWishes != null) {
      allWishes.addAll(pendingWishes.map((w) => Wish.fromJson(w)));
    }

    return allWishes;
  }

  static Future<bool> markAsFailed(int wishId) async {
    try {
      final hasToken = await StorageService.hasToken();
      final isOnline = await SyncService.isOnline();
      final isOfflineMode = await StorageService.isOfflineMode();

      print('[WishService] Marking wish $wishId as failed - Online: $isOnline, HasToken: $hasToken, OfflineMode: $isOfflineMode');

      // ALWAYS update locally first (offline-first approach)
      await _updateLocalWishStatus(wishId, 'failed');

      // Try to sync with backend if online and authenticated
      if (isOnline && hasToken && !isOfflineMode) {
        try {
          final token = await StorageService.getToken();
          print('[WishService] Syncing failed status to backend');
          final response = await http.post(
            Uri.parse('$baseUrl/api/wishes/$wishId/mark-failed'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 10));

          print('[WishService] Mark as failed response status: ${response.statusCode}');

          if (response.statusCode == 200) {
            print('[WishService] Successfully synced failed status to backend');
          } else {
            print('[WishService] Failed to sync to backend: ${response.body}');
            // Still return true since we updated locally
          }
        } catch (e) {
          print('[WishService] Error syncing to backend: $e');
          // Still return true since we updated locally
        }
      }

      return true;
    } catch (e) {
      print('[WishService] Error marking wish as failed: $e');
      return false;
    }
  }

  static Future<void> _updateLocalWishStatus(int wishId, String status) async {
    try {
      // Update cached wishes
      final cachedWishes = await StorageService.getCachedWishes();
      if (cachedWishes != null) {
        for (var wish in cachedWishes) {
          if (wish['id'] == wishId) {
            wish['status'] = status;
            if (status == 'failed') {
              wish['is_completed'] = false;
            }
            break;
          }
        }
        await StorageService.cacheWishes(cachedWishes);
        print('[WishService] Updated cached wish status to $status');
      }

      // Update pending wishes
      final pendingWishes = await StorageService.getPendingWishes();
      if (pendingWishes != null) {
        for (var wish in pendingWishes) {
          if (wish['id'] == wishId) {
            wish['status'] = status;
            if (status == 'failed') {
              wish['is_completed'] = false;
            }
            break;
          }
        }
        await StorageService.savePendingWishes(pendingWishes);
        print('[WishService] Updated pending wish status to $status');
      }
    } catch (e) {
      print('[WishService] Error updating local wish status: $e');
    }
  }
}

