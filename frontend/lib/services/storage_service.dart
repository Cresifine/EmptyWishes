import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _wishesKey = 'cached_wishes';
  static const String _pendingWishesKey = 'pending_wishes';
  static const String _offlineModeKey = 'offline_mode';

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

