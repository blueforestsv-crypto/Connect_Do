/// Una postulación a una oportunidad (vista del estudiante o de la empresa).
class ApplicationModel {
  final String id;
  final String publicationId;
  final String studentId;
  final String companyId;
  String status;
  final String? coverMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String publicationTitle;
  final String publicationType;
  final String? location;
  final String? modality;

  final String studentName;
  final String studentPhoto;
  final String companyName;

  /// Datos del perfil al momento de postularse.
  final Map<String, dynamic> snapshot;

  ApplicationModel({
    required this.id,
    required this.publicationId,
    required this.studentId,
    required this.companyId,
    required this.status,
    required this.coverMessage,
    required this.createdAt,
    required this.updatedAt,
    required this.publicationTitle,
    required this.publicationType,
    required this.location,
    required this.modality,
    required this.studentName,
    required this.studentPhoto,
    required this.companyName,
    required this.snapshot,
  });

  bool get hasCv => (snapshot['cv_url']?.toString() ?? '').isNotEmpty;

  String? get career => _text(snapshot['career']);
  String? get university => _text(snapshot['university']);

  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    final publication = _map(json['publication']);
    final student = _map(json['student']);
    final company = _map(json['company']);
    final snapshot = _map(json['profile_snapshot']);

    String name(Map<String, dynamic> user) {
      final full =
          '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
      return full.isEmpty ? (user['email']?.toString() ?? '') : full;
    }

    return ApplicationModel(
      id: json['id'].toString(),
      publicationId: json['publication_id'].toString(),
      studentId: json['student_id'].toString(),
      companyId: json['company_id'].toString(),
      status: json['status']?.toString() ?? 'new',
      coverMessage: _text(json['cover_message']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      publicationTitle: publication['title']?.toString() ?? 'Oportunidad',
      publicationType: publication['type']?.toString() ?? '',
      location: _text(publication['location']),
      modality: _text(publication['modality']),
      studentName: student.isEmpty ? name(snapshot) : name(student),
      studentPhoto:
          student['profile_image_base64']?.toString() ??
          snapshot['profile_image_base64']?.toString() ??
          '',
      companyName: name(company),
      snapshot: snapshot,
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String? _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
}

/// Etiqueta y orden de cada estado, en el idioma de la app.
class ApplicationStatus {
  const ApplicationStatus._();

  static const labels = {
    'new': 'Enviada',
    'reviewed': 'Vista',
    'contacted': 'Contactado',
    'interview': 'Entrevista',
    'selected': 'Seleccionado',
    'rejected': 'No seleccionado',
  };

  static String label(String status) => labels[status] ?? status;

  /// Los que aún esperan respuesta.
  static bool isOpen(String status) =>
      status != 'selected' && status != 'rejected';
}
