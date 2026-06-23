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

  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }

    return description;
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

  bool get hasLocation {
    return location != null && location!.trim().isNotEmpty;
  }

  bool get hasModality {
    return modalityLabel.trim().isNotEmpty;
  }

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

    String resolvedUserName = json['userName']?.toString() ?? '';

    if (author is Map<String, dynamic>) {
      final firstName = author['first_name']?.toString() ?? '';
      final lastName = author['last_name']?.toString() ?? '';
      final email = author['email']?.toString() ?? '';

      resolvedUserName = '$firstName $lastName'.trim();

      if (resolvedUserName.isEmpty) {
        resolvedUserName = email;
      }
    }

    if (resolvedUserName.isEmpty) {
      resolvedUserName = 'Usuario de Connect Do';
    }

    return PublicationModel(
      id: json['id']?.toString() ?? '',
      userName: resolvedUserName,
      userPhoto: json['userPhoto']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      location: json['location']?.toString(),
      modality: json['modality']?.toString(),

      // Backend usa image_url, local usaba imagePath
      imagePath: json['image_url']?.toString() ?? json['imagePath']?.toString(),

      filePath: json['filePath']?.toString(),
      fileName: json['fileName']?.toString(),
      fileType: json['fileType']?.toString(),

      // Backend usa created_at, local usaba createdAt
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),

      likes: _parseInt(json['likes']),
      comments: _parseInt(json['comments']),
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

  static int _parseInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }
}
