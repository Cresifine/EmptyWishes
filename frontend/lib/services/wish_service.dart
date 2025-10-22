import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'storage_service.dart';
import 'sync_service.dart';
import '../models/wish.dart';

class WishService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  // Create wish (online with file upload or offline)
  static Future<bool> createWish({
    required String title,
    required String description,
    DateTime? targetDate,
    String? consequence,
    File? coverImage,
  }) async {
    try {
      final hasToken = await StorageService.hasToken();
      final online = await SyncService.isOnline();
      
      // If online with token and has cover image, upload directly
      if (online && hasToken && coverImage != null) {
        final token = await StorageService.getToken();
        if (token != null) {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/api/wishes'),
          );

          request.headers['Authorization'] = 'Bearer $token';
          request.fields['title'] = title;
          request.fields['description'] = description;
          if (targetDate != null) {
            request.fields['target_date'] = targetDate.toIso8601String();
          }
          if (consequence != null && consequence.isNotEmpty) {
            request.fields['consequence'] = consequence;
          }

          // Add cover image file
          final fileStream = http.ByteStream(coverImage.openRead());
          final fileLength = await coverImage.length();
          final multipartFile = http.MultipartFile(
            'cover_image',
            fileStream,
            fileLength,
            filename: coverImage.path.split('/').last,
          );
          request.files.add(multipartFile);

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 201) {
            print('[WishService] Successfully created wish with cover image');
            return true;
          } else {
            print('[WishService] Failed to create wish: ${response.body}');
          }
        }
      }
      
      // Fallback to offline-first approach (without image for now)
      final wishData = {
        'title': title,
        'description': description,
        'target_date': targetDate?.toIso8601String(),
        'consequence': consequence,
        'progress': 0,
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
        'id': DateTime.now().millisecondsSinceEpoch, // Temporary local ID
      };

      // Always store locally first
      await SyncService.addToPendingSync(wishData);
      
      // Try to sync if online and has token
      if (hasToken && online) {
        // Sync in background, don't wait for result
        SyncService.syncPendingWishes();
      }
      
      return true;
    } catch (e) {
      print('Error creating wish: $e');
      return false;
    }
  }

  // Get all wishes (offline-first)
  static Future<List<Wish>> getWishesByStatus(String status) async {
    final isOnline = await SyncService.isOnline();
    final isAuthenticated = await StorageService.hasToken();

    if (isOnline && isAuthenticated) {
      final wishData = await SyncService.fetchWishesFromBackend(status: status);
      if (wishData != null) {
        return wishData.map((json) => Wish.fromJson(json)).toList();
      }
    }

    // Offline mode - return cached wishes filtered by status
    final cachedWishes = await StorageService.getCachedWishes() ?? [];
    final pendingWishes = await StorageService.getPendingWishes() ?? [];

    // Convert JSON to Wish objects
    final cachedWishObjects = cachedWishes.map((json) => Wish.fromJson(json)).toList();
    final pendingWishObjects = pendingWishes.map((json) => Wish.fromJson(json)).toList();
    
    // Combine and filter by status
    final List<Wish> allWishes = [...cachedWishObjects, ...pendingWishObjects];
    return allWishes.where((wish) => wish.status == status).toList();
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
      final token = await StorageService.getToken();
      if (token == null) {
        print('[WishService] No token found');
        return false;
      }

      print('[WishService] Marking wish $wishId as failed');
      final response = await http.post(
        Uri.parse('$baseUrl/api/wishes/$wishId/mark-failed'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[WishService] Mark as failed response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[WishService] Successfully marked wish as failed');
        return true;
      } else {
        print('[WishService] Failed to mark wish as failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[WishService] Error marking wish as failed: $e');
      return false;
    }
  }
}

