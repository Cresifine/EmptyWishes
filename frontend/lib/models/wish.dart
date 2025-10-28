class Wish {
  final int id;
  final int userId;
  final String title;
  final String description;
  final int progress;
  final bool isCompleted;
  final String status;
  final String progressMode; // 'manual' or 'milestone'
  final String visibility; // 'public', 'private', 'followers', 'friends'
  final DateTime createdAt;
  final DateTime? targetDate;
  final String? consequence;
  final String? coverImage;
  final bool requiresVerification;
  final String completionStatus; // 'incomplete', 'pending_verification', 'verified', 'disputed', 'self_verified'
  final List<Map<String, dynamic>> verifiers;

  Wish({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.progress,
    required this.isCompleted,
    this.status = 'current',
    this.progressMode = 'manual',
    this.visibility = 'public',
    required this.createdAt,
    this.targetDate,
    this.consequence,
    this.coverImage,
    this.requiresVerification = false,
    this.completionStatus = 'incomplete',
    this.verifiers = const [],
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
      progressMode: json['progress_mode'] ?? 'manual',
      visibility: json['visibility'] ?? 'public',
      createdAt: DateTime.parse(json['created_at']),
      targetDate: json['target_date'] != null 
          ? DateTime.parse(json['target_date']) 
          : null,
      consequence: json['consequence'],
      coverImage: json['cover_image'],
      requiresVerification: json['requires_verification'] ?? false,
      completionStatus: json['completion_status'] ?? 'incomplete',
      verifiers: json['verifiers'] != null 
          ? List<Map<String, dynamic>>.from(json['verifiers'])
          : [],
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
      'progress_mode': progressMode,
      'visibility': visibility,
      'created_at': createdAt.toIso8601String(),
      'target_date': targetDate?.toIso8601String(),
      if (consequence != null) 'consequence': consequence,
      if (coverImage != null) 'cover_image': coverImage,
      'requires_verification': requiresVerification,
      'completion_status': completionStatus,
      'verifiers': verifiers,
    };
  }
}

