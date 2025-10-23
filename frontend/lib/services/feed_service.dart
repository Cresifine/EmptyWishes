import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class FeedService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Fetch public feed from the backend
  static Future<List<Map<String, dynamic>>> getFeed({String? filter}) async {
    try {
      print('[FeedService] Fetching feed with filter: $filter');
      
      final token = await StorageService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final uri = filter != null
          ? Uri.parse('$baseUrl/api/wishes/public/feed?filter_type=$filter')
          : Uri.parse('$baseUrl/api/wishes/public/feed');
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      print('[FeedService] Feed response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final feedItems = data.cast<Map<String, dynamic>>();
        
        // Cache feed data for offline mode
        await StorageService.saveFeedCache(feedItems);
        
        print('[FeedService] Fetched ${feedItems.length} feed items');
        return feedItems;
      } else {
        print('[FeedService] Failed to fetch feed: ${response.statusCode}');
        // Return cached data if available
        return await _getCachedFeed();
      }
    } catch (e) {
      print('[FeedService] Error fetching feed: $e');
      // Return cached data if available
      return await _getCachedFeed();
    }
  }

  /// Get cached feed data
  static Future<List<Map<String, dynamic>>> _getCachedFeed() async {
    try {
      final cached = await StorageService.getFeedCache();
      if (cached != null && cached.isNotEmpty) {
        print('[FeedService] Returning ${cached.length} cached feed items');
        return cached;
      }
      return [];
    } catch (e) {
      print('[FeedService] Error getting cached feed: $e');
      return [];
    }
  }

  /// Toggle like on a wish
  static Future<Map<String, dynamic>?> toggleLike(int wishId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FeedService] No token found, cannot like');
        return null;
      }

      print('[FeedService] Toggling like for wish $wishId');
      final response = await http.post(
        Uri.parse('$baseUrl/api/engagements/likes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'wish_id': wishId}),
      ).timeout(const Duration(seconds: 10));

      print('[FeedService] Like toggle response: ${response.statusCode}');

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('[FeedService] Failed to toggle like: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[FeedService] Error toggling like: $e');
      return null;
    }
  }

  /// Add comment to a wish
  static Future<bool> addComment(int wishId, String content) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[FeedService] No token found, cannot comment');
        return false;
      }

      print('[FeedService] Adding comment to wish $wishId');
      final response = await http.post(
        Uri.parse('$baseUrl/api/engagements/comments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'wish_id': wishId,
          'content': content,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[FeedService] Comment response: ${response.statusCode}');

      if (response.statusCode == 201) {
        print('[FeedService] Comment added successfully');
        return true;
      } else {
        print('[FeedService] Failed to add comment: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[FeedService] Error adding comment: $e');
      return false;
    }
  }

  /// Record view for a wish
  static Future<void> recordView(int wishId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return;

      await http.post(
        Uri.parse('$baseUrl/api/engagements/views'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'wish_id': wishId}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[FeedService] Error recording view: $e');
    }
  }

  /// Get comments for a wish
  static Future<List<Map<String, dynamic>>> getComments(int wishId) async {
    try {
      print('[FeedService] Fetching comments for wish $wishId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/engagements/wishes/$wishId/comments'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('[FeedService] Comments response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final comments = data.cast<Map<String, dynamic>>();
        print('[FeedService] Fetched ${comments.length} comments');
        return comments;
      } else {
        print('[FeedService] Failed to fetch comments: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[FeedService] Error fetching comments: $e');
      return [];
    }
  }
}

