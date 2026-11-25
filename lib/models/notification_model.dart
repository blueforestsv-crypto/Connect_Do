/// Notificación tal como la devuelve el backend (GET /notifications).
class NotificationModel {
  final String id;

  /// like, comment, message, contact_request, contact_accepted,
  /// publication, opportunity...
  final String type;
  final String title;
  final String message;

  /// Quién generó el aviso (puede no venir).
  final String actorId;
  final String actorName;
  final String actorPhoto;

  final String? publicationId;
  final String? contactRequestId;
  final String? messageId;

  final DateTime createdAt;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.actorId = '',
    this.actorName = '',
    this.actorPhoto = '',
    this.publicationId,
    this.contactRequestId,
    this.messageId,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor =
        json['related_user'] is Map<String, dynamic>
            ? json['related_user'] as Map<String, dynamic>
            : const <String, dynamic>{};

    String? id(String key) {
      final value = json[key]?.toString() ?? '';
      return value.isEmpty || value == 'null' ? null : value;
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      actorId: actor['id']?.toString() ?? id('related_user_id') ?? '',
      actorName:
          '${actor['first_name'] ?? ''} ${actor['last_name'] ?? ''}'.trim(),
      actorPhoto: actor['profile_image_base64']?.toString() ?? '',
      publicationId: id('related_publication_id'),
      contactRequestId: id('related_contact_request_id'),
      messageId: id('related_message_id'),
      isRead: json['is_read'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
