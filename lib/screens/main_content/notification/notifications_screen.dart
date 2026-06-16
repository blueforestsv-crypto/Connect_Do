import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:connect_do/models/notification_model.dart';
import 'package:connect_do/services/notification_service.dart';

import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/contacts/contacts_screen.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';

import 'package:connect_do/utils/responsive_helper.dart';

// ---------------------------------------------------------------------------
// PANTALLA DE NOTIFICACIONES
// ---------------------------------------------------------------------------
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  List<NotificationModel> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // ===============================
  // CARGAR NOTIFICACIONES
  // ===============================
  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
    });

    final data = await NotificationService.getNotifications();

    if (!mounted) return;

    setState(() {
      notifications = data;
      isLoading = false;
    });
  }

  // ===============================
  // MARCAR UNA COMO LEÍDA
  // ===============================
  Future<void> _markAsRead(NotificationModel notification) async {
    if (!notification.isRead) {
      await NotificationService.markAsRead(notification.id);
    }
  }

  // ===============================
  // MARCAR TODAS COMO LEÍDAS
  // ===============================
  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();

    await _loadNotifications();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas las notificaciones fueron marcadas como leídas'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  // ===============================
  // ACCIÓN AL TOCAR NOTIFICACIÓN
  // ===============================
  Future<void> _handleNotificationTap(NotificationModel notification) async {
    await _markAsRead(notification);

    if (!mounted) return;

    setState(() {
      final index = notifications.indexWhere((n) => n.id == notification.id);

      if (index != -1) {
        notifications[index].isRead = true;
      }
    });

    await Future.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;

    switch (notification.type) {
      // ===============================
      // PUBLICACIONES
      // ===============================
      case 'publication':
      case 'publication_created':
      case 'like':
      case 'comment':
      case 'share':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => PublicationDetailScreen(
                  publicationId: notification.referenceId,
                ),
          ),
        );
        break;

      // ===============================
      // CONTACTOS
      // ===============================
      case 'contact_request':
      case 'contact_accepted':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
        );
        break;

      // ===============================
      // MENSAJES
      // ===============================
      case 'message':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
        );
        break;

      // ===============================
      // APLICACIONES / OPORTUNIDADES
      // ===============================
      case 'application':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pantalla de aplicaciones próximamente'),
            backgroundColor: Color(0xFF2563EB),
          ),
        );
        break;

      // ===============================
      // GENERAL
      // ===============================
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación abierta'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
    }
  }

  // ===============================
  // ICONO SEGÚN TIPO
  // ===============================
  Widget _buildTypeIcon(String type, bool isDarkMode) {
    IconData iconData;
    Color bgColor;

    switch (type) {
      case 'like':
        iconData = PhosphorIconsFill.heart;
        bgColor = Colors.red;
        break;

      case 'comment':
        iconData = PhosphorIconsFill.chatCircle;
        bgColor = const Color(0xFF10B970);
        break;

      case 'message':
        iconData = PhosphorIconsFill.chatTeardropText;
        bgColor = const Color(0xFF2563EB);
        break;

      case 'contact_request':
        iconData = PhosphorIconsFill.userPlus;
        bgColor = const Color(0xFF22C55E);
        break;

      case 'contact_accepted':
        iconData = PhosphorIconsFill.handshake;
        bgColor = const Color(0xFF22C55E);
        break;

      case 'publication':
      case 'publication_created':
        iconData = PhosphorIconsFill.checkCircle;
        bgColor = const Color(0xFF22C55E);
        break;

      case 'share':
        iconData = PhosphorIconsFill.shareFat;
        bgColor = Colors.orange;
        break;

      case 'application':
        iconData = PhosphorIconsFill.rocketLaunch;
        bgColor = const Color(0xFF2563EB);
        break;

      default:
        iconData = PhosphorIconsFill.bell;
        bgColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? const Color(0xFF121212) : Colors.white,
          width: 2,
        ),
      ),
      child: Icon(iconData, size: 12, color: Colors.white),
    );
  }

  // ===============================
  // AVATAR
  // ===============================
  Widget _buildAvatar(NotificationModel notif, bool isDarkMode) {
    final avatarBgColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    if (notif.userAvatar.isEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: avatarBgColor,
        child: Icon(
          PhosphorIconsRegular.user,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      );
    }

    if (notif.userAvatar.startsWith('/')) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: avatarBgColor,
        backgroundImage: FileImage(File(notif.userAvatar)),
      );
    }

    return CircleAvatar(
      radius: 25,
      backgroundColor: avatarBgColor,
      backgroundImage: NetworkImage(notif.userAvatar),
      onBackgroundImageError: (_, __) {},
    );
  }

  // ===============================
  // ESTADO VACÍO
  // ===============================
  Widget _buildEmptyState({
    required bool isDarkMode,
    required Color subtitleColor,
    required Color emptyIconColor,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        ResponsiveHelper.bottomSafe(context) + 40,
      ),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),

        Icon(PhosphorIconsRegular.bellSlash, size: 60, color: emptyIconColor),

        const SizedBox(height: 15),

        Text(
          "No tienes notificaciones aún",
          textAlign: TextAlign.center,
          style: TextStyle(color: subtitleColor, fontSize: 16),
        ),

        const SizedBox(height: 8),

        Text(
          "Cuando tengas actividad nueva aparecerá aquí.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ===============================
  // ITEM DE NOTIFICACIÓN
  // ===============================
  Widget _buildNotificationItem({
    required NotificationModel notif,
    required bool isDarkMode,
    required Color textColor,
    required Color subtitleColor,
    required Color unreadBgColor,
    required Color readBgColor,
  }) {
    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      child: Container(
        color: notif.isRead ? readBgColor : unreadBgColor,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildAvatar(notif, isDarkMode),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildTypeIcon(notif.type, isDarkMode),
                ),
              ],
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: "${notif.userName} ",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: notif.content),
                      ],
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    notif.timeAgo,
                    style: TextStyle(
                      color:
                          notif.isRead
                              ? subtitleColor
                              : const Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight:
                          notif.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (!notif.isRead)
              Container(
                margin: const EdgeInsets.only(top: 10, left: 10),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // BUILD
  // ===============================
  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color appBarColor =
        isDarkMode ? const Color(0xFF121212) : Colors.white;

    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    final Color subtitleColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    final Color emptyIconColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;

    final Color unreadBgColor =
        isDarkMode
            ? const Color(0xFF2563EB).withValues(alpha: 0.16)
            : const Color(0xFF2563EB).withValues(alpha: 0.05);

    final Color readBgColor =
        isDarkMode ? const Color(0xFF121212) : Colors.white;

    final bottomSpace = ResponsiveHelper.bottomSafe(context) + 24;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          icon: Icon(
            PhosphorIconsRegular.caretLeft,
            color: textColor,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          "Notificaciones",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),

        centerTitle: true,

        actions: [
          if (notifications.any((n) => !n.isRead))
            IconButton(
              tooltip: "Marcar todas como leídas",
              icon: const Icon(
                PhosphorIconsRegular.checkCircle,
                color: Color(0xFF10B970),
                size: 26,
              ),
              onPressed: _markAllAsRead,
            ),
        ],
      ),

      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B970)),
              )
              : RefreshIndicator(
                color: const Color(0xFF10B970),
                backgroundColor:
                    isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                onRefresh: _loadNotifications,
                child:
                    notifications.isEmpty
                        ? _buildEmptyState(
                          isDarkMode: isDarkMode,
                          subtitleColor: subtitleColor,
                          emptyIconColor: emptyIconColor,
                        )
                        : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: bottomSpace),
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notif = notifications[index];

                            return _buildNotificationItem(
                              notif: notif,
                              isDarkMode: isDarkMode,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              unreadBgColor: unreadBgColor,
                              readBgColor: readBgColor,
                            );
                          },
                        ),
              ),
    );
  }
}
