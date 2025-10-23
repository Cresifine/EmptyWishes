import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'auth_service.dart';
import '../models/wish.dart';
import 'progress_update_service.dart';

class SyncService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Sync all pending wishes to backend
  static Future<bool> syncPendingWishes() async {
    try {
      print('[SyncService] Starting sync of pending wishes');
      final token = await StorageService.getToken();
      if (token == null) {
        print('[SyncService] No token available, cannot sync');
        return false;
      }

      final pendingWishes = await StorageService.getPendingWishes();
      if (pendingWishes == null || pendingWishes.isEmpty) {
        print('[SyncService] No pending wishes to sync');
        return true;
      }

      print('[SyncService] Found ${pendingWishes.length} pending wishes to sync');
      bool allSynced = true;
      int syncedCount = 0;
      for (var wish in pendingWishes) {
        final synced = await _syncSingleWish(wish, token);
        if (synced) {
          syncedCount++;
        } else {
          allSynced = false;
        }
      }

      if (allSynced) {
        await StorageService.clearPendingWishes();
        print('[SyncService] Successfully synced all $syncedCount wishes');
      } else {
        print('[SyncService] Partially synced $syncedCount/${pendingWishes.length} wishes');
      }

      return allSynced;
    } catch (e, stackTrace) {
      print('[SyncService] Sync error: $e');
      print('[SyncService] Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<bool> _syncSingleWish(Map<String, dynamic> wish, String token) async {
    try {
      final localId = wish['id'];
      print('[SyncService] Syncing wish: ${wish['title']} (local ID: $localId)');
      
      // Backend expects Form data, not JSON
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/wishes'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = wish['title'] ?? '';
      request.fields['description'] = wish['description'] ?? '';
      
      if (wish['target_date'] != null) {
        request.fields['target_date'] = wish['target_date'];
      }
      
      if (wish['consequence'] != null && wish['consequence'].toString().isNotEmpty) {
        request.fields['consequence'] = wish['consequence'];
      }

      // Add local cover image if exists
      if (wish['local_cover_image'] != null) {
        final coverImagePath = wish['local_cover_image'];
        final coverImageFile = File(coverImagePath);
        
        if (await coverImageFile.exists()) {
          print('[SyncService] Adding cover image to sync: $coverImagePath');
          final fileStream = http.ByteStream(coverImageFile.openRead());
          final fileLength = await coverImageFile.length();
          final fileName = coverImagePath.split('/').last;
          
          final multipartFile = http.MultipartFile(
            'cover_image',
            fileStream,
            fileLength,
            filename: fileName,
          );
          request.files.add(multipartFile);
        } else {
          print('[SyncService] Local cover image not found: $coverImagePath');
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final backendId = responseData['id'];
        
        print('[SyncService] Successfully synced wish: ${wish['title']}');
        print('[SyncService] Local ID: $localId → Backend ID: $backendId');
        
        // Update progress updates that reference the old local ID
        await _updateProgressUpdateWishIds(localId, backendId);
        
        return true;
      } else {
        print('[SyncService] Failed to sync wish: ${wish['title']}, Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('[SyncService] Error syncing wish: ${wish['title']}, Error: $e');
      print('[SyncService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update progress updates to use the new backend wish ID
  static Future<void> _updateProgressUpdateWishIds(int oldLocalId, int newBackendId) async {
    try {
      final pendingUpdates = await StorageService.getPendingProgressUpdates();
      if (pendingUpdates == null || pendingUpdates.isEmpty) return;
      
      int updatedCount = 0;
      for (var update in pendingUpdates) {
        if (update['wish_id'] == oldLocalId) {
          update['wish_id'] = newBackendId;
          updatedCount++;
        }
      }
      
      if (updatedCount > 0) {
        await StorageService.savePendingProgressUpdates(pendingUpdates);
        print('[SyncService] Updated $updatedCount progress updates from wish ID $oldLocalId to $newBackendId');
      }
    } catch (e) {
      print('[SyncService] Error updating progress update wish IDs: $e');
    }
  }

  // Add wish to pending sync queue
  static Future<void> addToPendingSync(Map<String, dynamic> wish) async {
    final pending = await StorageService.getPendingWishes() ?? [];
    pending.add({
      ...wish,
      'sync_status': 'pending',
      'created_at_local': DateTime.now().toIso8601String(),
    });
    await StorageService.savePendingWishes(pending);
  }

  // Check if user is online
  static Future<bool> isOnline() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(
        const Duration(seconds: 3),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Background sync - called periodically
  static Future<void> backgroundSync() async {
    print('[SyncService] Starting background sync');
    final hasToken = await StorageService.hasToken();
    if (!hasToken) {
      print('[SyncService] No token, skipping sync');
      return;
    }
    
    final online = await isOnline();
    print('[SyncService] Online status: $online');
    if (online) {
      print('[SyncService] Syncing wishes...');
      await syncPendingWishes();
      print('[SyncService] Syncing progress updates...');
      await ProgressUpdateService.syncPendingUpdates();
      print('[SyncService] Background sync complete');
    }
  }

  // Fetch wishes from backend
  static Future<List<Map<String, dynamic>>?> fetchWishesFromBackend({String? status}) async {
    try {
      print('[SyncService] Fetching wishes from backend' + (status != null ? ' with status: $status' : ''));
      final token = await StorageService.getToken();
      if (token == null) {
        print('[SyncService] No token available for fetching wishes');
        return null;
      }

      final uri = status != null
          ? Uri.parse('$baseUrl/api/wishes?status_filter=$status')
          : Uri.parse('$baseUrl/api/wishes');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final wishes = data.map((w) => w as Map<String, dynamic>).toList();
        print('[SyncService] Successfully fetched ${wishes.length} wishes from backend');
        
        // Cache for offline use - merge with existing cache instead of replacing
        if (status != null) {
          // If fetching specific status, merge with existing cache
          final existingCache = await StorageService.getCachedWishes() ?? [];
          // Remove old wishes with same status
          final filteredCache = existingCache.where((w) => w['status'] != status).toList();
          // Add new wishes
          final mergedCache = [...filteredCache, ...wishes];
          await StorageService.cacheWishes(mergedCache);
          print('[SyncService] Merged ${wishes.length} wishes into cache (total: ${mergedCache.length})');
        } else {
          // If fetching all wishes, replace entire cache
          await StorageService.cacheWishes(wishes);
          print('[SyncService] Cached ${wishes.length} wishes');
        }
        
        return wishes;
      } else {
        print('[SyncService] Failed to fetch wishes: Status ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('[SyncService] Fetch error: $e');
      print('[SyncService] Stack trace: $stackTrace');
      // Return cached data if offline
      print('[SyncService] Falling back to cached wishes');
      return await StorageService.getCachedWishes();
    }
  }

  // Helper to get pending wishes (returns Wish objects)
  static Future<List<Wish>> getPendingWishesAsList() async {
    final pending = await StorageService.getPendingWishes();
    if (pending == null) return [];
    return pending.map((json) => Wish.fromJson(json)).toList();
  }
}

