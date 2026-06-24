import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/models/contact_request_model.dart';

class ContactService {
  const ContactService._();

  // ===============================
  // OBTENER TOKEN
  // ===============================
  static Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token =
        prefs.getString('access_token') ??
        prefs.getString('accessToken') ??
        prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('No se encontró token de sesión.');
    }

    return token;
  }

  // ===============================
  // HEADERS CON TOKEN
  // ===============================
  static Future<Map<String, String>> _headers() async {
    final token = await _getAccessToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ===============================
  // OBTENER USUARIO LOCAL ACTUAL
  // ===============================
  static Future<Map<String, dynamic>> _getCurrentLocalUser() async {
    final prefs = await SharedPreferences.getInstance();

    final userJson = prefs.getString('usuario_actual');

    if (userJson == null || userJson.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ===============================
  // BUSCAR USUARIOS REALES
  // ===============================
  static Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    final headers = await _headers();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/contacts/users/search?q=$query&limit=$limit',
    );

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Error al buscar usuarios: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  // ===============================
  // ENVIAR SOLICITUD REAL
  // ===============================
  static Future<Map<String, dynamic>> sendContactRequest({
    required String receiverId,
  }) async {
    final headers = await _headers();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/contacts/requests/$receiverId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error al enviar solicitud: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ===============================
  // SOLICITUDES RECIBIDAS REALES
  // ===============================
  static Future<List<ContactRequestModel>> getIncomingRequests() async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/contacts/requests/incoming'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar solicitudes recibidas: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded
        .map((item) => _contactRequestFromBackend(item as Map<String, dynamic>))
        .toList();
  }

  // ===============================
  // SOLICITUDES ENVIADAS REALES
  // ===============================
  static Future<List<ContactRequestModel>> getOutgoingRequests() async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/contacts/requests/outgoing'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar solicitudes enviadas: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded
        .map((item) => _contactRequestFromBackend(item as Map<String, dynamic>))
        .toList();
  }

  // ===============================
  // CONTACTOS ACEPTADOS REALES
  // ===============================
  static Future<List<Map<String, dynamic>>> getAcceptedContacts() async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/contacts'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al cargar contactos: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  // ===============================
  // ACEPTAR SOLICITUD REAL
  // ===============================
  static Future<ContactRequestModel> acceptRequest(String requestId) async {
    final headers = await _headers();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/contacts/requests/$requestId/accept'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al aceptar solicitud: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return _contactRequestFromBackend(data);
  }

  // ===============================
  // RECHAZAR SOLICITUD REAL
  // ===============================
  static Future<ContactRequestModel> rejectRequest(String requestId) async {
    final headers = await _headers();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/contacts/requests/$requestId/reject'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Error al rechazar solicitud: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return _contactRequestFromBackend(data);
  }

  // =====================================================
  // COMPATIBILIDAD TEMPORAL CON CONTACTS_SCREEN ACTUAL
  // =====================================================
  // Tu pantalla actual usa getRequests() y filtra localmente.
  // Este método mezcla:
  // - solicitudes recibidas
  // - solicitudes enviadas
  // - contactos aceptados
  //
  // Después reemplazamos ContactsScreen para usar los métodos reales directamente.
  static Future<List<ContactRequestModel>> getRequests() async {
    final currentUser = await _getCurrentLocalUser();

    final currentEmail = currentUser['email']?.toString() ?? '';
    final currentName = _buildLocalUserName(currentUser);

    final incoming = await getIncomingRequests();
    final outgoing = await getOutgoingRequests();
    final contacts = await getAcceptedContacts();

    final acceptedAsRequests =
        contacts.map((contact) {
          final contactId = contact['id']?.toString() ?? '';
          final contactEmail = contact['email']?.toString() ?? '';
          final contactName = _buildBackendUserName(contact);
          final contactPhoto =
              contact['profile_image_base64']?.toString() ?? '';

          return ContactRequestModel.fromJson({
            'id': 'accepted_$contactId',
            'requesterId': currentEmail,
            'receiverId': contactEmail,
            'requesterName': currentName,
            'receiverName': contactName,
            'requesterPhoto': '',
            'receiverPhoto': contactPhoto,
            'status': 'accepted',
            'createdAt': DateTime.now().toIso8601String(),
          });
        }).toList();

    return [...incoming, ...outgoing, ...acceptedAsRequests];
  }

  // ===============================
  // MÉTODOS ANTIGUOS ADAPTADOS
  // ===============================
  // Este método queda para no romper imports viejos.
  // Para enviar solicitudes reales usaremos sendContactRequest(receiverId: ...)
  static Future<void> sendRequest(ContactRequestModel request) async {
    await sendContactRequest(receiverId: request.receiverId);
  }

  static Future<void> deleteRequest(String requestId) async {
    // Por ahora no tenemos endpoint de cancelar/eliminar.
    // Lo dejamos como no-op para no romper llamadas existentes.
    return;
  }

  static Future<List<ContactRequestModel>> getReceivedRequests(
    String userId,
  ) async {
    return getIncomingRequests();
  }

  static Future<List<ContactRequestModel>> getSentRequests(
    String userId,
  ) async {
    return getOutgoingRequests();
  }

  static Future<List<ContactRequestModel>> getContacts(String userId) async {
    final allRequests = await getRequests();

    return allRequests.where((request) {
      return request.status == 'accepted';
    }).toList();
  }

  static Future<String> getContactStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final users = await searchUsers(query: '');

    for (final user in users) {
      final id = user['id']?.toString() ?? '';

      if (id != otherUserId) continue;

      final status = user['contact_status']?.toString();

      if (status == null || status.isEmpty || status == 'null') {
        return 'none';
      }

      if (status == 'accepted') {
        return 'accepted';
      }

      if (status == 'pending') {
        return 'pending';
      }

      if (status == 'rejected') {
        return 'rejected';
      }

      return status;
    }

    return 'none';
  }

  static Future<void> clearContacts() async {
    // Ya no usamos almacenamiento local para contactos.
    return;
  }

  // =====================================================
  // MAPEADORES
  // =====================================================
  static ContactRequestModel _contactRequestFromBackend(
    Map<String, dynamic> data,
  ) {
    final requester = data['requester'] as Map<String, dynamic>? ?? {};
    final receiver = data['receiver'] as Map<String, dynamic>? ?? {};

    return ContactRequestModel.fromJson({
      'id': data['id']?.toString() ?? '',
      'requesterId':
          requester['email']?.toString() ??
          data['requester_id']?.toString() ??
          '',
      'receiverId':
          receiver['email']?.toString() ??
          data['receiver_id']?.toString() ??
          '',
      'requesterName': _buildBackendUserName(requester),
      'receiverName': _buildBackendUserName(receiver),
      'requesterPhoto': requester['profile_image_base64']?.toString() ?? '',
      'receiverPhoto': receiver['profile_image_base64']?.toString() ?? '',
      'status': data['status']?.toString() ?? 'pending',
      'createdAt':
          data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    });
  }

  static String _buildBackendUserName(Map<String, dynamic> user) {
    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    if (email.isNotEmpty) {
      return email;
    }

    return 'Usuario de Connect Do';
  }

  static String _buildLocalUserName(Map<String, dynamic> user) {
    final firstName = user['firstName']?.toString() ?? '';
    final lastName = user['lastName']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    if (email.isNotEmpty) {
      return email;
    }

    return 'Usuario de Connect Do';
  }
}
