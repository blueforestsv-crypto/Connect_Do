import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Conversación con un contacto. Se actualiza cada pocos segundos.
class IndividualChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;

  const IndividualChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  static const Duration _pollInterval = Duration(seconds: 4);

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Del más nuevo (índice 0) al más viejo: la lista va invertida.
  List<ChatMessageModel> _messages = [];

  /// Mensajes enviados desde esta pantalla que aún no confirma el servidor.
  final List<ChatMessageModel> _pending = [];

  Timer? _pollTimer;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFetching = false;
  String _myId = '';

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _start();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _myId = (await UserService.getUser())['id']?.toString() ?? '';
    await _fetch(initial: true);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  Future<void> _fetch({bool initial = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final data = await ChatService.getMessages(contactId: widget.chatId);
      final messages =
          data
              .map((m) => ChatMessageModel.fromBackend(m, currentUserId: _myId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Solo marca como leído si hay mensajes nuevos del otro sin leer.
      if (messages.any((m) => !m.isMe && !m.isRead)) {
        ChatService.markAsRead(contactId: widget.chatId).ignore();
      }

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      // En las actualizaciones automáticas no se molesta con errores.
      if (initial) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _send([ChatMessageModel? retry]) async {
    final text = retry?.text ?? _input.text.trim();
    if (text.isEmpty) return;

    final pending =
        retry ??
        ChatMessageModel(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          createdAt: DateTime.now(),
          isMe: true,
        );

    setState(() {
      pending.status = MessageStatus.sending;
      if (retry == null) _pending.insert(0, pending);
    });

    if (retry == null) {
      _input.clear();
      HapticFeedback.lightImpact();
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }

    try {
      final created = await ChatService.sendMessage(
        contactId: widget.chatId,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        _messages.insert(
          0,
          ChatMessageModel.fromBackend(created, currentUserId: _myId),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => pending.status = MessageStatus.failed);
    }
  }

  void _showFailedOptions(ChatMessageModel message) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);

        return Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Brand.radiusLg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.arrowClockwise,
                  color: Brand.blue,
                ),
                title: Text(
                  'Reintentar',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontWeight: FontWeight.w600,
                    color: palette.title,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _send(message);
                },
              ),
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.trash,
                  color: Brand.danger,
                ),
                title: const Text(
                  'Descartar',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontWeight: FontWeight.w600,
                    color: Brand.danger,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _pending.remove(message));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final all = [..._pending, ..._messages];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        shape: Border(bottom: BorderSide(color: palette.cardBorder)),
        title: Row(
          children: [
            AuthBackButton(onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 12),
            UserAvatar(
              name: widget.chatName,
              photo: widget.chatAvatar,
              radius: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.chatName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: palette.title,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Brand.blue,
                        strokeWidth: 2.5,
                      ),
                    )
                    : all.isEmpty
                    ? _buildEmpty(palette)
                    : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: all.length,
                      itemBuilder: (context, index) {
                        final message = all[index];
                        final older =
                            index + 1 < all.length ? all[index + 1] : null;
                        final newer = index > 0 ? all[index - 1] : null;

                        final showDay =
                            older == null ||
                            !_sameDay(older.createdAt, message.createdAt);
                        // Burbujas seguidas del mismo autor van más juntas.
                        final groupedWithNewer =
                            newer != null &&
                            newer.isMe == message.isMe &&
                            _sameDay(newer.createdAt, message.createdAt);

                        return Column(
                          children: [
                            if (showDay) _DayChip(date: message.createdAt),
                            _Bubble(
                              message: message,
                              tight: groupedWithNewer,
                              onFailedTap:
                                  message.status == MessageStatus.failed
                                      ? () => _showFailedOptions(message)
                                      : null,
                            ),
                          ],
                        );
                      },
                    ),
          ),
          _buildInput(palette),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildEmpty(AuthPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              name: widget.chatName,
              photo: widget.chatAvatar,
              radius: 36,
            ),
            const SizedBox(height: 14),
            Text(
              _hasError
                  ? 'No se pudo cargar la conversación'
                  : 'Saluda a ${widget.chatName.split(' ').first}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasError
                  ? 'Revisa tu conexión; seguiremos intentando.'
                  : 'Escribe el primer mensaje de esta conversación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 14,
                color: palette.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(AuthPalette palette) {
    final canSend = _input.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        ResponsiveHelper.bottomSafe(context) + 8,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: palette.fieldBorder),
              ),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                cursorColor: Brand.blue,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 15,
                  color: palette.title,
                ),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  hintStyle: TextStyle(
                    fontFamily: Brand.displayFont,
                    color: palette.muted,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canSend ? Brand.gradient : null,
              color: canSend ? null : palette.fieldBorder,
            ),
            child: IconButton(
              tooltip: 'Enviar',
              onPressed: canSend ? _send : null,
              icon: Icon(
                PhosphorIconsFill.paperPlaneRight,
                size: 20,
                color: canSend ? Colors.white : palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// PIEZAS
// =====================================================
class _DayChip extends StatelessWidget {
  final DateTime date;

  const _DayChip({required this.date});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;

    if (days == 0) return 'Hoy';
    if (days == 1) return 'Ayer';
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
    final label = '${date.day} ${months[date.month - 1]}';
    return date.year == now.year ? label : '$label ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Text(
          _label,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool tight;
  final VoidCallback? onFailedTap;

  const _Bubble({required this.message, required this.tight, this.onFailedTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final isMe = message.isMe;
    final failed = message.status == MessageStatus.failed;

    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.minute.toString().padLeft(2, '0')}';

    final metaColor =
        isMe ? Colors.white.withValues(alpha: 0.75) : palette.muted;

    Widget statusIcon() {
      if (!isMe) return const SizedBox.shrink();
      final (IconData icon, Color color) = switch (message.status) {
        MessageStatus.sending => (PhosphorIconsRegular.clock, metaColor),
        MessageStatus.failed => (
          PhosphorIconsFill.warningCircle,
          const Color(0xFFFECACA),
        ),
        MessageStatus.sent when message.isRead => (
          PhosphorIconsRegular.checks,
          Colors.white,
        ),
        MessageStatus.sent => (PhosphorIconsRegular.check, metaColor),
      };
      return Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(icon, size: 14, color: color),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: tight ? 2 : 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: onFailedTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
              decoration: BoxDecoration(
                color:
                    isMe ? (failed ? Brand.danger : Brand.blue) : palette.card,
                border: isMe ? null : Border.all(color: palette.cardBorder),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe || tight ? 18 : 6),
                  bottomRight: Radius.circular(!isMe || tight ? 18 : 6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 15,
                        height: 1.35,
                        color: isMe ? Colors.white : palette.title,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        failed ? 'No enviado · toca para reintentar' : time,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 11,
                          color: metaColor,
                        ),
                      ),
                      statusIcon(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// MODELO
// =====================================================
enum MessageStatus { sending, sent, failed }

class ChatMessageModel {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool isMe;

  /// Para mis mensajes: si el otro ya lo leyó.
  final bool isRead;
  MessageStatus status;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.isMe,
    this.isRead = false,
    this.status = MessageStatus.sent,
  });

  factory ChatMessageModel.fromBackend(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      isMe: json['sender_id']?.toString() == currentUserId,
      isRead: json['is_read'] == true,
    );
  }
}
