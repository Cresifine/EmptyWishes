import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'storage_service.dart';
import 'sync_service.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator localhost

  static Future<bool> login(String email, String password) async {
    try {
      print('[AuthService] Attempting login to: $baseUrl/api/auth/login');
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email': email,
          'password': password,
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('[AuthService] Login request timed out');
          throw TimeoutException('Connection timeout');
        },
      );

      print('[AuthService] Login response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await StorageService.saveToken(data['access_token']);
        await StorageService.setOfflineMode(false);
        
        print('[AuthService] Login successful, syncing data...');
        // Sync all pending offline data if auto-sync is enabled
        final autoSyncEnabled = await StorageService.isAutoSyncEnabled();
        if (autoSyncEnabled) {
          print('[AuthService] Auto-sync enabled, syncing pending data');
          await SyncService.backgroundSync();
        } else {
          print('[AuthService] Auto-sync disabled, skipping automatic sync');
        }
        
        return true;
      }
      print('[AuthService] Login failed with status: ${response.statusCode}');
      return false;
    } on TimeoutException catch (e) {
      print('[AuthService] Login timeout error: $e');
      return false;
    } catch (e) {
      print('[AuthService] Login error: $e');
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
      print('[AuthService] Getting current user...');
      final token = await StorageService.getToken();
      if (token == null) {
        print('[AuthService] No token found');
        return await StorageService.getUser(); // Return cached user
      }

      print('[AuthService] Token found, calling API...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      print('[AuthService] API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        print('[AuthService] User data received: ${userData['username']}, ${userData['email']}');
        await StorageService.saveUser(userData);
        return userData;
      } else {
        print('[AuthService] API returned error: ${response.statusCode}, ${response.body}');
        // Return cached user if API fails
        return await StorageService.getUser();
      }
    } catch (e) {
      print('[AuthService] Get user error: $e');
      // Return cached user if offline
      final cachedUser = await StorageService.getUser();
      print('[AuthService] Returning cached user: $cachedUser');
      return cachedUser;
    }
  }

  static Future<void> logout() async {
    print('[AuthService] Logging out - clearing cached backend data');
    
    // Clear auth-related data
    await StorageService.deleteToken();
    await StorageService.deleteUser();
    
    // Clear cached backend data (prevent data leakage between accounts)
    // But keep pending data that was created offline and needs to sync
    await StorageService.clearCachedBackendData();
    
    await StorageService.setOfflineMode(true);
    print('[AuthService] Logout complete - cached data cleared, pending data preserved');
  }

  static Future<bool> isLoggedIn() async {
    return await StorageService.hasToken();
  }
}

