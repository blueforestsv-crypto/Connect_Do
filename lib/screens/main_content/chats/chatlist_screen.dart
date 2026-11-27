import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/stories/stories_row.dart';
import 'package:connect_do/screens/main_content/contacts/contacts_screen.dart';
import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/services/group_service.dart';
import 'package:connect_do/services/realtime_service.dart';
import 'package:connect_do/screens/main_content/chats/group_info_screen.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

import 'individual_chat_screen.dart';

/// Lista de conversaciones.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ChatListModel> _chats = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _query = '';
  String _myId = '';

  final GlobalKey<StoriesRowState> _storiesKey = GlobalKey<StoriesRowState>();

  List<ChatListModel> get _visibleChats {
    if (_query.isEmpty) return _chats;
    return _chats.where((chat) {
      return chat.userName.toLowerCase().contains(_query) ||
          chat.lastMessage.toLowerCase().contains(_query);
    }).toList();
  }

  StreamSubscription<Map<String, dynamic>>? _live;
  Timer? _reloadSoon;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _query) setState(() => _query = query);
    });
    RealtimeService.instance.ensureConnected();
    _live = RealtimeService.instance.events.listen(_onEvent);
    _load();
  }

  /// Mensaje nuevo, eliminado o cambio en un grupo: se recarga la lista
  /// (agrupando varios avisos seguidos en una sola consulta).
  void _onEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'presence':
        if (mounted) setState(() {});
      case 'message' ||
          'group_message' ||
          'deleted' ||
          'group_updated' ||
          'read':
        _reloadSoon?.cancel();
        _reloadSoon = Timer(const Duration(milliseconds: 800), () {
          if (mounted) _load();
        });
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    _reloadSoon?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_myId.isEmpty) {
      _myId = (await UserService.getUser())['id']?.toString() ?? '';
    }

    try {
      final results = await Future.wait([
        ChatService.getConversations(),
        // Si los grupos fallan, igual se muestran los chats.
        GroupService.list().catchError((_) => <ChatGroup>[]),
      ]);
      final data = results[0] as List<Map<String, dynamic>>;
      final groups = results[1] as List<ChatGroup>;
      if (!mounted) return;
      setState(() {
        _chats = [
          ...data.map((item) => ChatListModel.fromBackend(item, _myId)),
          ...groups.map((g) => ChatListModel.fromGroup(g, _myId)),
        ]..sort((a, b) {
          final x = a.sortAt, y = b.sortAt;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
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

  Future<void> _openChat({
    required String id,
    required String name,
    required String photo,
    bool isGroup = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => IndividualChatScreen(
              chatId: id,
              chatName: name,
              chatAvatar: photo,
              isGroup: isGroup,
            ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _newGroup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewGroupScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _startNewChat() async {
    final contact = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewChatSheet(),
    );

    if (contact == null || !mounted) return;

    await _openChat(
      id: contact['id']?.toString() ?? '',
      name: _contactName(contact),
      photo: contact['profile_image_base64']?.toString() ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final chats = _visibleChats;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Mensajes',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: palette.title,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Nuevo grupo',
                    child: Material(
                      color: Brand.blue.withValues(alpha: 0.1),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _newGroup,
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            PhosphorIconsRegular.usersThree,
                            color: Brand.blue,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Nuevo chat',
                    child: Material(
                      color: Brand.blue,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _startNewChat,
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            PhosphorIconsRegular.pencilSimpleLine,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Historias de 24 h (la mía primero, luego mis contactos).
            StoriesRow(key: _storiesKey),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _SearchField(controller: _searchController),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Brand.blue,
                          strokeWidth: 2.5,
                        ),
                      )
                      : RefreshIndicator(
                        color: Brand.blue,
                        onRefresh:
                            () => Future.wait([
                              _load(),
                              _storiesKey.currentState?.reload() ??
                                  Future.value(),
                            ]),
                        child:
                            chats.isEmpty
                                ? _buildEmpty(palette)
                                : ListView(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    ResponsiveHelper.appBottomNavSpace(context),
                                  ),
                                  children: [
                                    Material(
                                      color: palette.card,
                                      clipBehavior: Clip.antiAlias,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: palette.cardBorder,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < chats.length;
                                            i++
                                          ) ...[
                                            if (i > 0)
                                              Divider(
                                                height: 1,
                                                indent: 76,
                                                color: palette.cardBorder,
                                              ),
                                            _ChatTile(
                                              chat: chats[i],
                                              onTap:
                                                  () => _openChat(
                                                    id: chats[i].chatId,
                                                    name: chats[i].userName,
                                                    photo: chats[i].userAvatar,
                                                    isGroup: chats[i].isGroup,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AuthPalette palette) {
    final searching = _query.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 140),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Brand.blue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasError
                  ? PhosphorIconsRegular.cloudSlash
                  : searching
                  ? PhosphorIconsRegular.magnifyingGlass
                  : PhosphorIconsRegular.chatsCircle,
              size: 32,
              color: Brand.blue,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _hasError
              ? 'No se pudieron cargar tus chats'
              : searching
              ? 'Sin resultados'
              : 'Aún no tienes conversaciones',
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
          _hasError
              ? 'Desliza hacia abajo para reintentar.'
              : searching
              ? 'Prueba con otro nombre o palabra.'
              : 'Escríbele a uno de tus contactos para empezar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 14,
            height: 1.4,
            color: palette.body,
          ),
        ),
        if (!_hasError && !searching) ...[
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 220,
              child: GradientButton(
                text: 'Nuevo chat',
                trailingIcon: PhosphorIconsRegular.pencilSimpleLine,
                onPressed: _startNewChat,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _contactName(Map<String, dynamic> user) {
  final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  final email = user['email']?.toString() ?? '';
  return email.isNotEmpty ? email : 'Usuario de Connect Do';
}

// =====================================================
// PIEZAS
// =====================================================
class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        border: Border.all(color: palette.cardBorder),
      ),
      child: TextField(
        controller: controller,
        cursorColor: Brand.blue,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 15,
          color: palette.title,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar conversaciones…',
          hintStyle: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 14.5,
            color: palette.muted,
          ),
          prefixIcon: Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 20,
            color: palette.muted,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatListModel chat;
  final VoidCallback onTap;

  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final unread = chat.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  name: chat.userName,
                  photo: chat.userAvatar,
                  radius: 24,
                ),
                if (chat.isGroup)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Brand.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.card, width: 2),
                      ),
                      child: const Icon(
                        PhosphorIconsFill.usersThree,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (RealtimeService.instance.online[chat.userId] == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: OnlineDot(border: palette.card, size: 13),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: palette.title,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chat.lastMessageTime,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w400,
                          color: unread ? Brand.blue : palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (chat.lastMessageIsMine)
                                TextSpan(
                                  text: 'Tú: ',
                                  style: TextStyle(color: palette.muted),
                                )
                              else if (chat.senderPrefix.isNotEmpty)
                                TextSpan(
                                  text: '${chat.senderPrefix}: ',
                                  style: TextStyle(color: palette.muted),
                                ),
                              TextSpan(text: chat.lastMessage),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 14,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                            color: unread ? palette.title : palette.body,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Brand.blue,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja para elegir un contacto y empezar a chatear.
class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  List<Map<String, dynamic>>? _contacts;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    ContactService.getAcceptedContacts()
        .then((contacts) {
          if (mounted) setState(() => _contacts = contacts);
        })
        .catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final contacts = _contacts;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        ResponsiveHelper.bottomSafe(context) + 12,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Brand.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.fieldBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nuevo chat',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Puedes escribirle a tus contactos.',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 13.5,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 14),
          if (contacts == null && !_hasError)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: Brand.blue,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_hasError || contacts!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    _hasError
                        ? 'No se pudieron cargar tus contactos.'
                        : 'Aún no tienes contactos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14.5,
                      color: palette.body,
                    ),
                  ),
                  if (!_hasError) ...[
                    const SizedBox(height: 12),
                    OutlineActionButton(
                      text: 'Buscar personas',
                      icon: PhosphorIconsRegular.userPlus,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            )
          else
            Flexible(
              child: Material(
                color: palette.card,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: palette.cardBorder),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder:
                      (_, __) => Divider(
                        height: 1,
                        indent: 72,
                        color: palette.cardBorder,
                      ),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final career = contact['career']?.toString() ?? '';

                    return ListTile(
                      onTap: () => Navigator.pop(context, contact),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: UserAvatar(
                        name: _contactName(contact),
                        photo:
                            contact['profile_image_base64']?.toString() ?? '',
                      ),
                      title: Text(
                        _contactName(contact),
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                        ),
                      ),
                      subtitle:
                          career.isEmpty
                              ? null
                              : Text(
                                career,
                                style: TextStyle(
                                  fontFamily: Brand.displayFont,
                                  color: palette.muted,
                                ),
                              ),
                      trailing: const Icon(
                        PhosphorIconsRegular.chatCircle,
                        color: Brand.blue,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================
// MODELO
// =====================================================
class ChatListModel {
  final String chatId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String lastMessage;
  final String lastMessageTime;
  final bool lastMessageIsMine;
  final int unreadCount;
  final bool isGroup;

  /// En grupos: quién escribió el último mensaje ("Ana").
  final String senderPrefix;

  /// Para ordenar (lo más reciente arriba).
  final DateTime? sortAt;

  ChatListModel({
    required this.chatId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.lastMessageIsMine = false,
    this.unreadCount = 0,
    this.isGroup = false,
    this.senderPrefix = '',
    this.sortAt,
  });

  factory ChatListModel.fromGroup(ChatGroup group, String currentUserId) {
    final last = group.lastMessage;
    final sender =
        last?['sender'] is Map
            ? Map<String, dynamic>.from(last!['sender'] as Map)
            : null;
    final isSystem = last?['kind'] == 'system';
    final mine = sender?['id']?.toString() == currentUserId;
    return ChatListModel(
      chatId: group.id,
      userId: group.id,
      userName: group.name,
      userAvatar: group.photoUrl,
      lastMessage:
          last == null
              ? 'Grupo nuevo'
              : last['is_deleted'] == true
              ? 'Mensaje eliminado'
              : messagePreviewText(
                last['content']?.toString() ?? '',
                last['attachment'],
              ),
      lastMessageTime: formatChatDate(last?['created_at']?.toString()),
      lastMessageIsMine: !isSystem && mine,
      senderPrefix:
          isSystem || mine
              ? ''
              : (sender?['name']?.toString() ?? '').split(' ').first,
      unreadCount: group.unreadCount,
      isGroup: true,
      sortAt: group.lastActivity,
    );
  }

  factory ChatListModel.fromBackend(
    Map<String, dynamic> json, [
    String currentUserId = '',
  ]) {
    final contact = json['contact'] as Map<String, dynamic>? ?? {};
    final lastMessage = json['last_message'] as Map<String, dynamic>?;
    final contactId = contact['id']?.toString() ?? '';
    final content =
        lastMessage?['is_deleted'] == true
            ? 'Mensaje eliminado'
            : messagePreviewText(
              lastMessage?['content']?.toString() ?? '',
              lastMessage?['attachment'],
            );

    return ChatListModel(
      chatId: contactId,
      userId: contactId,
      userName: _contactName(contact),
      userAvatar: contact['profile_image_base64']?.toString() ?? '',
      lastMessage: content.isNotEmpty ? content : 'Sin mensajes todavía',
      lastMessageTime: formatChatDate(lastMessage?['created_at']?.toString()),
      lastMessageIsMine:
          currentUserId.isNotEmpty &&
          lastMessage?['sender_id']?.toString() == currentUserId,
      unreadCount: int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
      sortAt:
          DateTime.tryParse(
            lastMessage?['created_at']?.toString() ?? '',
          )?.toLocal(),
    );
  }
}

/// Texto corto del último mensaje ("📷 Foto · hola", "📰 Publicación…").
String messagePreviewText(String rawContent, dynamic attachment) {
  final raw = rawContent.trim();
  // Publicación compartida: se muestra legible, sin la marca interna.
  final text =
      raw.startsWith('[pub:') ? '\u{1F4F0} Publicación compartida' : raw;
  final attachmentLabel = switch (attachment is Map
      ? attachment['type']
      : null) {
    'image' => '📷 Foto',
    'video' => '🎥 Video',
    'audio' => '🎤 Nota de voz',
    'sticker' => '💟 Sticker',
    'file' => '📄 Documento',
    'location' => '📍 Ubicación',
    _ => '',
  };
  return attachmentLabel.isEmpty
      ? text
      : text.isEmpty
      ? attachmentLabel
      : '$attachmentLabel · $text';
}

/// "14:05", "Ayer", "lun" o "12/11/26".
String formatChatDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '')?.toLocal();
  if (date == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;

  if (days == 0) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
  if (days == 1) return 'Ayer';
  if (days < 7) {
    const names = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    return names[date.weekday - 1];
  }
  return '${date.day}/${date.month}/${date.year % 100}';
}
