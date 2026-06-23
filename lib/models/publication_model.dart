class PublicationModel {
  final String id;

  // Datos del autor
  final String userName;
  final String userPhoto;

  // Datos principales
  final String title;
  final String description;
  final String type;
  final String? location;
  final String? modality;

  // Imagen
  final String? imagePath;

  // Archivo / video / documento
  final String? filePath;
  final String? fileName;
  final String? fileType;

  final DateTime createdAt;
  final int likes;
  final int comments;

  PublicationModel({
    required this.id,
    required this.userName,
    required this.userPhoto,
    required this.description,
    this.title = '',
    this.type = 'general',
    this.location,
    this.modality,
    this.imagePath,
    this.filePath,
    this.fileName,
    this.fileType,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'userPhoto': userPhoto,
      'title': title,
      'description': description,
      'type': type,
      'location': location,
      'modality': modality,
      'imagePath': imagePath,
      'filePath': filePath,
      'fileName': fileName,
      'fileType': fileType,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'comments': comments,
    };
  }

  factory PublicationModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'];

    String resolvedUserName = json['userName'] ?? '';

    if (author is Map<String, dynamic>) {
      final firstName = author['first_name'] ?? '';
      final lastName = author['last_name'] ?? '';
      final email = author['email'] ?? '';

      resolvedUserName = '$firstName $lastName'.trim();

      if (resolvedUserName.isEmpty) {
        resolvedUserName = email;
      }
    }

    return PublicationModel(
      id: json['id']?.toString() ?? '',
      userName: resolvedUserName,
      userPhoto: json['userPhoto'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'general',
      location: json['location'],
      modality: json['modality'],

      // Backend usa image_url, local usaba imagePath
      imagePath: json['image_url'] ?? json['imagePath'],

      filePath: json['filePath'],
      fileName: json['fileName'],
      fileType: json['fileType'],

      // Backend usa created_at, local usaba createdAt
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),

      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}
