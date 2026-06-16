class ContactRequestModel {
  final String id;

  final String requesterId;
  final String requesterName;
  final String requesterPhoto;

  final String receiverId;
  final String receiverName;
  final String receiverPhoto;

  /// Estados posibles:
  /// pending = pendiente
  /// accepted = aceptada
  /// rejected = rechazada
  final String status;

  final DateTime createdAt;

  ContactRequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterPhoto,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.status,
    required this.createdAt,
  });

  factory ContactRequestModel.fromJson(Map<String, dynamic> json) {
    return ContactRequestModel(
      id: json['id'] ?? '',
      requesterId: json['requesterId'] ?? '',
      requesterName: json['requesterName'] ?? '',
      requesterPhoto: json['requesterPhoto'] ?? '',
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverPhoto: json['receiverPhoto'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterPhoto': requesterPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ContactRequestModel copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? requesterPhoto,
    String? receiverId,
    String? receiverName,
    String? receiverPhoto,
    String? status,
    DateTime? createdAt,
  }) {
    return ContactRequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterPhoto: requesterPhoto ?? this.requesterPhoto,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhoto: receiverPhoto ?? this.receiverPhoto,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
