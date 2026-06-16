class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final bool isInternship;
  final List<String> imageUrls;
  final String description;
  final int likes;
  final int comments;
  final String timeAgo;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.isInternship,
    required this.imageUrls,
    required this.description,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Usuario',
      userAvatar: json['user_avatar'] ?? '',
      isInternship: json['is_internship'] ?? false,
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      description: json['description'] ?? '',
      likes: json['likes_count'] ?? 0,
      comments: json['comments_count'] ?? 0,
      timeAgo: json['time_ago'] ?? 'Recientemente',
      isLikedByMe: json['is_liked_by_me'] ?? false,
      isBookmarkedByMe: json['is_bookmarked_by_me'] ?? false,
    );
  }
}
