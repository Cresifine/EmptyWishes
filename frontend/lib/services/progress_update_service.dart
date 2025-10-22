import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'storage_service.dart';

class ProgressUpdateService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<List<Map<String, dynamic>>> getProgressUpdates(int wishId) async {
    try {
      print('[ProgressUpdateService] Fetching progress updates for wish $wishId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/wishes/$wishId/progress'),
      ).timeout(const Duration(seconds: 5));

      print('[ProgressUpdateService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('[ProgressUpdateService] Found ${data.length} updates');
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('[ProgressUpdateService] Error fetching updates: $e');
      return [];
    }
  }

  static Future<bool> createProgressUpdate({
    required int wishId,
    required String content,
    int? progressValue,
    List<File>? files,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        print('[ProgressUpdateService] No token found');
        return false;
      }

      print('[ProgressUpdateService] Creating progress update for wish $wishId');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/wishes/$wishId/progress'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = content;
      if (progressValue != null) {
        request.fields['progress_value'] = progressValue.toString();
      }

      // Add files if provided
      if (files != null && files.isNotEmpty) {
        print('[ProgressUpdateService] Adding ${files.length} file(s)');
        for (var file in files) {
          final fileStream = http.ByteStream(file.openRead());
          final fileLength = await file.length();
          final multipartFile = http.MultipartFile(
            'files',
            fileStream,
            fileLength,
            filename: file.path.split('/').last,
          );
          request.files.add(multipartFile);
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('[ProgressUpdateService] Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        print('[ProgressUpdateService] Successfully created progress update');
        return true;
      } else {
        print('[ProgressUpdateService] Failed: ${response.body}');
      }
      return false;
    } catch (e) {
      print('[ProgressUpdateService] Error creating update: $e');
      return false;
    }
  }
}

