class PublicationModel {
  final String id;
  final String userName;
  final String userPhoto;
  final String description;

  // IMAGEN
  final String? imagePath;

  // ARCHIVO / VIDEO / DOCUMENTO
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
      'description': description,
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
    return PublicationModel(
      id: json['id'] ?? '',
      userName: json['userName'] ?? '',
      userPhoto: json['userPhoto'] ?? '',
      description: json['description'] ?? '',
      imagePath: json['imagePath'],
      filePath: json['filePath'],
      fileName: json['fileName'],
      fileType: json['fileType'],
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
    );
  }
}
