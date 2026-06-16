class NotificationModel {
  final String id;
  final String type;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final String timeAgo;
  final String referenceId;
  final DateTime createdAt;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.timeAgo,
    required this.referenceId,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      type: json['type'] ?? 'general',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Usuario',
      userAvatar: json['user_avatar'] ?? '',
      content: json['content'] ?? '',
      timeAgo: json['time_ago'] ?? 'Recientemente',
      referenceId: json['reference_id'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'content': content,
      'time_ago': timeAgo,
      'reference_id': referenceId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
