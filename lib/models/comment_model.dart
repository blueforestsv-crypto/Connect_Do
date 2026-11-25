/// Comentario de una publicación, tal como lo devuelve el backend.
class CommentModel {
  final String id;
  final String publicationId;
  final String authorId;
  final String authorName;

  /// Foto del autor en base64 (puede venir vacía).
  final String authorPhoto;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Lo escribió el usuario actual.
  final bool isMine;

  /// El usuario actual puede borrarlo (es suyo o es el autor de la publicación).
  final bool canDelete;

  const CommentModel({
    required this.id,
    required this.publicationId,
    required this.authorId,
    required this.authorName,
    required this.authorPhoto,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.isMine = false,
    this.canDelete = false,
  });

  bool get wasEdited => updatedAt.difference(createdAt).inSeconds > 2;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author =
        json['author'] is Map<String, dynamic>
            ? json['author'] as Map<String, dynamic>
            : const <String, dynamic>{};

    final name =
        '${author['first_name'] ?? ''} ${author['last_name'] ?? ''}'.trim();
    final createdAt = _parseDate(json['created_at']);

    return CommentModel(
      id: json['id']?.toString() ?? '',
      publicationId: json['publication_id']?.toString() ?? '',
      authorId: author['id']?.toString() ?? '',
      authorName: name.isEmpty ? 'Usuario' : name,
      authorPhoto: author['profile_image_base64']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt:
          json['updated_at'] == null
              ? createdAt
              : _parseDate(json['updated_at']),
      isMine: json['is_mine'] == true,
      canDelete: json['can_delete'] == true,
    );
  }

  static DateTime _parseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        DateTime.now();
  }
}
