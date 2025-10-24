import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class NotificationService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Get all notifications for the current user
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      print('[NotificationService] Fetching notifications');
      final token = await StorageService.getToken();
      
      if (token == null) {
        print('[NotificationService] No token found');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Notifications response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final notifications = data.cast<Map<String, dynamic>>();
        print('[NotificationService] Fetched ${notifications.length} notifications');
        return notifications;
      } else {
        print('[NotificationService] Failed to fetch notifications: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[NotificationService] Error fetching notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount() async {
    try {
      print('[NotificationService] Fetching unread count');
      final token = await StorageService.getToken();
      
      if (token == null) {
        return 0;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread-count'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Unread count response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final count = data['unread_count'] ?? 0;
        print('[NotificationService] Unread count: $count');
        return count;
      } else {
        print('[NotificationService] Failed to fetch unread count: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('[NotificationService] Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  static Future<bool> markAsRead(int notificationId) async {
    try {
      print('[NotificationService] Marking notification $notificationId as read');
      final token = await StorageService.getToken();
      
      if (token == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Mark as read response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[NotificationService] Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllAsRead() async {
    try {
      print('[NotificationService] Marking all notifications as read');
      final token = await StorageService.getToken();
      
      if (token == null) {
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/read-all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('[NotificationService] Mark all as read response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[NotificationService] Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Format notification message
  static String formatNotificationMessage(Map<String, dynamic> notification) {
    final type = notification['type'];
    final actorUsername = notification['actor_username'];
    final actorUsernames = notification['actor_usernames'] as List<dynamic>?;
    final count = notification['count'] ?? 0;

    switch (type) {
      case 'like':
        return '$actorUsername liked your goal';
      case 'like_aggregated':
        if (actorUsernames != null && actorUsernames.isNotEmpty) {
          if (count == 2) {
            return '${actorUsernames[0]} and ${actorUsernames[1]} liked your goal';
          } else if (count > 2) {
            return '${actorUsernames[0]} and ${count - 1} others liked your goal';
          }
        }
        return 'People liked your goal';
      case 'comment':
        return '$actorUsername commented on your goal';
      case 'comment_aggregated':
        if (actorUsernames != null && actorUsernames.isNotEmpty) {
          if (count == 2) {
            return '${actorUsernames[0]} and ${actorUsernames[1]} commented on your goal';
          } else if (count > 2) {
            return '${actorUsernames[0]} and ${count - 1} others commented on your goal';
          }
        }
        return 'People commented on your goal';
      case 'follow':
        final content = notification['content'];
        return content ?? '$actorUsername started following you';
      default:
        return 'You have a new notification';
    }
  }
}

