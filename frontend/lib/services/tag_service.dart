import 'dart:convert';
import 'package:http/http.dart' as http;

class TagService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Get popular tags
  static Future<List<Map<String, dynamic>>> getPopularTags({int limit = 20}) async {
    try {
      print('[TagService] Fetching popular tags');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags/popular?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('[TagService] Popular tags response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final tags = data.cast<Map<String, dynamic>>();
        print('[TagService] Fetched ${tags.length} popular tags');
        return tags;
      } else {
        print('[TagService] Failed to fetch popular tags: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[TagService] Error fetching popular tags: $e');
      return [];
    }
  }

  /// Search tags by query (autocomplete)
  static Future<List<Map<String, dynamic>>> searchTags(String query, {int limit = 10}) async {
    if (query.length < 2) return [];
    
    try {
      print('[TagService] Searching tags with query: $query');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags/search?q=${Uri.encodeComponent(query)}&limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      print('[TagService] Search response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final tags = data.cast<Map<String, dynamic>>();
        print('[TagService] Found ${tags.length} tags');
        return tags;
      } else {
        print('[TagService] Search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('[TagService] Error searching tags: $e');
      return [];
    }
  }

  /// Get all tags
  static Future<List<Map<String, dynamic>>> getAllTags() async {
    try {
      print('[TagService] Fetching all tags');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      print('[TagService] Error fetching all tags: $e');
      return [];
    }
  }
}

