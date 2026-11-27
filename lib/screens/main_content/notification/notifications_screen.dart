import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/settings/account_type_screen.dart';
import 'package:connect_do/models/notification_model.dart';
import 'package:connect_do/screens/applications/my_applications_screen.dart';
import 'package:connect_do/screens/applications/received_applications_screen.dart';
import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/screens/main_content/contacts/contacts_screen.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';
import 'package:connect_do/services/notification_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<NotificationModel> _notifications = [];

  bool get _hasUnread => _notifications.any((n) => !n.isRead);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final previous = {for (final n in _notifications) n.id: n.isRead};
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });

    try {
      await NotificationService.markAllAsRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        for (final n in _notifications) {
          n.isRead = previous[n.id] ?? n.isRead;
        }
      });
      showAuthMessage(context, 'No se pudieron marcar como leídas.');
    }
  }

  Future<void> _open(NotificationModel notification) async {
    if (!notification.isRead) {
      setState(() => notification.isRead = true);
      NotificationService.markAsRead(notification.id).ignore();
    }

    final Widget? destination = switch (notification.type) {
      'like' ||
      'comment' ||
      'publication' ||
      'opportunity' ||
      'share' ||
      'job_alert' when notification.publicationId != null =>
        PublicationDetailScreen(publicationId: notification.publicationId!),
      'contact_request' => const ContactsScreen(initialTabIndex: 2),
      'contact_accepted' => const ContactsScreen(initialTabIndex: 1),
      'message' || 'application_contact' when notification.actorId.isNotEmpty =>
        IndividualChatScreen(
          chatId: notification.actorId,
          chatName:
              notification.actorName.isEmpty ? 'Chat' : notification.actorName,
          chatAvatar: notification.actorPhoto,
        ),
      'message' => const ChatListScreen(),
      'application_new' => const ReceivedApplicationsScreen(),
      'company_verification' => const AccountTypeScreen(),
      'application_status' => const MyApplicationsScreen(),
      _ => null,
    };

    if (destination == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            AuthBackButton(onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 12),
            Text(
              'Notificaciones',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
          ],
        ),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Marcar todo',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontWeight: FontWeight.w700,
                  color: Brand.blue,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Brand.blue,
                  strokeWidth: 2.5,
                ),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    _notifications.isEmpty
                        ? _Message(
                          icon:
                              _hasError
                                  ? PhosphorIconsRegular.cloudSlash
                                  : PhosphorIconsRegular.bellSimple,
                          title:
                              _hasError
                                  ? 'No se pudieron cargar'
                                  : 'Estás al día',
                          subtitle:
                              _hasError
                                  ? 'Desliza hacia abajo para reintentar.'
                                  : 'Aquí verás likes, comentarios, mensajes '
                                      'y solicitudes de contacto.',
                        )
                        : ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            ResponsiveHelper.bottomSafe(context) + 24,
                          ),
                          children: [
                            if (unread.isNotEmpty) ...[
                              _SectionTitle('Nuevas', count: unread.length),
                              _Group(
                                children: [
                                  for (final n in unread)
                                    _NotificationTile(
                                      notification: n,
                                      onTap: () => _open(n),
                                    ),
                                ],
                              ),
                            ],
                            if (read.isNotEmpty) ...[
                              const _SectionTitle('Anteriores'),
                              _Group(
                                children: [
                                  for (final n in read)
                                    _NotificationTile(
                                      notification: n,
                                      onTap: () => _open(n),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
              ),
    );
  }
}

// =====================================================
// PIEZAS
// =====================================================

/// Ícono y color por tipo de notificación.
(IconData, Color) notificationStyle(String type) {
  return switch (type) {
    'like' => (PhosphorIconsFill.heart, const Color(0xFFEF4444)),
    'comment' => (PhosphorIconsFill.chatCircle, Brand.blue),
    'message' ||
    'application_contact' => (PhosphorIconsFill.chatTeardropText, Brand.blue),
    'contact_request' => (PhosphorIconsFill.userPlus, Brand.green),
    'contact_accepted' => (PhosphorIconsFill.handshake, Brand.green),
    'opportunity' => (PhosphorIconsFill.briefcase, const Color(0xFF8B5CF6)),
    'application_new' => (PhosphorIconsFill.tray, const Color(0xFF8B5CF6)),
    'job_alert' => (PhosphorIconsFill.bellRinging, const Color(0xFF8B5CF6)),
    'skill_endorsement' => (PhosphorIconsFill.sealCheck, Brand.green),
    'company_verification' => (PhosphorIconsFill.sealCheck, Brand.blue),
    'application_status' => (
      PhosphorIconsFill.paperPlaneTilt,
      const Color(0xFFF59E0B),
    ),
    'publication' => (PhosphorIconsFill.newspaper, Brand.blue),
    _ => (PhosphorIconsFill.bellSimple, const Color(0xFF64748B)),
  };
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final int? count;

  const _SectionTitle(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: palette.muted,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: Brand.blue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Material(
      color: palette.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 72, color: palette.cardBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final (icon, color) = notificationStyle(notification.type);
    final hasActor = notification.actorName.isNotEmpty;
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            unread
                ? Brand.blue.withValues(alpha: palette.isDark ? 0.10 : 0.04)
                : null,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                hasActor
                    ? UserAvatar(
                      name: notification.actorName,
                      photo: notification.actorPhoto,
                    )
                    : CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, color: color, size: 20),
                    ),
                if (hasActor)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.card, width: 2),
                      ),
                      child: Icon(icon, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message.isNotEmpty
                        ? notification.message
                        : notification.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: palette.title,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notification.title} · ${timeAgo(notification.createdAt)}',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread ? Brand.blue : palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Brand.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 120),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Brand.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Brand.blue),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: palette.title,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 14,
            height: 1.4,
            color: palette.body,
          ),
        ),
      ],
    );
  }
}
