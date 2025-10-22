import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'auth_service.dart';
import '../models/wish.dart';

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
      print('[SyncService] Syncing wish: ${wish['title']}');
      final response = await http.post(
        Uri.parse('$baseUrl/api/wishes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': wish['title'],
          'description': wish['description'],
          'target_date': wish['target_date'],
        }),
      );

      if (response.statusCode == 201) {
        print('[SyncService] Successfully synced wish: ${wish['title']}');
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
    final hasToken = await StorageService.hasToken();
    if (!hasToken) return;
    
    final online = await isOnline();
    if (online) {
      await syncPendingWishes();
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
        
        // Cache for offline use
        await StorageService.cacheWishes(wishes);
        
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

