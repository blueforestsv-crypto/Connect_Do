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

  bool get isImage => type == 'image';

  bool get isVideo => type == 'video';

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
      sizeBytes: _parseInt(json['size_bytes'] ?? json['sizeBytes']),
    );
  }

  static int? _parseInt(dynamic value) {
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

  // Imagen antigua
  final String? imagePath;

  // Multimedia nueva
  final List<PublicationMediaItem> mediaItems;

  // Archivo / video / documento local antiguo
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

  bool get hasMedia {
    return mediaItems.isNotEmpty;
  }

  PublicationMediaItem? get firstMedia {
    if (mediaItems.isEmpty) return null;

    return mediaItems.first;
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

  String get visibilityLabel {
    switch (visibility) {
      case 'public':
        return 'Público';
      case 'contacts':
        return 'Solo contactos';
      case 'private':
        return 'Privado';
      default:
        return 'Solo contactos';
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

    final rawMediaItems = json['media_items'] ?? json['mediaItems'];

    final List<PublicationMediaItem> parsedMediaItems = [];

    if (rawMediaItems is List) {
      for (final item in rawMediaItems) {
        if (item is Map<String, dynamic>) {
          parsedMediaItems.add(PublicationMediaItem.fromJson(item));
        }
      }
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
      visibility: json['visibility']?.toString() ?? 'contacts',

      imagePath: json['image_url']?.toString() ?? json['imagePath']?.toString(),

      mediaItems: parsedMediaItems,

      filePath: json['filePath']?.toString(),
      fileName: json['fileName']?.toString(),
      fileType: json['fileType']?.toString(),

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
