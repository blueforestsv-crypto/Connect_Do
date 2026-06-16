import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:project_ena/models/contact_request_model.dart';

class ContactService {
  static const String _storageKey = 'contact_requests';

  // ===============================
  // OBTENER TODAS LAS SOLICITUDES
  // ===============================
  static Future<List<ContactRequestModel>> getRequests() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_storageKey);

    if (data == null) {
      return [];
    }

    final List decoded = jsonDecode(data);

    return decoded.map((item) => ContactRequestModel.fromJson(item)).toList();
  }

  // ===============================
  // GUARDAR LISTA COMPLETA
  // ===============================
  static Future<void> _saveRequests(List<ContactRequestModel> requests) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = requests.map((request) => request.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ===============================
  // ENVIAR SOLICITUD
  // ===============================
  static Future<void> sendRequest(ContactRequestModel request) async {
    final requests = await getRequests();

    final alreadyExists = requests.any((item) {
      final sameDirection =
          item.requesterId == request.requesterId &&
          item.receiverId == request.receiverId;

      final inverseDirection =
          item.requesterId == request.receiverId &&
          item.receiverId == request.requesterId;

      return sameDirection || inverseDirection;
    });

    if (alreadyExists) {
      return;
    }

    requests.insert(0, request);

    await _saveRequests(requests);
  }

  // ===============================
  // ACEPTAR SOLICITUD
  // ===============================
  static Future<void> acceptRequest(String requestId) async {
    final requests = await getRequests();

    final updatedRequests =
        requests.map((request) {
          if (request.id == requestId) {
            return request.copyWith(status: 'accepted');
          }

          return request;
        }).toList();

    await _saveRequests(updatedRequests);
  }

  // ===============================
  // RECHAZAR SOLICITUD
  // ===============================
  static Future<void> rejectRequest(String requestId) async {
    final requests = await getRequests();

    final updatedRequests =
        requests.map((request) {
          if (request.id == requestId) {
            return request.copyWith(status: 'rejected');
          }

          return request;
        }).toList();

    await _saveRequests(updatedRequests);
  }

  // ===============================
  // ELIMINAR CONTACTO / SOLICITUD
  // ===============================
  static Future<void> deleteRequest(String requestId) async {
    final requests = await getRequests();

    requests.removeWhere((request) => request.id == requestId);

    await _saveRequests(requests);
  }

  // ===============================
  // SOLICITUDES RECIBIDAS
  // ===============================
  static Future<List<ContactRequestModel>> getReceivedRequests(
    String userId,
  ) async {
    final requests = await getRequests();

    return requests.where((request) {
      return request.receiverId == userId && request.status == 'pending';
    }).toList();
  }

  // ===============================
  // SOLICITUDES ENVIADAS
  // ===============================
  static Future<List<ContactRequestModel>> getSentRequests(
    String userId,
  ) async {
    final requests = await getRequests();

    return requests.where((request) {
      return request.requesterId == userId && request.status == 'pending';
    }).toList();
  }

  // ===============================
  // CONTACTOS ACEPTADOS
  // ===============================
  static Future<List<ContactRequestModel>> getContacts(String userId) async {
    final requests = await getRequests();

    return requests.where((request) {
      final isUserInRequest =
          request.requesterId == userId || request.receiverId == userId;

      return isUserInRequest && request.status == 'accepted';
    }).toList();
  }

  // ===============================
  // SABER ESTADO ENTRE DOS USUARIOS
  // ===============================
  static Future<String> getContactStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final requests = await getRequests();

    for (final request in requests) {
      final sameDirection =
          request.requesterId == currentUserId &&
          request.receiverId == otherUserId;

      final inverseDirection =
          request.requesterId == otherUserId &&
          request.receiverId == currentUserId;

      if (sameDirection || inverseDirection) {
        if (request.status == 'accepted') {
          return 'accepted';
        }

        if (request.status == 'rejected') {
          return 'rejected';
        }

        if (request.status == 'pending') {
          if (sameDirection) {
            return 'sent';
          } else {
            return 'received';
          }
        }
      }
    }

    return 'none';
  }

  // ===============================
  // LIMPIAR TODO
  // ===============================
  static Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }
}
