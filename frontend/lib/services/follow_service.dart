import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class FollowService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Follow a user
  static Future<bool> followUser(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FollowService] No token found');
        return false;
      }

      print('[FollowService] Following user $userId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/$userId/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Follow response: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('[FollowService] Error following user: $e');
      return false;
    }
  }

  /// Unfollow a user
  static Future<bool> unfollowUser(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FollowService] No token found');
        return false;
      }

      print('[FollowService] Unfollowing user $userId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$userId/follow'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Unfollow response: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('[FollowService] Error unfollowing user: $e');
      return false;
    }
  }

  /// Check if currently following a user and get follower/following counts
  static Future<Map<String, dynamic>?> getFollowStatus(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FollowService] No token found');
        return null;
      }

      print('[FollowService] Checking follow status for user $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/is-following'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('[FollowService] Follow status response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('[FollowService] Error checking follow status: $e');
      return null;
    }
  }

  /// Get list of followers for a user
  static Future<List<Map<String, dynamic>>> getFollowers(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FollowService] No token found');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/followers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('[FollowService] Error getting followers: $e');
      return [];
    }
  }

  /// Get list of users that a user is following
  static Future<List<Map<String, dynamic>>> getFollowing(int userId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FollowService] No token found');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/following'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('[FollowService] Error getting following: $e');
      return [];
    }
  }
}

