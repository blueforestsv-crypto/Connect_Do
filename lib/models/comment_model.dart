class CommentModel {
  final String id;
  final String publicationId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String text;
  final String timeAgo;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.publicationId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.timeAgo,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? '',
      publicationId: json['publication_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Usuario',
      userAvatar: json['user_avatar'] ?? '',
      text: json['text'] ?? '',
      timeAgo: json['time_ago'] ?? 'Ahora',
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'publication_id': publicationId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'text': text,
      'time_ago': timeAgo,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
