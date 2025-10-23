import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'storage_service.dart';
import 'sync_service.dart';

class ProgressUpdateService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Get local storage directory for progress update files
  static Future<Directory> _getLocalStorageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final progressDir = Directory('${appDir.path}/progress_updates');
    if (!await progressDir.exists()) {
      await progressDir.create(recursive: true);
    }
    return progressDir;
  }

  /// Copy file to local storage and return the new path
  static Future<String> _copyFileToLocalStorage(File file, int wishId, int timestamp) async {
    try {
      final storageDir = await _getLocalStorageDir();
      final fileName = path.basename(file.path);
      final localPath = '${storageDir.path}/${wishId}_${timestamp}_$fileName';
      final localFile = await file.copy(localPath);
      print('[ProgressUpdateService] Copied file to local storage: $localPath');
      return localFile.path;
    } catch (e) {
      print('[ProgressUpdateService] Error copying file: $e');
      return file.path; // Fallback to original path
    }
  }

  static Future<List<Map<String, dynamic>>> getProgressUpdates(int wishId) async {
    try {
      print('[ProgressUpdateService] ===== Fetching progress updates for wish $wishId =====');
      
      final hasToken = await StorageService.hasToken();
      final isOnline = await SyncService.isOnline();
      final isOfflineMode = await StorageService.isOfflineMode();

      print('[ProgressUpdateService] HasToken: $hasToken, IsOnline: $isOnline, IsOfflineMode: $isOfflineMode');

      // If online and authenticated, try to fetch from backend
      if (isOnline && hasToken && !isOfflineMode) {
        print('[ProgressUpdateService] Fetching from backend: $baseUrl/api/wishes/$wishId/progress');
        final response = await http.get(
          Uri.parse('$baseUrl/api/wishes/$wishId/progress'),
        ).timeout(const Duration(seconds: 10));

        print('[ProgressUpdateService] Response status: ${response.statusCode}');
        print('[ProgressUpdateService] Response body: ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('[ProgressUpdateService] ✅ Found ${data.length} updates from backend');
          
          // Cache backend updates for offline use (replace entire cache for this wish)
          await _cacheProgressUpdates(wishId, data.cast<Map<String, dynamic>>(), merge: false);
          
          // Merge with local pending updates
          final localUpdates = await _getLocalProgressUpdates(wishId);
          print('[ProgressUpdateService] Found ${localUpdates.length} local updates');
          
          // Combine backend and local updates
          final allUpdates = [...data.cast<Map<String, dynamic>>(), ...localUpdates];
          print('[ProgressUpdateService] Total updates: ${allUpdates.length}');
          return allUpdates;
        } else {
          print('[ProgressUpdateService] ❌ Backend returned error: ${response.statusCode}');
        }
      } else {
        print('[ProgressUpdateService] Skipping backend fetch - using local storage only');
      }
      
      // Fallback to cached + local pending updates
      print('[ProgressUpdateService] Falling back to cached + local updates');
      final cachedUpdates = await _getCachedProgressUpdates(wishId);
      final localUpdates = await _getLocalProgressUpdates(wishId);
      final allUpdates = [...cachedUpdates, ...localUpdates];
      print('[ProgressUpdateService] Returning ${allUpdates.length} updates (${cachedUpdates.length} cached + ${localUpdates.length} local)');
      return allUpdates;
    } catch (e, stackTrace) {
      print('[ProgressUpdateService] ❌ Error fetching updates: $e');
      print('[ProgressUpdateService] Stack trace: $stackTrace');
      // Return cached + local updates on error
      final cachedUpdates = await _getCachedProgressUpdates(wishId);
      final localUpdates = await _getLocalProgressUpdates(wishId);
      final allUpdates = [...cachedUpdates, ...localUpdates];
      print('[ProgressUpdateService] Returning ${allUpdates.length} updates after error (${cachedUpdates.length} cached + ${localUpdates.length} local)');
      return allUpdates;
    }
  }

  /// Cache progress updates for offline use
  static Future<void> _cacheProgressUpdates(int wishId, List<Map<String, dynamic>> updates, {bool merge = false}) async {
    try {
      // Get existing cached updates
      final allCached = await StorageService.getCachedProgressUpdates() ?? {};
      
      if (merge) {
        // Merge with existing cached updates for this wish
        final existingUpdates = (allCached[wishId.toString()] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        // Add new updates that don't already exist (check by ID)
        final existingIds = existingUpdates.map((u) => u['id']).toSet();
        final newUpdates = updates.where((u) => !existingIds.contains(u['id'])).toList();
        
        allCached[wishId.toString()] = [...existingUpdates, ...newUpdates];
        print('[ProgressUpdateService] Merged ${newUpdates.length} new updates with ${existingUpdates.length} existing (total: ${allCached[wishId.toString()].length})');
      } else {
        // Replace cache for this wish
        allCached[wishId.toString()] = updates;
        print('[ProgressUpdateService] Cached ${updates.length} updates for wish $wishId');
      }
      
      // Save back to storage
      await StorageService.saveCachedProgressUpdates(allCached);
    } catch (e) {
      print('[ProgressUpdateService] Error caching progress updates: $e');
    }
  }

  /// Get cached progress updates for a wish
  static Future<List<Map<String, dynamic>>> _getCachedProgressUpdates(int wishId) async {
    try {
      final allCached = await StorageService.getCachedProgressUpdates();
      if (allCached == null) return [];
      
      final cached = allCached[wishId.toString()];
      if (cached == null) return [];
      
      return (cached as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('[ProgressUpdateService] Error getting cached updates: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getLocalProgressUpdates(int wishId) async {
    final pendingUpdates = await StorageService.getPendingProgressUpdates();
    if (pendingUpdates == null) return [];
    
    // Filter updates for this wish and convert to display format
    final updates = pendingUpdates.where((update) => update['wish_id'] == wishId).toList();
    print('[ProgressUpdateService] Found ${updates.length} local updates');
    
    // Convert local file paths to display format
    final displayUpdates = <Map<String, dynamic>>[];
    for (var update in updates) {
      final Map<String, dynamic> displayUpdate = {
        'id': update['id'],
        'wish_id': update['wish_id'],
        'content': update['content'],
        'progress_value': update['progress_value'],
        'created_at': update['created_at'],
        'attachments': [],
        'is_local': true, // Mark as local
      };

      // Convert local file paths to attachment format
      if (update['local_files'] != null) {
        final localFiles = update['local_files'] as List;
        for (var filePath in localFiles) {
          final file = File(filePath);
          if (await file.exists()) {
            displayUpdate['attachments'].add({
              'file_name': path.basename(filePath),
              'file_path': filePath,
              'file_type': _getMimeType(filePath),
              'file_size': await file.length(),
              'is_local': true,
            });
          }
        }
      }

      displayUpdates.add(displayUpdate);
    }
    
    return displayUpdates;
  }

  static String _getMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<bool> createProgressUpdate({
    required int wishId,
    required String content,
    int? progressValue,
    List<File>? files,
  }) async {
    try {
      final hasToken = await StorageService.hasToken();
      final isOnline = await SyncService.isOnline();

      print('[ProgressUpdateService] Creating progress update - Online: $isOnline, HasToken: $hasToken');

      // ALWAYS store locally first (offline-first approach)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final List<String> localFilePaths = [];

      // Copy files to local storage
      if (files != null && files.isNotEmpty) {
        print('[ProgressUpdateService] Copying ${files.length} files to local storage');
        for (var file in files) {
          final localPath = await _copyFileToLocalStorage(file, wishId, timestamp);
          localFilePaths.add(localPath);
        }
      }

      final updateData = {
        'wish_id': wishId,
        'content': content,
        'progress_value': progressValue,
        'created_at': DateTime.now().toIso8601String(),
        'id': timestamp, // Temporary local ID
        'local_files': localFilePaths,
        'synced': false,
      };

      // Add to pending updates
      final pendingUpdates = await StorageService.getPendingProgressUpdates() ?? [];
      pendingUpdates.add(updateData);
      await StorageService.savePendingProgressUpdates(pendingUpdates);

      print('[ProgressUpdateService] Saved to pending updates. Total pending: ${pendingUpdates.length}');
      print('[ProgressUpdateService] Update data: wishId=$wishId, content=$content, progressValue=$progressValue');

      // Update the wish's progress locally if progressValue is provided
      if (progressValue != null) {
        await _updateLocalWishProgress(wishId, progressValue);
      }

      print('[ProgressUpdateService] Progress update stored locally with ${localFilePaths.length} files');

      // Try to sync immediately if online and authenticated
      if (isOnline && hasToken) {
        print('[ProgressUpdateService] Attempting immediate sync');
        // Fire and forget, but let it run in background
        syncPendingUpdates().then((_) {
          print('[ProgressUpdateService] Immediate sync completed');
        }).catchError((error) {
          print('[ProgressUpdateService] Immediate sync failed: $error');
        });
      }

      return true;
    } catch (e) {
      print('[ProgressUpdateService] Error creating update: $e');
      return false;
    }
  }

  static Future<void> _updateLocalWishProgress(int wishId, int progressValue) async {
    try {
      // Update cached wishes
      final cachedWishes = await StorageService.getCachedWishes();
      if (cachedWishes != null) {
        for (var wish in cachedWishes) {
          if (wish['id'] == wishId) {
            wish['progress'] = progressValue;
            if (progressValue >= 100) {
              wish['is_completed'] = true;
              wish['status'] = 'completed';
            }
            break;
          }
        }
        await StorageService.cacheWishes(cachedWishes);
      }

      // Update pending wishes
      final pendingWishes = await StorageService.getPendingWishes();
      if (pendingWishes != null) {
        for (var wish in pendingWishes) {
          if (wish['id'] == wishId) {
            wish['progress'] = progressValue;
            if (progressValue >= 100) {
              wish['is_completed'] = true;
              wish['status'] = 'completed';
            }
            break;
          }
        }
        await StorageService.savePendingWishes(pendingWishes);
      }

      print('[ProgressUpdateService] Updated local wish progress to $progressValue');
    } catch (e) {
      print('[ProgressUpdateService] Error updating local wish progress: $e');
    }
  }

  static Future<void> _syncProgressUpdates() async {
    try {
      print('[ProgressUpdateService] Starting sync of progress updates');
      
      final token = await StorageService.getToken();
      if (token == null) {
        print('[ProgressUpdateService] No token for sync');
        return;
      }

      final pendingUpdates = await StorageService.getPendingProgressUpdates();
      print('[ProgressUpdateService] Found ${pendingUpdates?.length ?? 0} pending updates');
      
      if (pendingUpdates == null || pendingUpdates.isEmpty) {
        print('[ProgressUpdateService] No pending updates to sync');
        return;
      }

      print('[ProgressUpdateService] Syncing ${pendingUpdates.length} progress updates');

      final remainingUpdates = <Map<String, dynamic>>[];

      for (var update in pendingUpdates) {
        if (update['synced'] == true) continue; // Skip already synced

        final success = await _syncSingleProgressUpdate(update, token);
        if (!success) {
          remainingUpdates.add(update);
        }
      }

      // Save remaining unsynced updates
      await StorageService.savePendingProgressUpdates(remainingUpdates);
      
      if (remainingUpdates.isEmpty) {
        print('[ProgressUpdateService] All progress updates synced successfully');
      } else {
        print('[ProgressUpdateService] ${remainingUpdates.length} updates remaining to sync');
      }
    } catch (e) {
      print('[ProgressUpdateService] Error syncing progress updates: $e');
    }
  }

  static Future<bool> _syncSingleProgressUpdate(Map<String, dynamic> update, String token) async {
    try {
      final wishId = update['wish_id'];
      print('[ProgressUpdateService] ===== Syncing single progress update =====');
      print('[ProgressUpdateService] Wish ID: $wishId');
      print('[ProgressUpdateService] Content: ${update['content']}');
      print('[ProgressUpdateService] Progress value: ${update['progress_value']}');

      // Check if wish exists on backend first
      try {
        final checkResponse = await http.get(
          Uri.parse('$baseUrl/api/wishes/$wishId'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
        
        if (checkResponse.statusCode == 404) {
          print('[ProgressUpdateService] Wish $wishId not found on backend, skipping sync');
          return false; // Keep in pending to retry later
        }
      } catch (e) {
        print('[ProgressUpdateService] Error checking wish existence: $e');
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/wishes/$wishId/progress'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = update['content'] ?? '';
      if (update['progress_value'] != null) {
        request.fields['progress_value'] = update['progress_value'].toString();
      }

      // Add local files to the request
      if (update['local_files'] != null) {
        final localFiles = update['local_files'] as List;
        print('[ProgressUpdateService] Adding ${localFiles.length} files to sync');
        
        for (var filePath in localFiles) {
          final file = File(filePath);
          if (await file.exists()) {
            final fileStream = http.ByteStream(file.openRead());
            final fileLength = await file.length();
            final multipartFile = http.MultipartFile(
              'files',
              fileStream,
              fileLength,
              filename: path.basename(filePath),
            );
            request.files.add(multipartFile);
            print('[ProgressUpdateService] Added file: ${path.basename(filePath)}');
          } else {
            print('[ProgressUpdateService] Local file not found: $filePath');
          }
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        print('[ProgressUpdateService] Successfully synced update');
        
        // Cache the synced update immediately for offline viewing (merge with existing cache)
        try {
          final responseData = json.decode(response.body);
          await _cacheProgressUpdates(wishId, [responseData], merge: true);
          print('[ProgressUpdateService] Cached synced update for offline viewing');
        } catch (e) {
          print('[ProgressUpdateService] Error caching synced update: $e');
        }
        
        return true;
      } else {
        print('[ProgressUpdateService] Failed to sync update: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      print('[ProgressUpdateService] Error syncing single update: $e');
      return false;
    }
  }

  /// Public method to trigger sync of pending progress updates
  static Future<void> syncPendingUpdates() async {
    await _syncProgressUpdates();
  }
}
