import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import '../models/milestone.dart';

class MilestoneService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Create a new milestone
  Future<Milestone?> createMilestone(int wishId, Milestone milestone) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/wishes/$wishId/milestones'),
        headers: headers,
        body: jsonEncode(milestone.toJson()),
      );

      if (response.statusCode == 201) {
        return Milestone.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error creating milestone: $e');
      return null;
    }
  }

  // Get milestones for a specific wish
  Future<List<Milestone>> getWishMilestones(int wishId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/wishes/$wishId/milestones'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Milestone.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching milestones: $e');
      return [];
    }
  }

  // Get a specific milestone
  Future<Milestone?> getMilestone(int milestoneId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/milestones/$milestoneId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Milestone.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error fetching milestone: $e');
      return null;
    }
  }

  // Update a milestone
  Future<Milestone?> updateMilestone(
    int milestoneId, {
    String? title,
    String? description,
    int? points,
    bool? isCompleted,
  }) async {
    try {
      final headers = await _getHeaders();
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (points != null) updates['points'] = points;
      if (isCompleted != null) updates['is_completed'] = isCompleted;
      
      final response = await http.patch(
        Uri.parse('$baseUrl/milestones/$milestoneId'),
        headers: headers,
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return Milestone.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error updating milestone: $e');
      return null;
    }
  }

  // Toggle milestone completion
  Future<Milestone?> toggleMilestoneCompletion(int milestoneId, bool isCompleted) async {
    return await updateMilestone(milestoneId, isCompleted: isCompleted);
  }

  // Delete a milestone
  Future<bool> deleteMilestone(int milestoneId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/milestones/$milestoneId'),
        headers: headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting milestone: $e');
      return false;
    }
  }

  // Calculate progress percentage based on milestones
  int calculateProgress(List<Milestone> milestones) {
    if (milestones.isEmpty) return 0;
    
    final completedCount = milestones.where((m) => m.isCompleted).length;
    return ((completedCount / milestones.length) * 100).round();
  }

  // Check if all milestones are completed
  bool areAllMilestonesCompleted(List<Milestone> milestones) {
    if (milestones.isEmpty) return false;
    return milestones.every((m) => m.isCompleted);
  }

  // Get next incomplete milestone
  Milestone? getNextMilestone(List<Milestone> milestones) {
    try {
      return milestones.firstWhere((m) => !m.isCompleted);
    } catch (e) {
      return null;
    }
  }

  // Get overdue milestones
  List<Milestone> getOverdueMilestones(List<Milestone> milestones) {
    final now = DateTime.now();
    return milestones.where((m) {
      return !m.isCompleted && 
             m.targetDate != null && 
             m.targetDate!.isBefore(now);
    }).toList();
  }
}

