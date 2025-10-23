class Wish {
  final int id;
  final int userId;
  final String title;
  final String description;
  final int progress;
  final bool isCompleted;
  final String status;
  final DateTime createdAt;
  final DateTime? targetDate;
  final String? consequence;
  final String? coverImage;

  Wish({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.progress,
    required this.isCompleted,
    this.status = 'current',
    required this.createdAt,
    this.targetDate,
    this.consequence,
    this.coverImage,
  });

  factory Wish.fromJson(Map<String, dynamic> json) {
    return Wish(
      id: json['id'],
      userId: json['user_id'] ?? 1,
      title: json['title'],
      description: json['description'] ?? '',
      progress: json['progress'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      status: json['status'] ?? 'current',
      createdAt: DateTime.parse(json['created_at']),
      targetDate: json['target_date'] != null 
          ? DateTime.parse(json['target_date']) 
          : null,
      consequence: json['consequence'],
      coverImage: json['cover_image'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'progress': progress,
      'is_completed': isCompleted,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'target_date': targetDate?.toIso8601String(),
      if (consequence != null) 'consequence': consequence,
      if (coverImage != null) 'cover_image': coverImage,
    };
  }
}

