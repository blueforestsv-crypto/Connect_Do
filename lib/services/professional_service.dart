import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';

/// Tipos de línea del perfil, con su nombre en la app.
const entryKinds = <String, String>{
  'experience': 'Experiencia',
  'education': 'Formación',
  'certification': 'Certificaciones',
  'project': 'Proyectos',
  'language': 'Idiomas',
  'volunteer': 'Voluntariado',
};

class ProfileEntry {
  final String id;
  final String kind;
  final String title;
  final String? organization;
  final String? location;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;
  final String? url;

  const ProfileEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.organization,
    this.location,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
    this.url,
  });

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory ProfileEntry.fromJson(Map<String, dynamic> json) => ProfileEntry(
    id: json['id'].toString(),
    kind: json['kind'].toString(),
    title: json['title']?.toString() ?? '',
    organization: json['organization']?.toString(),
    location: json['location']?.toString(),
    startDate: _date(json['start_date']),
    endDate: _date(json['end_date']),
    isCurrent: json['is_current'] == true,
    description: json['description']?.toString(),
    url: json['url']?.toString(),
  );

  Map<String, dynamic> toJson() {
    String? day(DateTime? d) =>
        d == null
            ? null
            : '${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-01';
    return {
      'kind': kind,
      'title': title,
      'organization': organization,
      'location': location,
      'start_date': day(startDate),
      'end_date': isCurrent ? null : day(endDate),
      'is_current': isCurrent,
      'description': description,
      'url': url,
    };
  }

  /// "ene 2024 – actualidad · 1 año 3 meses"
  String get period {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    String label(DateTime d) => '${months[d.month - 1]} ${d.year}';
    final start = startDate;
    if (start == null) return isCurrent ? 'Actualidad' : '';
    final end = isCurrent ? null : endDate;
    final range =
        '${label(start)} – ${end == null ? 'actualidad' : label(end)}';
    final last = end ?? DateTime.now();
    final totalMonths =
        (last.year - start.year) * 12 + last.month - start.month + 1;
    if (totalMonths <= 0) return range;
    final years = totalMonths ~/ 12;
    final rest = totalMonths % 12;
    final parts = [
      if (years > 0) years == 1 ? '1 año' : '$years años',
      if (rest > 0) rest == 1 ? '1 mes' : '$rest meses',
    ];
    return '$range · ${parts.join(' ')}';
  }
}

class SkillDetail {
  final String name;
  int count;
  bool endorsedByMe;

  SkillDetail({
    required this.name,
    required this.count,
    required this.endorsedByMe,
  });

  factory SkillDetail.fromJson(Map<String, dynamic> json) => SkillDetail(
    name: json['name'].toString(),
    count: (json['count'] as num?)?.toInt() ?? 0,
    endorsedByMe: json['endorsed_by_me'] == true,
  );
}

class ProfileVisitor {
  final String userId;
  final String name;
  final String? headline;
  final String photo;
  final DateTime viewedAt;

  const ProfileVisitor({
    required this.userId,
    required this.name,
    required this.headline,
    required this.photo,
    required this.viewedAt,
  });
}

class JobAlert {
  final String id;
  final String? query;
  final String? type;
  final String? modality;
  final String? location;

  const JobAlert({
    required this.id,
    this.query,
    this.type,
    this.modality,
    this.location,
  });

  factory JobAlert.fromJson(Map<String, dynamic> json) => JobAlert(
    id: json['id'].toString(),
    query: json['query']?.toString(),
    type: json['type']?.toString(),
    modality: json['modality']?.toString(),
    location: json['location']?.toString(),
  );
}

class PendingCompany {
  final String userId;
  final String name;
  final String email;
  final String? sector;
  final String? website;

  const PendingCompany({
    required this.userId,
    required this.name,
    required this.email,
    this.sector,
    this.website,
  });
}

/// Lo profesional del perfil y los empleos.
class ProfessionalService {
  const ProfessionalService._();

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) throw Exception('Tu sesión expiró.');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static dynamic _decode(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    var message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] is String) {
        message = data['detail'];
      } else if (data is Map && data['detail'] is List) {
        final first = (data['detail'] as List).first;
        if (first is Map && first['msg'] != null) {
          message = first['msg'].toString().replaceFirst('Value error, ', '');
        }
      }
    } catch (_) {}
    throw Exception(message);
  }

  // ---------------- tipo de cuenta ----------------
  static Future<Map<String, dynamic>> setAccountType({
    required String accountType,
    String? companyName,
    String? sector,
    String? size,
  }) async {
    final response = await http.put(
      _uri('/auth/account-type'),
      headers: await _headers(),
      body: jsonEncode({
        'account_type': accountType,
        if (companyName != null) 'company_name': companyName,
        if (sector != null && sector.isNotEmpty) 'company_sector': sector,
        if (size != null && size.isNotEmpty) 'company_size': size,
      }),
    );
    return Map<String, dynamic>.from(
      _decode(response, 'No se pudo cambiar el tipo de cuenta.') as Map,
    );
  }

  static Future<void> requestVerification() async {
    final response = await http.post(
      _uri('/companies/verification-request'),
      headers: await _headers(),
    );
    _decode(response, 'No se pudo pedir la verificación.');
  }

  // ---------------- experiencia, formación… ----------------
  static Future<List<ProfileEntry>> myEntries() async {
    final response = await http.get(
      _uri('/profiles/me/entries'),
      headers: await _headers(),
    );
    final data = _decode(response, 'No se pudo cargar tu experiencia.');
    return [
      for (final item in data as List)
        ProfileEntry.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  static Future<ProfileEntry> saveEntry(
    ProfileEntry entry, {
    String? id,
  }) async {
    final response =
        id == null
            ? await http.post(
              _uri('/profiles/me/entries'),
              headers: await _headers(),
              body: jsonEncode(entry.toJson()),
            )
            : await http.put(
              _uri('/profiles/me/entries/$id'),
              headers: await _headers(),
              body: jsonEncode(entry.toJson()),
            );
    final data = _decode(response, 'No se pudo guardar.');
    return ProfileEntry.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> deleteEntry(String id) async {
    final response = await http.delete(
      _uri('/profiles/me/entries/$id'),
      headers: await _headers(),
    );
    _decode(response, 'No se pudo borrar.');
  }

  // ---------------- validar habilidades ----------------
  static Future<List<SkillDetail>> endorse(
    String userId,
    String skill, {
    required bool endorse,
  }) async {
    final request =
        http.Request(
            endorse ? 'POST' : 'DELETE',
            _uri('/profiles/$userId/endorse'),
          )
          ..headers.addAll(await _headers())
          ..body = jsonEncode({'skill': skill});
    final response = await http.Response.fromStream(
      await http.Client().send(request),
    );
    final data = _decode(response, 'No se pudo validar.');
    return [
      for (final item in data as List)
        SkillDetail.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  // ---------------- visitas ----------------
  static Future<({int total, List<ProfileVisitor> visitors})> myViews() async {
    final response = await http.get(
      _uri('/profiles/me/views'),
      headers: await _headers(),
    );
    final data = Map<String, dynamic>.from(
      _decode(response, 'No se pudieron cargar las visitas.') as Map,
    );
    return (
      total: (data['total_30_days'] as num?)?.toInt() ?? 0,
      visitors: [
        for (final item in data['visitors'] as List)
          ProfileVisitor(
            userId: item['user_id'].toString(),
            name: item['name']?.toString() ?? '',
            headline: item['headline']?.toString(),
            photo: item['profile_image_base64']?.toString() ?? '',
            viewedAt:
                DateTime.tryParse(item['viewed_at'].toString())?.toLocal() ??
                DateTime.now(),
          ),
      ],
    );
  }

  // ---------------- alertas ----------------
  static Future<List<JobAlert>> alerts() async {
    final response = await http.get(
      _uri('/job-alerts'),
      headers: await _headers(),
    );
    final data = _decode(response, 'No se pudieron cargar tus alertas.');
    return [
      for (final item in data as List)
        JobAlert.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  static Future<JobAlert> createAlert({
    String? query,
    String? type,
    String? modality,
    String? location,
  }) async {
    final response = await http.post(
      _uri('/job-alerts'),
      headers: await _headers(),
      body: jsonEncode({
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (type != null) 'type': type,
        if (modality != null) 'modality': modality,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
      }),
    );
    final data = _decode(response, 'No se pudo crear la alerta.');
    return JobAlert.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> deleteAlert(String id) async {
    final response = await http.delete(
      _uri('/job-alerts/$id'),
      headers: await _headers(),
    );
    _decode(response, 'No se pudo borrar la alerta.');
  }

  // ---------------- moderación de empresas ----------------
  static Future<List<PendingCompany>> pendingCompanies() async {
    final response = await http.get(
      _uri('/admin/companies'),
      headers: await _headers(),
    );
    final data = _decode(response, 'No se pudieron cargar las empresas.');
    return [
      for (final item in data as List)
        PendingCompany(
          userId: item['user_id'].toString(),
          name: item['company_name']?.toString() ?? '',
          email: item['email']?.toString() ?? '',
          sector: item['company_sector']?.toString(),
          website: item['website']?.toString(),
        ),
    ];
  }

  static Future<void> verifyCompany(String userId, {required bool ok}) async {
    final response = await http.post(
      _uri('/admin/companies/$userId/verify'),
      headers: await _headers(),
      body: jsonEncode({'verified': ok}),
    );
    _decode(response, 'No se pudo guardar.');
  }
}
