class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;

  final bool isInternship;
  final List<String> imageUrls;

  final String title;
  final String description;
  final String type;
  final String? location;
  final String? modality;

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
    this.title = '',
    required this.description,
    this.type = 'general',
    this.location,
    this.modality,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'];

    String resolvedUserId =
        json['user_id']?.toString() ?? json['author_id']?.toString() ?? '';

    String resolvedUserName =
        json['user_name']?.toString() ??
        json['userName']?.toString() ??
        'Usuario';

    String resolvedUserAvatar =
        json['user_avatar']?.toString() ?? json['userAvatar']?.toString() ?? '';

    if (author is Map<String, dynamic>) {
      final firstName = author['first_name']?.toString() ?? '';
      final lastName = author['last_name']?.toString() ?? '';
      final email = author['email']?.toString() ?? '';

      final fullName = '$firstName $lastName'.trim();

      if (fullName.isNotEmpty) {
        resolvedUserName = fullName;
      } else if (email.isNotEmpty) {
        resolvedUserName = email;
      }

      resolvedUserId = author['id']?.toString() ?? resolvedUserId;
    }

    final type = json['type']?.toString() ?? 'general';

    return PostModel(
      id: json['id']?.toString() ?? '',
      userId: resolvedUserId,
      userName: resolvedUserName,
      userAvatar: resolvedUserAvatar,
      isInternship: json['is_internship'] == true || type == 'internship',
      imageUrls: _parseImageUrls(json),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: type,
      location: json['location']?.toString(),
      modality: json['modality']?.toString(),
      likes: _parseInt(json['likes_count'] ?? json['likes']),
      comments: _parseInt(json['comments_count'] ?? json['comments']),
      timeAgo:
          json['time_ago']?.toString() ??
          json['timeAgo']?.toString() ??
          'Ahora',
      isLikedByMe:
          json['is_liked_by_me'] == true || json['isLikedByMe'] == true,
      isBookmarkedByMe:
          json['is_bookmarked_by_me'] == true ||
          json['isBookmarkedByMe'] == true,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'internship':
        return 'Pasantía';
      case 'job':
        return 'Empleo';
      case 'social_service':
        return 'Servicio social';
      case 'freelance':
        return 'Freelance';
      case 'announcement':
        return 'Convocatoria';
      case 'general':
        return 'General';
      default:
        return 'Publicación';
    }
  }

  String get modalityLabel {
    switch (modality) {
      case 'remote':
        return 'Remoto';
      case 'onsite':
        return 'Presencial';
      case 'hybrid':
        return 'Híbrido';
      default:
        return modality ?? '';
    }
  }

  bool get hasTitle {
    return title.trim().isNotEmpty;
  }

  bool get hasLocation {
    return location != null && location!.trim().isNotEmpty;
  }

  bool get hasModality {
    return modalityLabel.trim().isNotEmpty;
  }

  static List<String> _parseImageUrls(Map<String, dynamic> json) {
    final imageUrls = json['image_urls'];

    if (imageUrls is List) {
      return imageUrls.map((item) => item.toString()).toList();
    }

    final imageUrl = json['image_url']?.toString();

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return [imageUrl];
    }

    return [];
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }
}
