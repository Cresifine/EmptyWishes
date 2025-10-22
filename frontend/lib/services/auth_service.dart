import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';
import 'sync_service.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator localhost

  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await StorageService.saveToken(data['access_token']);
        await StorageService.setOfflineMode(false);
        
        // Sync pending offline wishes
        await SyncService.syncPendingWishes();
        
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      print('Attempting registration to: $baseUrl/api/auth/register');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print('Registration response status: ${response.statusCode}');
      print('Registration response body: ${response.body}');

      if (response.statusCode == 201) {
        // Auto login after registration and sync pending wishes
        final loginSuccess = await login(email, password);
        return {'success': loginSuccess, 'message': 'Registration successful'};
      } else {
        try {
          final errorData = json.decode(response.body);
          return {'success': false, 'message': errorData['detail'] ?? 'Registration failed'};
        } catch (e) {
          // If response is not JSON (e.g., 500 error with HTML)
          return {'success': false, 'message': 'Server error: ${response.body.substring(0, 50)}'};
        }
      }
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<void> useOfflineMode() async {
    await StorageService.setOfflineMode(true);
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        await StorageService.saveUser(userData);
        return userData;
      }
      return null;
    } catch (e) {
      print('Get user error: $e');
      // Return cached user if offline
      return await StorageService.getUser();
    }
  }

  static Future<void> logout() async {
    await StorageService.clearAll();
  }

  static Future<bool> isLoggedIn() async {
    return await StorageService.hasToken();
  }
}

