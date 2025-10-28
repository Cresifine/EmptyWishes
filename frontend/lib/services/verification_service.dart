import 'package:http/http.dart' as http;
import 'dart:convert';
import 'storage_service.dart';

class VerificationService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Get verifications for a specific wish
  static Future<Map<String, dynamic>> getVerifications(int wishId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return {'verifications': [], 'owner_dispute_response': null};

      final response = await http.get(
        Uri.parse('$baseUrl/api/wishes/$wishId/verifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> verifications = responseData['verifications'] ?? [];
        final String? ownerResponse = responseData['owner_dispute_response'];
        print('[VerificationService] Loaded ${verifications.length} verifications for wish $wishId, owner response: ${ownerResponse != null ? "present" : "absent"}');
        return {
          'verifications': verifications.map((v) => v as Map<String, dynamic>).toList(),
          'owner_dispute_response': ownerResponse,
        };
      }
      print('[VerificationService] Failed to load verifications: ${response.statusCode}');
      return {'verifications': [], 'owner_dispute_response': null};
    } catch (e) {
      print('[VerificationService] Error getting verifications: $e');
      return {'verifications': [], 'owner_dispute_response': null};
    }
  }

  /// Verify completion (approve or dispute)
  static Future<bool> verifyCompletion({
    required int wishId,
    required String status, // 'approved' or 'disputed'
    String? comment,
    String? disputeReason,
    String? proofUrl,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return false;

      // Build query parameters
      final queryParams = <String, String>{
        'approved': (status == 'approved').toString(),
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (disputeReason != null && disputeReason.isNotEmpty) 'dispute_reason': disputeReason,
      };

      final uri = Uri.parse('$baseUrl/api/wishes/$wishId/verify').replace(
        queryParameters: queryParams,
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('[VerificationService] Verify response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[VerificationService] Error verifying completion: $e');
      return false;
    }
  }

  /// Owner responds to dispute
  static Future<bool> respondToDispute({
    required int wishId,
    required String responseText,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return false;

      // Backend expects 'response' as query parameter
      final uri = Uri.parse('$baseUrl/api/wishes/$wishId/respond-to-dispute').replace(
        queryParameters: {'response': responseText},
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('[VerificationService] Respond to dispute response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[VerificationService] Error responding to dispute: $e');
      return false;
    }
  }

  /// Re-request verification after responding to disputes
  static Future<bool> reRequestVerification({
    required int wishId,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/wishes/$wishId/re-request-verification'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('[VerificationService] Re-request verification response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[VerificationService] Error re-requesting verification: $e');
      return false;
    }
  }

  /// Verifier replies to owner's dispute response
  static Future<bool> verifierReplyToOwner({
    required int wishId,
    required int verificationId,
    required String reply,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return false;

      // Backend expects 'reply' as query parameter
      final uri = Uri.parse('$baseUrl/api/wishes/$wishId/verifications/$verificationId/reply').replace(
        queryParameters: {'reply': reply},
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('[VerificationService] Verifier reply response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[VerificationService] Error sending verifier reply: $e');
      return false;
    }
  }
}

