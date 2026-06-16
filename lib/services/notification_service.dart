import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:project_ena/models/notification_model.dart';

class NotificationService {
  static const String _storageKey = 'app_notifications';

  // ==========================
  // OBTENER NOTIFICACIONES
  // ==========================
  static Future<List<NotificationModel>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getString(_storageKey);

    if (data == null) {
      return [];
    }

    final List decoded = jsonDecode(data);

    final notifications =
        decoded.map((item) => NotificationModel.fromJson(item)).toList();

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notifications;
  }

  // ==========================
  // AGREGAR NOTIFICACIÓN
  // ==========================
  static Future<void> addNotification(NotificationModel notification) async {
    final prefs = await SharedPreferences.getInstance();

    final notifications = await getNotifications();

    notifications.insert(0, notification);

    final jsonList =
        notifications.map((notification) => notification.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ==========================
  // MARCAR UNA COMO LEÍDA
  // ==========================
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final notifications = await getNotifications();

    final updated =
        notifications.map((notification) {
          if (notification.id == id) {
            notification.isRead = true;
          }

          return notification;
        }).toList();

    final jsonList =
        updated.map((notification) => notification.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ==========================
  // MARCAR TODAS COMO LEÍDAS
  // ==========================
  static Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();

    final notifications = await getNotifications();

    final updated =
        notifications.map((notification) {
          notification.isRead = true;
          return notification;
        }).toList();

    final jsonList =
        updated.map((notification) => notification.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ==========================
  // ELIMINAR NOTIFICACIÓN
  // ==========================
  static Future<void> deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final notifications = await getNotifications();

    notifications.removeWhere((notification) => notification.id == id);

    final jsonList =
        notifications.map((notification) => notification.toJson()).toList();

    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // ==========================
  // LIMPIAR TODAS
  // ==========================
  static Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
  }

  // ==========================
  // HELPERS RÁPIDOS
  // ==========================

  static Future<void> notifyPublicationCreated({
    required String userId,
    required String userName,
    required String userAvatar,
    required String publicationId,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'publication_created',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: 'tu publicación se subió correctamente.',
      timeAgo: 'Ahora',
      referenceId: publicationId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await addNotification(notification);
  }

  static Future<void> notifyContactRequest({
    required String userId,
    required String userName,
    required String userAvatar,
    required String requestId,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'contact_request',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: 'quiere agregarte como contacto.',
      timeAgo: 'Ahora',
      referenceId: requestId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await addNotification(notification);
  }

  static Future<void> notifyContactAccepted({
    required String userId,
    required String userName,
    required String userAvatar,
    required String requestId,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'contact_accepted',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: 'aceptó tu solicitud de contacto.',
      timeAgo: 'Ahora',
      referenceId: requestId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await addNotification(notification);
  }

  static Future<void> notifyNewMessage({
    required String userId,
    required String userName,
    required String userAvatar,
    required String chatId,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'message',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: 'te envió un nuevo mensaje.',
      timeAgo: 'Ahora',
      referenceId: chatId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await addNotification(notification);
  }

  static Future<void> notifySharedInterest({
    required String userId,
    required String userName,
    required String userAvatar,
    required String referenceId,
  }) async {
    final notification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'share',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: 'compartió algo que podría interesarte.',
      timeAgo: 'Ahora',
      referenceId: referenceId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await addNotification(notification);
  }
}
