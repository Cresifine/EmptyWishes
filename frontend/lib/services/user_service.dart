import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';

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
}

