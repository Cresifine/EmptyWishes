import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _wishesKey = 'cached_wishes';
  static const String _pendingWishesKey = 'pending_wishes';
  static const String _offlineModeKey = 'offline_mode';
  static const String _feedCacheKey = 'feed_cache';
  static const String _pendingProgressUpdatesKey = 'pending_progress_updates';
  static const String _cachedProgressUpdatesKey = 'cached_progress_updates';
  static const String _autoSyncKey = 'auto_sync_enabled';

  // Token management
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // User data management
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(userData));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      return json.decode(userData);
    }
    return null;
  }

  static Future<void> deleteUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Offline wishes cache
  static Future<void> cacheWishes(List<Map<String, dynamic>> wishes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wishesKey, json.encode(wishes));
  }

  static Future<List<Map<String, dynamic>>?> getCachedWishes() async {
    final prefs = await SharedPreferences.getInstance();
    final wishesData = prefs.getString(_wishesKey);
    if (wishesData != null) {
      final List<dynamic> decoded = json.decode(wishesData);
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  // Pending wishes for sync
  static Future<void> savePendingWishes(List<Map<String, dynamic>> wishes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingWishesKey, json.encode(wishes));
  }

  static Future<List<Map<String, dynamic>>?> getPendingWishes() async {
    final prefs = await SharedPreferences.getInstance();
    final wishesData = prefs.getString(_pendingWishesKey);
    if (wishesData != null) {
      final List<dynamic> decoded = json.decode(wishesData);
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  static Future<void> clearPendingWishes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingWishesKey);
  }

  // Offline mode flag
  static Future<void> setOfflineMode(bool isOffline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, isOffline);
  }

  static Future<bool> isOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_offlineModeKey) ?? false;
  }

  // Feed cache management
  static Future<void> saveFeedCache(List<Map<String, dynamic>> feedItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedCacheKey, json.encode(feedItems));
  }

  static Future<List<Map<String, dynamic>>?> getFeedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final feedData = prefs.getString(_feedCacheKey);
    if (feedData != null) {
      final List<dynamic> decoded = json.decode(feedData);
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  static Future<void> clearFeedCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_feedCacheKey);
  }

  // Auto-sync settings
  static Future<void> setAutoSync(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, enabled);
  }

  static Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? true; // Default: enabled
  }

  // Pending progress updates management
  static Future<void> savePendingProgressUpdates(List<Map<String, dynamic>> updates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingProgressUpdatesKey, json.encode(updates));
  }

  static Future<List<Map<String, dynamic>>?> getPendingProgressUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final updatesData = prefs.getString(_pendingProgressUpdatesKey);
    if (updatesData != null) {
      final List<dynamic> decoded = json.decode(updatesData);
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  static Future<void> clearPendingProgressUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingProgressUpdatesKey);
  }

  // Cached progress updates management (for offline viewing)
  static Future<void> saveCachedProgressUpdates(Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedProgressUpdatesKey, json.encode(updates));
  }

  static Future<Map<String, dynamic>?> getCachedProgressUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final updatesData = prefs.getString(_cachedProgressUpdatesKey);
    if (updatesData != null) {
      return json.decode(updatesData) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearCachedProgressUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedProgressUpdatesKey);
  }

  // Clear cached backend data (for logout) but keep pending data
  static Future<void> clearCachedBackendData() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear cached data from backend (prevents data leakage between accounts)
    await prefs.remove(_wishesKey);
    await prefs.remove(_cachedProgressUpdatesKey);
    await prefs.remove(_feedCacheKey);
    // Note: pending_wishes and pending_progress_updates are NOT cleared
    // They contain offline-created data that needs to sync
    print('[StorageService] Cleared cached backend data, kept pending data');
  }

  // Clear all data except offline wishes
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep offline wishes when clearing
    final pendingWishes = await getPendingWishes();
    await prefs.clear();
    if (pendingWishes != null && pendingWishes.isNotEmpty) {
      await savePendingWishes(pendingWishes);
    }
  }
}

