class PublicationMediaItem {
  final String type;
  final String base64;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;

  PublicationMediaItem({
    required this.type,
    required this.base64,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  bool get isImage => type.toLowerCase() == 'image';

  bool get isVideo => type.toLowerCase() == 'video';

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'base64': base64,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
    };
  }

  factory PublicationMediaItem.fromJson(Map<String, dynamic> json) {
    return PublicationMediaItem(
      type: json['type']?.toString() ?? '',
      base64: json['base64']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? json['fileName']?.toString(),
      mimeType: json['mime_type']?.toString() ?? json['mimeType']?.toString(),
      sizeBytes: _parseNullableInt(json['size_bytes'] ?? json['sizeBytes']),
    );
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString());
  }
}

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
  final String visibility;

  // Imagen antigua / compatibilidad
  final String? imagePath;

  // Multimedia nueva
  final List<PublicationMediaItem> mediaItems;

  // Archivo / video / documento antiguo
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
    this.visibility = 'contacts',
    this.imagePath,
    this.mediaItems = const [],
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

  String get visibilityLabel {
    switch (visibility) {
      case 'public':
        return 'Pública';
      case 'contacts':
        return 'Contactos';
      case 'private':
        return 'Privada';
      default:
        return 'Contactos';
    }
  }

  bool get hasLocation {
    return location != null && location!.trim().isNotEmpty;
  }

  bool get hasModality {
    return modalityLabel.trim().isNotEmpty;
  }

  bool get hasUserPhoto {
    return userPhoto.trim().isNotEmpty;
  }

  bool get hasMedia {
    return mediaItems.isNotEmpty;
  }

  PublicationMediaItem? get firstMedia {
    if (mediaItems.isEmpty) {
      return null;
    }

    return mediaItems.first;
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
      'visibility': visibility,
      'imagePath': imagePath,
      'media_items': mediaItems.map((item) => item.toJson()).toList(),
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
    String resolvedUserPhoto = json['userPhoto']?.toString() ?? '';

    if (author is Map<String, dynamic>) {
      final firstName =
          author['first_name']?.toString() ??
          author['firstName']?.toString() ??
          '';

      final lastName =
          author['last_name']?.toString() ??
          author['lastName']?.toString() ??
          '';

      final email = author['email']?.toString() ?? '';

      resolvedUserName = '$firstName $lastName'.trim();

      if (resolvedUserName.isEmpty) {
        resolvedUserName = email;
      }

      resolvedUserPhoto =
          author['profile_image_base64']?.toString() ??
          author['profileImageBase64']?.toString() ??
          author['avatar_url']?.toString() ??
          author['avatarUrl']?.toString() ??
          resolvedUserPhoto;
    }

    if (resolvedUserName.isEmpty) {
      resolvedUserName = 'Usuario de Connect Do';
    }

    final List<PublicationMediaItem> parsedMediaItems = _parseMediaItems(
      json['media_items'] ?? json['mediaItems'],
    );

    return PublicationModel(
      id: json['id']?.toString() ?? '',
      userName: resolvedUserName,
      userPhoto: resolvedUserPhoto,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      location: _parseNullableString(json['location']),
      modality: _parseNullableString(json['modality']),
      visibility: json['visibility']?.toString() ?? 'contacts',

      // Backend usa image_url, local usaba imagePath
      imagePath:
          _parseNullableString(json['image_url']) ??
          _parseNullableString(json['imagePath']),

      mediaItems: parsedMediaItems,

      filePath: _parseNullableString(json['filePath']),
      fileName: _parseNullableString(json['fileName']),
      fileType: _parseNullableString(json['fileType']),

      // Backend usa created_at, local usaba createdAt
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),

      likes: _parseInt(json['likes']),
      comments: _parseInt(json['comments']),
    );
  }

  static List<PublicationMediaItem> _parseMediaItems(dynamic value) {
    if (value == null) {
      return [];
    }

    if (value is! List) {
      return [];
    }

    return value
        .whereType<Map>()
        .map((item) {
          return PublicationMediaItem.fromJson(Map<String, dynamic>.from(item));
        })
        .where((item) {
          return item.type.trim().isNotEmpty && item.base64.trim().isNotEmpty;
        })
        .toList();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;

    final text = value.toString();

    if (text.trim().isEmpty || text == 'null') {
      return null;
    }

    return text;
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
