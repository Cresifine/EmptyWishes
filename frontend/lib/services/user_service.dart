import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';
import '../models/wish.dart';

class UserService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.length < 2) return [];

    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[UserService] No token found, cannot search users');
        return [];
      }

      print('[UserService] Searching for users with query: $query');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('[UserService] Search response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('[UserService] Found ${data.length} users');
        return data.cast<Map<String, dynamic>>();
      } else {
        print('[UserService] Search failed with status ${response.statusCode}: ${response.body}');
      }
      return [];
    } catch (e) {
      print('[UserService] User search error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[UserService] No token found, cannot get user profile');
        return null;
      }

      print('[UserService] Fetching profile for user ID: $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('[UserService] Profile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[UserService] Successfully fetched profile for ${data['username']}');
        return data;
      } else {
        print('[UserService] Failed to fetch profile with status ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      print('[UserService] User profile fetch error: $e');
      return null;
    }
  }

  /// Get user by ID (alias for getUserProfile)
  static Future<Map<String, dynamic>?> getUserById(int userId) async {
    return getUserProfile(userId);
  }

  /// Get user statistics
  static Future<Map<String, dynamic>?> getUserStats(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[UserService] No token found, cannot get user stats');
        return null;
      }

      print('[UserService] Fetching stats for user ID: $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('[UserService] Stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[UserService] Successfully fetched user stats');
        return data;
      } else {
        print('[UserService] Failed to fetch stats with status ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      print('[UserService] User stats fetch error: $e');
      return null;
    }
  }

  /// Get user's public wishes
  static Future<List<Wish>> getUserWishes(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[UserService] No token found, cannot get user wishes');
        return [];
      }

      print('[UserService] Fetching wishes for user ID: $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/wishes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('[UserService] Wishes response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('[UserService] Successfully fetched ${data.length} wishes');
        return data.map((json) => Wish.fromJson(json)).toList();
      } else {
        print('[UserService] Failed to fetch wishes with status ${response.statusCode}: ${response.body}');
      }
      return [];
    } catch (e) {
      print('[UserService] User wishes fetch error: $e');
      return [];
    }
  }

  /// Update user profile
  static Future<bool> updateProfile(Map<String, dynamic> updateData) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[UserService] No token found, cannot update profile');
        return false;
      }

      print('[UserService] Updating profile: $updateData');
      
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      ).timeout(const Duration(seconds: 10));

      print('[UserService] Update profile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[UserService] Profile updated successfully');
        return true;
      } else {
        print('[UserService] Failed to update profile with status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[UserService] Profile update error: $e');
      return false;
    }
  }
}

