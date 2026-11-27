import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:record/record.dart';

import 'package:connect_do/screens/main_content/chats/chat_media_screen.dart';
import 'package:connect_do/services/live_location_service.dart';
import 'package:connect_do/widgets/chat/chat_attachments.dart';
import 'package:connect_do/screens/main_content/chats/group_info_screen.dart';
import 'package:connect_do/services/group_service.dart';
import 'package:connect_do/services/realtime_service.dart';
import 'package:connect_do/widgets/social/share_to_chat.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';
import 'package:connect_do/widgets/safety/report_sheet.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/media/media_viewer_screen.dart';
import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/services/media_upload_service.dart';
import 'package:connect_do/services/sticker_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/chat/sticker_picker.dart';
import 'package:connect_do/widgets/chat/voice_note_player.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';
import 'package:connect_do/widgets/media/media_gallery.dart';

/// Conversación con un contacto o un grupo. Los mensajes llegan al instante
/// por la conexión en tiempo real; si se cae, se consulta cada pocos segundos.
class IndividualChatScreen extends StatefulWidget {
  /// Id del contacto (o grupo) cuya conversación está abierta ahora.
  static String? get openChatId => _IndividualChatScreenState.openChatId;

  /// Id del contacto o, si [isGroup], del grupo.
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final bool isGroup;

  const IndividualChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.isGroup = false,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with WidgetsBindingObserver {
  /// Conversación que está en pantalla (para no avisar de sus mensajes).
  static String? openChatId;

  // Cada 5 s se piden solo los mensajes nuevos (casi 0 datos si no hay).
  // Cada 6 vueltas (30 s) se refresca la lista completa, sin fotos de
  // perfil, para actualizar los "visto" (✓✓).
  static const Duration _pollInterval = Duration(seconds: 5);
  static const int _fullRefreshEvery = 6;
  int _pollCount = 0;

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// Del más nuevo (índice 0) al más viejo: la lista va invertida.
  List<ChatMessageModel> _messages = [];

  /// Mensajes enviados desde esta pantalla que aún no confirma el servidor.
  final List<ChatMessageModel> _pending = [];

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  /// Grabación de nota de voz en curso.
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  static const int _maxVoiceSeconds = 180;
  static const int _maxVideoSeconds = 60;

  Timer? _pollTimer;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFetching = false;
  String _myId = '';

  // ---- Tiempo real ----
  StreamSubscription<Map<String, dynamic>>? _live;
  int _ticks = 0;

  /// Quién está escribiendo ahora (id -> nombre) y cuándo se borra.
  final Map<String, String> _typing = {};
  final Map<String, Timer> _typingTimers = {};
  DateTime? _typingSentAt;
  Timer? _stopTyping;

  bool _online = false;
  DateTime? _lastSeen;

  /// Mensaje que se está respondiendo.
  ChatMessageModel? _replyTo;

  /// Datos del grupo (miembros, nombre actual, si soy admin).
  ChatGroup? _group;
  late String _title = widget.chatName;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      setState(() {});
      _onTypingChanged();
    });
    WidgetsBinding.instance.addObserver(this);
    openChatId = widget.chatId;
    _start();
  }

  /// En segundo plano no se consulta nada; al volver, se actualiza.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetch(full: true);
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _tick());
  }

  /// Con la conexión en tiempo real abierta casi no se consulta (solo un
  /// repaso cada minuto); sin ella, se consulta cada 5 s como antes.
  void _tick() {
    _ticks++;
    if (!RealtimeService.instance.connected.value) {
      _fetch();
    } else if (_ticks % 12 == 0) {
      _fetch(full: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (openChatId == widget.chatId) openChatId = null;
    _live?.cancel();
    _stopTyping?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    if (_typingSentAt != null) _sendTyping(false);
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _myId = (await UserService.getUser())['id']?.toString() ?? '';
    RealtimeService.instance.ensureConnected();
    _live = RealtimeService.instance.events.listen(_onEvent);
    if (widget.isGroup) {
      _loadGroup();
    } else {
      final known = RealtimeService.instance.online[widget.chatId];
      if (known != null) _online = known;
      _lastSeen = RealtimeService.instance.lastSeen[widget.chatId];
      ChatService.presence(widget.chatId)
          .then((value) {
            if (!mounted) return;
            setState(() {
              _online = value.$1;
              _lastSeen = value.$2 ?? _lastSeen;
            });
          })
          .catchError((_) {});
    }
    await _fetch(initial: true);
    _startPolling();
  }

  Future<void> _loadGroup() async {
    try {
      final group = await GroupService.get(widget.chatId);
      if (mounted) {
        setState(() {
          _group = group;
          _title = group.name;
        });
      }
    } catch (_) {
      // Ya no pertenezco al grupo.
      if (mounted && _group != null) Navigator.maybePop(context);
    }
  }

  // ===============================
  // TIEMPO REAL
  // ===============================

  /// ¿El evento es de esta conversación?
  bool _isMine(Map<String, dynamic> e) =>
      widget.isGroup
          ? e['group_id']?.toString() == widget.chatId
          : e['group_id'] == null;

  void _onEvent(Map<String, dynamic> e) {
    if (!mounted) return;
    switch (e['type']) {
      case 'message' when !widget.isGroup:
        final data = Map<String, dynamic>.from(e['message'] as Map);
        final from = data['sender_id']?.toString();
        final to = data['receiver_id']?.toString();
        if (from != widget.chatId && to != widget.chatId) return;
        _receive(data, fromOther: from == widget.chatId);
      case 'group_message' when widget.isGroup:
        final data = Map<String, dynamic>.from(e['message'] as Map);
        if (data['group_id']?.toString() != widget.chatId) return;
        final from = (data['sender'] as Map?)?['id']?.toString();
        _receive(data, fromOther: from != _myId);
      case 'read' when !widget.isGroup:
        if (e['by']?.toString() != widget.chatId) return;
        setState(() {
          for (final m in _messages) {
            if (m.isMe) m.isRead = true;
          }
        });
      case 'typing':
        if (!_isMine(e)) return;
        final from = e['from']?.toString() ?? '';
        if (!widget.isGroup && from != widget.chatId) return;
        _setTyping(from, e['is_typing'] == true);
      case 'reaction':
        if (!_isMine(e)) return;
        final m = _find(e['message_id']?.toString());
        if (m == null) return;
        setState(() => m.reactions = ChatService.reactionsFrom(e['reactions']));
      case 'location':
        if (!_isMine(e)) return;
        final m = _find(e['message_id']?.toString());
        final a = e['attachment'];
        if (m == null || a is! Map) return;
        setState(() => m.applyLocation(Map<String, dynamic>.from(a)));
      case 'deleted':
        if (!_isMine(e)) return;
        final m = _find(e['message_id']?.toString());
        if (m == null) return;
        setState(() => m.markDeleted());
      case 'presence' when !widget.isGroup:
        if (e['user_id']?.toString() != widget.chatId) return;
        setState(() {
          _online = e['online'] == true;
          final seen = DateTime.tryParse(e['last_seen_at']?.toString() ?? '');
          if (seen != null) _lastSeen = seen.toLocal();
        });
      case 'group_updated' when widget.isGroup:
        if (e['group_id']?.toString() == widget.chatId) {
          _loadGroup();
          _fetch();
        }
    }
  }

  ChatMessageModel? _find(String? id) {
    for (final m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _receive(Map<String, dynamic> data, {required bool fromOther}) {
    final message = ChatMessageModel.fromBackend(data, currentUserId: _myId);
    if (_find(message.id) != null) return;
    setState(() {
      _messages.insert(0, message);
      if (fromOther) _setTyping(message.senderId ?? '', false, rebuild: false);
    });
    if (fromOther) {
      HapticFeedback.selectionClick();
      _markRead();
    }
  }

  void _markRead() {
    if (widget.isGroup) {
      GroupService.markRead(widget.chatId).ignore();
    } else {
      ChatService.markAsRead(contactId: widget.chatId).ignore();
    }
  }

  void _setTyping(String userId, bool isTyping, {bool rebuild = true}) {
    _typingTimers.remove(userId)?.cancel();
    void apply() {
      if (isTyping) {
        _typing[userId] = _nameOf(userId);
      } else {
        _typing.remove(userId);
      }
    }

    rebuild ? setState(apply) : apply();
    if (isTyping) {
      // Si no vuelve a avisar en 6 s, se asume que dejó de escribir.
      _typingTimers[userId] = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _typing.remove(userId));
      });
    }
  }

  String _nameOf(String userId) {
    if (!widget.isGroup) return widget.chatName;
    for (final m in _group?.members ?? const <GroupPerson>[]) {
      if (m.id == userId) return m.name.split(' ').first;
    }
    return 'Alguien';
  }

  /// Avisa "escribiendo…" como mucho cada 3 s y "dejó de escribir" tras
  /// 4 s sin teclear.
  void _onTypingChanged() {
    if (_input.text.trim().isEmpty) {
      if (_typingSentAt != null) _sendTyping(false);
      return;
    }
    final now = DateTime.now();
    if (_typingSentAt == null ||
        now.difference(_typingSentAt!) > const Duration(seconds: 3)) {
      _sendTyping(true);
    }
    _stopTyping?.cancel();
    _stopTyping = Timer(const Duration(seconds: 4), () => _sendTyping(false));
  }

  void _sendTyping(bool isTyping) {
    _typingSentAt = isTyping ? DateTime.now() : null;
    if (!isTyping) _stopTyping?.cancel();
    RealtimeService.instance.sendTyping(
      to: widget.isGroup ? null : widget.chatId,
      groupId: widget.isGroup ? widget.chatId : null,
      isTyping: isTyping,
    );
  }

  /// Texto bajo el nombre: escribiendo, en línea, últ. vez o miembros.
  String? get _subtitle {
    if (_typing.isNotEmpty) {
      if (!widget.isGroup) return 'escribiendo…';
      final names = _typing.values.toList();
      return names.length == 1
          ? '${names.first} está escribiendo…'
          : 'Varios están escribiendo…';
    }
    if (widget.isGroup) {
      final members = _group?.members ?? const <GroupPerson>[];
      if (members.isEmpty) return null;
      final names = [
        for (final m in members)
          if (m.id != _myId) m.name.split(' ').first,
      ];
      return names.isEmpty ? 'Solo tú' : 'Tú, ${names.join(', ')}';
    }
    if (_online) return 'en línea';
    if (_lastSeen != null) return 'últ. vez ${lastSeenLabel(_lastSeen!)}';
    return null;
  }

  Future<void> _fetch({bool initial = false, bool full = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    _pollCount++;

    // El más nuevo que ya mandó el servidor (no los pendientes locales).
    final newest = _messages.isEmpty ? null : _messages.first.createdAt;
    final complete =
        initial ||
        full ||
        newest == null ||
        _pollCount % _fullRefreshEvery == 0;

    try {
      final data =
          widget.isGroup
              ? await GroupService.messages(
                widget.chatId,
                after: complete ? null : newest,
              )
              : await ChatService.getMessages(
                contactId: widget.chatId,
                after: complete ? null : newest,
              );
      final incoming =
          data
              .map((m) => ChatMessageModel.fromBackend(m, currentUserId: _myId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Solo marca como leído si hay mensajes nuevos del otro sin leer.
      if (widget.isGroup) {
        final known = _messages.map((m) => m.id).toSet();
        if (initial || incoming.any((m) => !m.isMe && !known.contains(m.id))) {
          _markRead();
        }
      } else if (incoming.any((m) => !m.isMe && !m.isRead)) {
        _markRead();
      }

      if (!mounted) return;
      if (!complete && incoming.isEmpty) {
        if (initial) setState(() => _isLoading = false);
        return;
      }

      setState(() {
        if (complete) {
          // Conserva la vista local de fotos recién enviadas.
          final local = {
            for (final m in _messages)
              if (m.localBytes != null) m.id: m.localBytes,
          };
          _messages = [for (final m in incoming) m..localBytes = local[m.id]];
        } else {
          final known = _messages.map((m) => m.id).toSet();
          _messages = [
            ...incoming.where((m) => !known.contains(m.id)),
            ..._messages,
          ];
        }
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

  /// Texto escrito en el campo.
  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _sendTyping(false);
    _enqueue(
      ChatMessageModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        createdAt: DateTime.now(),
        isMe: true,
      ),
    );
  }

  /// Agrega el mensaje a la lista y lo envía (subiendo antes el adjunto).
  void _enqueue(ChatMessageModel pending) {
    // La respuesta citada viaja con el mensaje (texto, foto, audio…).
    if (_replyTo != null) {
      pending.replyTo = ReplyQuote.fromMessage(
        _replyTo!,
        name: _replyTo!.isMe ? 'Tú' : _senderName(_replyTo!),
      );
    }
    setState(() {
      _pending.insert(0, pending);
      _replyTo = null;
    });
    HapticFeedback.lightImpact();
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _send(pending);
  }

  Future<void> _send(ChatMessageModel pending) async {
    setState(() {
      pending.status = MessageStatus.sending;
      pending.progress = null;
    });

    try {
      // 1) El archivo a Cloudinary (si no se subió en un intento anterior).
      if (pending.localBytes != null && pending.attachmentUrl == null) {
        final uploaded = await MediaUploadService.upload(
          bytes: pending.localBytes!,
          fileName: pending.localName ?? 'archivo',
          kind: MediaKind.values.byName(pending.attachmentType!),
          purpose: MediaPurpose.chat,
          onProgress: (value) {
            if (mounted) setState(() => pending.progress = value);
          },
        );
        pending
          ..attachmentUrl = uploaded.url
          ..width = uploaded.width ?? pending.width
          ..height = uploaded.height ?? pending.height
          ..duration = uploaded.duration ?? pending.duration;
      }

      // 2) El mensaje.
      final attachment =
          pending.attachmentType == 'location'
              ? {
                'type': 'location',
                'lat': pending.lat,
                'lng': pending.lng,
                if (pending.liveMinutes != null)
                  'live_minutes': pending.liveMinutes,
              }
              : pending.attachmentUrl == null
              ? null
              : {
                'type': pending.attachmentType,
                'url': pending.attachmentUrl,
                if (pending.width != null) 'width': pending.width,
                if (pending.height != null) 'height': pending.height,
                if (pending.duration != null) 'duration': pending.duration,
                if (pending.fileName != null) 'name': pending.fileName,
                if (pending.sizeBytes != null) 'size_bytes': pending.sizeBytes,
              };
      final created =
          widget.isGroup
              ? await GroupService.send(
                widget.chatId,
                content: pending.text,
                attachment: attachment,
                replyToId: pending.replyTo?.id,
              )
              : await ChatService.sendMessage(
                contactId: widget.chatId,
                content: pending.text,
                attachment: attachment,
                replyToId: pending.replyTo?.id,
              );
      if (!mounted) return;
      final sent = ChatMessageModel.fromBackend(created, currentUserId: _myId)
        // Se conserva la vista local para que la foto no "parpadee".
        ..localBytes = pending.localBytes;
      setState(() {
        _pending.remove(pending);
        // Puede que ya haya llegado por la conexión en tiempo real.
        final echoed = _find(sent.id);
        if (echoed != null) {
          echoed.localBytes ??= pending.localBytes;
        } else {
          _messages.insert(0, sent);
        }
      });
      // Ubicación en tiempo real: desde ahora se envía mi posición.
      final until = sent.liveUntil;
      if (sent.attachmentType == 'location' &&
          until != null &&
          until.isAfter(DateTime.now())) {
        LiveLocationService.instance.start(
          sent.id,
          until,
          isGroup: widget.isGroup,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => pending.status = MessageStatus.failed);
      if (error is MediaUploadException) {
        showAuthMessage(context, error.message);
      }
    }
  }

  // ===============================
  // ADJUNTOS
  // ===============================
  void _openAttachMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);

        Widget option(
          IconData icon,
          Color color,
          String label,
          VoidCallback onTap,
        ) {
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(Brand.radiusMd),
              onTap: () {
                Navigator.pop(sheetContext);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.label,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    option(
                      PhosphorIconsFill.image,
                      Brand.blue,
                      'Galería',
                      () => _pickImage(ImageSource.gallery),
                    ),
                    if (!kIsWeb)
                      option(
                        PhosphorIconsFill.camera,
                        Brand.green,
                        'Cámara',
                        () => _pickImage(ImageSource.camera),
                      ),
                    option(
                      PhosphorIconsFill.videoCamera,
                      const Color(0xFF8B5CF6),
                      'Video',
                      _pickVideo,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    option(
                      PhosphorIconsFill.fileText,
                      const Color(0xFFEA580C),
                      'Documento',
                      _pickDocument,
                    ),
                    if (!kIsWeb)
                      option(
                        PhosphorIconsFill.mapPin,
                        const Color(0xFFDC2626),
                        'Ubicación',
                        _chooseLocation,
                      ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// PDF, Word, Excel, PowerPoint, TXT, ZIP… (hasta 10 MB).
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: documentExtensions,
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) {
          showAuthMessage(context, 'El documento no puede pesar más de 10 MB.');
        }
        return;
      }
      final caption = _input.text.trim();
      _input.clear();
      _enqueue(
        ChatMessageModel(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: caption,
          createdAt: DateTime.now(),
          isMe: true,
          attachmentType: 'file',
          localBytes: bytes,
          localName: file.name,
          fileName: file.name,
          sizeBytes: bytes.length,
        ),
      );
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo abrir el documento.');
    }
  }

  /// Ubicación actual o en tiempo real (15 min, 1 h u 8 h).
  void _chooseLocation() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        Widget tile(
          IconData icon,
          String title,
          String? subtitle,
          int? minutes,
        ) => ListTile(
          leading: Icon(icon, color: Brand.blue),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontWeight: FontWeight.w600,
              color: palette.title,
            ),
          ),
          subtitle: subtitle == null ? null : Text(subtitle),
          onTap: () {
            Navigator.pop(sheetContext);
            _sendLocation(liveMinutes: minutes);
          },
        );
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile(
                  PhosphorIconsRegular.mapPin,
                  'Enviar mi ubicación actual',
                  null,
                  null,
                ),
                const Divider(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: Text(
                    'En tiempo real (se actualiza mientras tengas la app abierta)',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
                ),
                tile(PhosphorIconsRegular.broadcast, '15 minutos', null, 15),
                tile(PhosphorIconsRegular.broadcast, '1 hora', null, 60),
                tile(PhosphorIconsRegular.broadcast, '8 horas', null, 480),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendLocation({int? liveMinutes}) async {
    try {
      final position = await LiveLocationService.current();
      if (!mounted) return;
      _enqueue(
        ChatMessageModel(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: '',
          createdAt: DateTime.now(),
          isMe: true,
          attachmentType: 'location',
          lat: position.latitude,
          lng: position.longitude,
          liveMinutes: liveMinutes,
          liveUntil:
              liveMinutes == null
                  ? null
                  : DateTime.now().add(Duration(minutes: liveMinutes)),
        ),
      );
    } on LocationException catch (error) {
      if (mounted) showAuthMessage(context, error.message);
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo obtener tu ubicación.');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _enqueueAttachment('image', bytes, picked.name);
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo abrir la foto.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: _maxVideoSeconds),
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _enqueueAttachment('video', bytes, picked.name);
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo abrir el video.');
    }
  }

  void _enqueueAttachment(
    String type,
    Uint8List bytes,
    String name, {
    double? duration,
  }) {
    // Lo escrito en el campo va como texto del mismo mensaje.
    final caption = _input.text.trim();
    _input.clear();
    _enqueue(
      ChatMessageModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        text: caption,
        createdAt: DateTime.now(),
        isMe: true,
        attachmentType: type,
        localBytes: bytes,
        localName: name,
        duration: duration,
      ),
    );
  }

  // ===============================
  // NOTAS DE VOZ
  // ===============================
  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          showAuthMessage(
            context,
            'Permite el micrófono para enviar notas de voz.',
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/nota_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: path,
      );
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds >= _maxVoiceSeconds) _stopRecording(send: true);
      });
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo grabar.');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    setState(() => _isRecording = false);

    try {
      if (!send) {
        await _recorder.cancel();
        return;
      }
      final path = await _recorder.stop();
      if (path == null) return;
      if (seconds < 1) {
        if (mounted) {
          showAuthMessage(
            context,
            'Mantén la grabación al menos un segundo.',
            type: AuthMessageType.info,
          );
        }
        return;
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      file.delete().ignore();
      _enqueueAttachment(
        'audio',
        bytes,
        'nota_de_voz.m4a',
        duration: seconds.toDouble(),
      );
    } catch (_) {
      if (mounted) {
        showAuthMessage(context, 'No se pudo enviar la nota de voz.');
      }
    }
  }

  // ===============================
  // STICKERS
  // ===============================
  Future<void> _openStickers() async {
    FocusScope.of(context).unfocus();
    final sticker = await showStickerPicker(context);
    if (sticker == null || !mounted) return;
    _enqueue(
      ChatMessageModel(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        text: '',
        createdAt: DateTime.now(),
        isMe: true,
        attachmentType: 'sticker',
        attachmentUrl: sticker.url,
        width: sticker.width,
        height: sticker.height,
      ),
    );
  }

  void _stickerOptions(ChatMessageModel message) {
    final url = message.attachmentUrl;
    if (url == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StickerImage(url: url, size: 110),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.heart,
                    color: Brand.blue,
                  ),
                  title: Text(
                    'Agregar a mis stickers',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await StickerService.save(
                        url: url,
                        width: message.width,
                        height: message.height,
                      );
                      if (mounted) {
                        showAuthMessage(
                          context,
                          'Sticker guardado',
                          type: AuthMessageType.success,
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        showAuthMessage(
                          context,
                          error.toString().replaceFirst('Exception: ', ''),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMedia(ChatMessageModel message) {
    final item = message.asMediaItem;
    if (item == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => MediaViewerScreen(items: [item]),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  String _senderName(ChatMessageModel message) {
    if (message.isMe) return 'Tú';
    if (!widget.isGroup) return widget.chatName.split(' ').first;
    return (message.senderName ?? _nameOf(message.senderId ?? ''))
        .split(' ')
        .first;
  }

  static const _quickReactions = ['❤️', '😂', '😮', '😢', '👍', '🙏'];

  /// Mantener presionado un mensaje: reaccionar, responder, copiar,
  /// eliminar o reportar.
  void _messageActions(ChatMessageModel message) {
    if (message.id.startsWith('local') || message.isSystem) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final mine = message.reactions[_myId];

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        Widget tile(
          IconData icon,
          String title,
          VoidCallback onTap, {
          Color? color,
        }) => ListTile(
          leading: Icon(icon, color: color ?? Brand.blue),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontWeight: FontWeight.w600,
              color: color ?? palette.title,
            ),
          ),
          onTap: () {
            Navigator.pop(sheetContext);
            onTap();
          },
        );

        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!message.isDeleted)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final emoji in _quickReactions)
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _react(message, mine == emoji ? null : emoji);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  mine == emoji
                                      ? Brand.blue.withValues(alpha: 0.15)
                                      : null,
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (!message.isDeleted) const SizedBox(height: 6),
                if (!message.isDeleted)
                  tile(
                    PhosphorIconsRegular.arrowBendUpLeft,
                    'Responder',
                    () => setState(() => _replyTo = message),
                  ),
                if (!message.isDeleted &&
                    message.text.isNotEmpty &&
                    !sharedPostPattern.hasMatch(message.text))
                  tile(PhosphorIconsRegular.copy, 'Copiar', () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    showAuthMessage(context, 'Copiado');
                  }),
                if (!message.isDeleted &&
                    message.attachmentType == 'sticker' &&
                    !message.isMe)
                  tile(
                    PhosphorIconsRegular.heart,
                    'Agregar a mis stickers',
                    () => _stickerOptions(message),
                  ),
                if (message.isMe && !message.isDeleted)
                  tile(
                    PhosphorIconsRegular.trash,
                    'Eliminar para todos',
                    () => _deleteForEveryone(message),
                    color: Brand.danger,
                  ),
                if (!message.isMe)
                  tile(
                    PhosphorIconsRegular.flag,
                    'Reportar',
                    () => showReportSheet(
                      context,
                      targetType: widget.isGroup ? 'user' : 'message',
                      targetId:
                          widget.isGroup
                              ? (message.senderId ?? '')
                              : message.id,
                    ),
                    color: Brand.danger,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _react(ChatMessageModel message, String? emoji) async {
    final before = Map<String, String>.from(message.reactions);
    setState(() {
      if (emoji == null) {
        message.reactions.remove(_myId);
      } else {
        message.reactions[_myId] = emoji;
      }
    });
    try {
      final reactions =
          widget.isGroup
              ? await GroupService.react(message.id, emoji)
              : await ChatService.react(message.id, emoji);
      if (mounted) setState(() => message.reactions = reactions);
    } catch (_) {
      if (!mounted) return;
      setState(() => message.reactions = before);
      showAuthMessage(context, 'No se pudo reaccionar.');
    }
  }

  Future<void> _deleteForEveryone(ChatMessageModel message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('¿Eliminar para todos?'),
            content: const Text(
              'El mensaje desaparecerá de la conversación para todos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Brand.danger),
                ),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    try {
      if (widget.isGroup) {
        await GroupService.deleteForEveryone(message.id);
      } else {
        await ChatService.deleteForEveryone(message.id);
      }
      if (mounted) setState(message.markDeleted);
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo eliminar.');
    }
  }

  void _openShared() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatMediaScreen(
              chatId: widget.chatId,
              isGroup: widget.isGroup,
              title: _title,
              myId: _myId,
            ),
      ),
    );
  }

  void _openGroupInfo() {
    if (!widget.isGroup) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(groupId: widget.chatId),
      ),
    ).then((_) => _loadGroup());
  }

  void _showFailedOptions(ChatMessageModel message) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);

        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
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
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openGroupInfo,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(
                          name: _title,
                          photo: _group?.photoUrl ?? widget.chatAvatar,
                          radius: 19,
                        ),
                        if (_online && !widget.isGroup)
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: OnlineDot(border: palette.card),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: palette.title,
                            ),
                          ),
                          if (_subtitle != null)
                            Text(
                              _subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 12.5,
                                fontWeight:
                                    _typing.isNotEmpty || _online
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                color:
                                    _typing.isNotEmpty || _online
                                        ? Brand.blue
                                        : palette.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: Icon(
              PhosphorIconsRegular.dotsThreeVertical,
              color: palette.title,
            ),
            onSelected: (value) async {
              if (value == 'media') {
                _openShared();
              } else if (value == 'info') {
                _openGroupInfo();
              } else if (value == 'report') {
                showReportSheet(
                  context,
                  targetType: 'user',
                  targetId: widget.chatId,
                );
              } else if (value == 'block') {
                final blocked = await confirmBlock(
                  context,
                  userId: widget.chatId,
                  name: widget.chatName,
                );
                if (blocked && context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder:
                (_) =>
                    widget.isGroup
                        ? const [
                          PopupMenuItem(
                            value: 'media',
                            child: Text('Archivos, enlaces y documentos'),
                          ),
                          PopupMenuItem(
                            value: 'info',
                            child: Text('Información del grupo'),
                          ),
                        ]
                        : const [
                          PopupMenuItem(
                            value: 'media',
                            child: Text('Archivos, enlaces y documentos'),
                          ),
                          PopupMenuItem(
                            value: 'report',
                            child: Text('Reportar'),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text(
                              'Bloquear',
                              style: TextStyle(color: Brand.danger),
                            ),
                          ),
                        ],
          ),
        ],
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
                            !newer.isSystem &&
                            newer.senderKey == message.senderKey &&
                            _sameDay(newer.createdAt, message.createdAt);
                        // En grupos, el nombre va en la primera de cada tanda.
                        final showSender =
                            widget.isGroup &&
                            !message.isMe &&
                            (showDay ||
                                older.isSystem ||
                                older.senderKey != message.senderKey);

                        if (message.isSystem) {
                          return Column(
                            children: [
                              if (showDay) _DayChip(date: message.createdAt),
                              _SystemNote(text: message.text),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            if (showDay) _DayChip(date: message.createdAt),
                            _Bubble(
                              message: message,
                              tight: groupedWithNewer,
                              myId: _myId,
                              senderName:
                                  showSender ? _senderName(message) : null,
                              otherName: widget.chatName.split(' ').first,
                              onMediaTap: () => _openMedia(message),
                              onStickerLongPress:
                                  () => _messageActions(message),
                              onStickerTap: () => _stickerOptions(message),
                              isGroup: widget.isGroup,
                              onReport: () => _messageActions(message),
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
    final reply = _replyTo;
    if (reply == null) return _buildComposer(palette);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: _QuoteBox(
                  quote: ReplyQuote.fromMessage(
                    reply,
                    name: reply.isMe ? 'Tú' : _senderName(reply),
                  ),
                  onDark: false,
                ),
              ),
              IconButton(
                tooltip: 'Cancelar respuesta',
                onPressed: () => setState(() => _replyTo = null),
                icon: Icon(PhosphorIconsRegular.x, color: palette.muted),
              ),
            ],
          ),
        ),
        _buildComposer(palette),
      ],
    );
  }

  Widget _buildComposer(AuthPalette palette) {
    final canSend = _input.text.trim().isNotEmpty;
    // Sin texto, el botón grande graba una nota de voz (no en la web).
    final showMic = !canSend && !kIsWeb;

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        12,
        ResponsiveHelper.bottomSafe(context) + 8,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      child:
          _isRecording
              ? _buildRecordingBar(palette)
              : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Adjuntar',
                    onPressed: _openAttachMenu,
                    icon: Icon(
                      PhosphorIconsRegular.plusCircle,
                      size: 28,
                      color: Brand.blue,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.only(left: 16, right: 2),
                      decoration: BoxDecoration(
                        color: palette.fieldFill,
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: palette.fieldBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
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
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Stickers',
                            visualDensity: VisualDensity.compact,
                            onPressed: _openStickers,
                            icon: Icon(
                              PhosphorIconsRegular.sticker,
                              color: palette.muted,
                              size: 22,
                            ),
                          ),
                        ],
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
                      gradient: canSend || showMic ? Brand.gradient : null,
                      color: canSend || showMic ? null : palette.fieldBorder,
                    ),
                    child: IconButton(
                      tooltip: showMic ? 'Grabar nota de voz' : 'Enviar',
                      onPressed:
                          canSend
                              ? _sendText
                              : showMic
                              ? _startRecording
                              : null,
                      icon: Icon(
                        showMic
                            ? PhosphorIconsFill.microphone
                            : PhosphorIconsFill.paperPlaneRight,
                        size: 20,
                        color:
                            canSend || showMic ? Colors.white : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildRecordingBar(AuthPalette palette) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Descartar',
          onPressed: () => _stopRecording(send: false),
          icon: const Icon(
            PhosphorIconsRegular.trash,
            color: Brand.danger,
            size: 24,
          ),
        ),
        const SizedBox(width: 4),
        const _RecordingDot(),
        const SizedBox(width: 10),
        Text(
          formatDuration(_recordSeconds.toDouble()),
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.title,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Grabando…',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              color: palette.muted,
            ),
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: Brand.gradient,
          ),
          child: IconButton(
            tooltip: 'Enviar nota de voz',
            onPressed: () => _stopRecording(send: true),
            icon: const Icon(
              PhosphorIconsFill.paperPlaneRight,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Punto rojo que late mientras se graba.
class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_blink),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Brand.danger,
          shape: BoxShape.circle,
        ),
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
  final String myId;

  /// Nombre de quien escribió (solo en grupos, primera burbuja de la tanda).
  final String? senderName;

  /// Nombre corto del contacto (para "respondiendo a").
  final String otherName;
  final VoidCallback? onFailedTap;
  final VoidCallback? onMediaTap;
  final VoidCallback? onStickerLongPress;

  /// Tocar un sticker ajeno: guardarlo en mis stickers.
  final VoidCallback? onStickerTap;
  final bool isGroup;

  /// Mantener presionado: menú de acciones del mensaje.
  final VoidCallback? onReport;

  const _Bubble({
    required this.message,
    required this.tight,
    this.myId = '',
    this.senderName,
    this.otherName = '',
    this.onFailedTap,
    this.onMediaTap,
    this.onStickerLongPress,
    this.onStickerTap,
    this.isGroup = false,
    this.onReport,
  });

  /// Reacciones debajo de la burbuja: "❤️ 2  😂".
  Widget _reactions(AuthPalette palette) {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final mine = message.reactions[myId];
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
      child: GestureDetector(
        onTap: onReport,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: mine != null ? Brand.blue : palette.cardBorder,
            ),
          ),
          child: Text(
            [
              for (final e in counts.entries)
                e.value > 1 ? '${e.key} ${e.value}' : e.key,
            ].join('  '),
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 13,
              color: palette.title,
            ),
          ),
        ),
      ),
    );
  }

  String _quoteName(ReplyQuote quote) {
    if (quote.senderId == myId) return 'Tú';
    return quote.senderName ?? otherName;
  }

  /// Sticker: grande y sin burbuja, con la hora debajo.
  Widget _sticker(BuildContext context, AuthPalette palette, String time) {
    final m = message;
    final failed = m.status == MessageStatus.failed;
    final icon = switch (m.status) {
      MessageStatus.sending => PhosphorIconsRegular.clock,
      MessageStatus.failed => PhosphorIconsFill.warningCircle,
      MessageStatus.sent when m.isRead => PhosphorIconsRegular.checks,
      MessageStatus.sent => PhosphorIconsRegular.check,
    };

    return Padding(
      padding: EdgeInsets.only(top: tight ? 2 : 8),
      child: Align(
        alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: onFailedTap ?? (m.isMe ? null : onStickerTap),
          onLongPress: onStickerLongPress,
          child: Column(
            crossAxisAlignment:
                m.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              StickerImage(url: m.attachmentUrl ?? '', size: 140),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      failed ? 'No enviado · toca para reintentar' : time,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 11,
                        color: failed ? Brand.danger : palette.muted,
                      ),
                    ),
                    if (m.isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        icon,
                        size: 14,
                        color:
                            failed
                                ? Brand.danger
                                : m.isRead
                                ? Brand.blue
                                : palette.muted,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Foto o portada de video dentro de la burbuja.
  Widget _visual(AuthPalette palette) {
    final m = message;
    final ratio =
        (m.width != null && m.height != null && m.height! > 0)
            ? (m.width! / m.height!).clamp(0.6, 1.8)
            : 1.0;

    Widget image;
    if (m.attachmentType == 'image' && m.localBytes != null) {
      image = Image.memory(
        m.localBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else if (m.attachmentUrl != null) {
      image = Image(
        image: CachedNetworkImageProvider(
          m.attachmentType == 'video'
              ? CloudinaryUrl.videoPoster(m.attachmentUrl!, width: 600)
              : CloudinaryUrl.image(m.attachmentUrl!, width: 600),
        ),
        fit: BoxFit.cover,
        loadingBuilder:
            (_, child, progress) =>
                progress == null ? child : Container(color: palette.fieldFill),
        errorBuilder:
            (_, __, ___) => Container(
              color: palette.fieldFill,
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsRegular.imageBroken,
                color: palette.muted,
              ),
            ),
      );
    } else {
      image = Container(color: Colors.black87);
    }

    final uploading =
        m.status == MessageStatus.sending && m.attachmentUrl == null;

    return GestureDetector(
      onTap: m.attachmentUrl == null ? null : onMediaTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 240,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (m.attachmentType == 'video' &&
                    !uploading &&
                    m.duration != null)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsFill.videoCamera,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatDuration(m.duration!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (m.attachmentType == 'video' && !uploading)
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        PhosphorIconsFill.play,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                if (uploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        value: m.progress,
                        strokeWidth: 3,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _audio(AuthPalette palette) {
    final m = message;
    if (m.attachmentUrl == null) {
      return SizedBox(
        width: 220,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                value: m.status == MessageStatus.failed ? 0 : m.progress,
                strokeWidth: 2.5,
                color: m.isMe ? Colors.white : Brand.blue,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              m.status == MessageStatus.failed
                  ? 'Nota de voz'
                  : 'Enviando nota de voz…',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                color: m.isMe ? Colors.white : palette.title,
              ),
            ),
          ],
        ),
      );
    }
    return VoiceNotePlayer(
      url: m.attachmentUrl!,
      duration: m.duration,
      onDark: m.isMe && m.status != MessageStatus.failed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final isMe = message.isMe;

    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.minute.toString().padLeft(2, '0')}';

    final metaColor =
        isMe ? Colors.white.withValues(alpha: 0.75) : palette.muted;

    if (message.isDeleted) {
      return Padding(
        padding: EdgeInsets.only(top: tight ? 2 : 8),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: onReport,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.prohibit,
                    size: 15,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isMe ? 'Eliminaste este mensaje' : 'Mensaje eliminado',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 11,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final bubble = _buildBubble(context, palette, time, metaColor);
    if (message.reactions.isEmpty) return bubble;
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [bubble, _reactions(palette)],
    );
  }

  Widget _buildBubble(
    BuildContext context,
    AuthPalette palette,
    String time,
    Color metaColor,
  ) {
    final isMe = message.isMe;
    final failed = message.status == MessageStatus.failed;

    if (message.attachmentType == 'sticker') {
      return _sticker(context, palette, time);
    }

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
          onLongPress: onReport,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              padding:
                  message.hasVisual
                      ? const EdgeInsets.fromLTRB(4, 4, 4, 6)
                      : const EdgeInsets.fromLTRB(14, 9, 12, 7),
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
                  if (senderName != null)
                    Padding(
                      padding:
                          message.hasVisual
                              ? const EdgeInsets.fromLTRB(8, 2, 8, 4)
                              : const EdgeInsets.only(bottom: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: Text(
                          senderName!,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: senderColor(message.senderId ?? ''),
                          ),
                        ),
                      ),
                    ),
                  if (message.replyTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _QuoteBox(
                        quote: message.replyTo!,
                        name: _quoteName(message.replyTo!),
                        onDark: isMe,
                      ),
                    ),
                  if (message.hasVisual) _visual(palette),
                  if (message.attachmentType == 'audio') _audio(palette),
                  if (message.attachmentType == 'file')
                    FileBubble(
                      name:
                          message.fileName ?? message.localName ?? 'Documento',
                      url: message.attachmentUrl,
                      sizeBytes: message.sizeBytes,
                      onDark: isMe,
                      uploading:
                          message.status == MessageStatus.sending &&
                          message.attachmentUrl == null,
                      progress: message.progress,
                    ),
                  if (message.attachmentType == 'location' &&
                      message.lat != null &&
                      message.lng != null)
                    LocationBubble(
                      messageId:
                          message.id.startsWith('local') ? null : message.id,
                      lat: message.lat!,
                      lng: message.lng!,
                      liveUntil: message.liveUntil,
                      isMe: isMe,
                      isGroup: isGroup,
                      senderName: senderName ?? (isMe ? 'Tú' : otherName),
                    ),
                  if (message.text.isNotEmpty)
                    Padding(
                      padding:
                          message.hasVisual
                              ? const EdgeInsets.fromLTRB(10, 6, 8, 0)
                              : EdgeInsets.zero,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child:
                            sharedPostPattern.hasMatch(message.text)
                                ? _SharedPost(
                                  match:
                                      sharedPostPattern.firstMatch(
                                        message.text,
                                      )!,
                                  onDark: isMe,
                                )
                                : Text(
                                  message.text,
                                  style: TextStyle(
                                    fontFamily: Brand.displayFont,
                                    fontSize: 15,
                                    height: 1.35,
                                    color: isMe ? Colors.white : palette.title,
                                  ),
                                ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Padding(
                    padding:
                        message.hasVisual
                            ? const EdgeInsets.only(right: 8)
                            : EdgeInsets.zero,
                    child: Row(
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
  String text;
  final DateTime createdAt;
  final bool isMe;

  /// Para mis mensajes: si el otro ya lo leyó.
  bool isRead;
  MessageStatus status;

  /// Quién lo envió (en grupos, además su nombre y foto).
  final String? senderId;
  final String? senderName;

  /// "user" o "system" (avisos del grupo como "Ana agregó a Luis").
  final String kind;

  /// Mensaje que responde, reacciones ({usuario: emoji}) y si se eliminó.
  ReplyQuote? replyTo;
  Map<String, String> reactions;
  bool isDeleted;

  /// Adjunto: image | video | audio | sticker.
  String? attachmentType;
  String? attachmentUrl;
  int? width;
  int? height;
  double? duration;

  /// Documento: nombre y tamaño.
  String? fileName;
  int? sizeBytes;

  /// Ubicación (y, si es en tiempo real, hasta cuándo se actualiza).
  double? lat;
  double? lng;
  DateTime? liveUntil;

  /// Solo al enviar: por cuántos minutos se comparte en tiempo real.
  final int? liveMinutes;

  /// Mientras se envía: el archivo local y el avance de la subida.
  Uint8List? localBytes;
  final String? localName;
  double? progress;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.isMe,
    this.isRead = false,
    this.status = MessageStatus.sent,
    this.attachmentType,
    this.attachmentUrl,
    this.width,
    this.height,
    this.duration,
    this.localBytes,
    this.localName,
    this.fileName,
    this.sizeBytes,
    this.lat,
    this.lng,
    this.liveUntil,
    this.liveMinutes,
    this.senderId,
    this.senderName,
    this.kind = 'user',
    this.replyTo,
    Map<String, String>? reactions,
    this.isDeleted = false,
  }) : reactions = reactions ?? {};

  bool get isSystem => kind == 'system';

  /// Nueva posición de una ubicación en tiempo real (o que terminó).
  void applyLocation(Map<String, dynamic> a) {
    lat = (a['lat'] as num?)?.toDouble() ?? lat;
    lng = (a['lng'] as num?)?.toDouble() ?? lng;
    final until = DateTime.tryParse(a['live_until']?.toString() ?? '');
    if (until != null) liveUntil = until.toLocal();
  }

  /// Para agrupar burbujas seguidas del mismo autor.
  String get senderKey => isMe ? 'me' : (senderId ?? 'other');

  void markDeleted() {
    isDeleted = true;
    text = '';
    attachmentType = null;
    attachmentUrl = null;
    reactions = {};
  }

  bool get hasVisual => attachmentType == 'image' || attachmentType == 'video';

  /// Para abrirlo en el visor de pantalla completa.
  PublicationMediaItem? get asMediaItem =>
      attachmentUrl == null || !hasVisual
          ? null
          : PublicationMediaItem(
            type: attachmentType!,
            url: attachmentUrl!,
            width: width,
            height: height,
            duration: duration,
          );

  factory ChatMessageModel.fromBackend(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final attachment =
        json['attachment'] is Map
            ? Map<String, dynamic>.from(json['attachment'] as Map)
            : null;

    // 1 a 1 trae sender_id; los grupos traen sender {id, name}.
    final sender =
        json['sender'] is Map
            ? Map<String, dynamic>.from(json['sender'] as Map)
            : null;
    final senderId = json['sender_id']?.toString() ?? sender?['id']?.toString();

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      isMe: senderId != null && senderId == currentUserId,
      isRead: json['is_read'] == true,
      senderId: senderId,
      senderName: sender?['name']?.toString(),
      kind: json['kind']?.toString() ?? 'user',
      isDeleted: json['is_deleted'] == true,
      reactions: ChatService.reactionsFrom(json['reactions']),
      replyTo:
          json['reply_to'] is Map
              ? ReplyQuote.fromJson(
                Map<String, dynamic>.from(json['reply_to'] as Map),
              )
              : null,
      attachmentType: attachment?['type']?.toString(),
      attachmentUrl: attachment?['url']?.toString(),
      width: (attachment?['width'] as num?)?.toInt(),
      height: (attachment?['height'] as num?)?.toInt(),
      duration: (attachment?['duration'] as num?)?.toDouble(),
      fileName: attachment?['name']?.toString(),
      sizeBytes: (attachment?['size_bytes'] as num?)?.toInt(),
      lat: (attachment?['lat'] as num?)?.toDouble(),
      lng: (attachment?['lng'] as num?)?.toDouble(),
      liveUntil:
          DateTime.tryParse(
            attachment?['live_until']?.toString() ?? '',
          )?.toLocal(),
    );
  }
}

/// Publicación compartida por chat: tarjeta que la abre.
class _SharedPost extends StatelessWidget {
  final RegExpMatch match;
  final bool onDark;

  const _SharedPost({required this.match, required this.onDark});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final id = match.group(1)!;
    final title = (match.group(2) ?? '').trim();
    final fg = onDark ? Colors.white : palette.title;

    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicationDetailScreen(publicationId: id),
            ),
          ),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              onDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Brand.blue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(PhosphorIconsFill.newspaper, color: fg, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Publicación compartida',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: fg.withValues(alpha: 0.75),
                    ),
                  ),
                  Text(
                    title.isEmpty ? 'Ver publicación' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIconsRegular.caretRight, color: fg, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Mensaje citado al responder.
class ReplyQuote {
  final String id;
  final String? senderId;
  final String? senderName;
  final String content;
  final String? attachmentType;
  final bool isDeleted;

  const ReplyQuote({
    required this.id,
    this.senderId,
    this.senderName,
    this.content = '',
    this.attachmentType,
    this.isDeleted = false,
  });

  factory ReplyQuote.fromJson(Map<String, dynamic> json) => ReplyQuote(
    id: json['id']?.toString() ?? '',
    senderId: json['sender_id']?.toString(),
    senderName: json['sender_name']?.toString(),
    content: json['content']?.toString() ?? '',
    attachmentType: json['attachment_type']?.toString(),
    isDeleted: json['is_deleted'] == true,
  );

  factory ReplyQuote.fromMessage(ChatMessageModel m, {String? name}) =>
      ReplyQuote(
        id: m.id,
        senderId: m.senderId,
        senderName: name,
        content: m.text,
        attachmentType: m.attachmentType,
        isDeleted: m.isDeleted,
      );

  /// Texto corto: el mensaje, o "📷 Foto", "🎤 Nota de voz"…
  String get preview {
    if (isDeleted) return 'Mensaje eliminado';
    if (sharedPostPattern.hasMatch(content)) return '📰 Publicación';
    if (content.trim().isNotEmpty) return content.trim();
    return switch (attachmentType) {
      'image' => '📷 Foto',
      'video' => '🎥 Video',
      'audio' => '🎤 Nota de voz',
      'sticker' => '💟 Sticker',
      'file' => '📄 Documento',
      'location' => '📍 Ubicación',
      _ => 'Mensaje',
    };
  }
}

/// Cita dentro de la burbuja (o sobre la caja de texto al responder).
class _QuoteBox extends StatelessWidget {
  final ReplyQuote quote;
  final String? name;
  final bool onDark;

  const _QuoteBox({required this.quote, this.name, required this.onDark});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final accent = onDark ? Colors.white : Brand.blue;
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color:
            onDark
                ? Colors.white.withValues(alpha: 0.16)
                : Brand.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name ?? quote.senderName ?? 'Mensaje',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          Text(
            quote.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 13,
              fontStyle: quote.isDeleted ? FontStyle.italic : null,
              color:
                  onDark ? Colors.white.withValues(alpha: 0.85) : palette.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso del grupo ("Ana agregó a Luis").
class _SystemNote extends StatelessWidget {
  final String text;

  const _SystemNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: palette.fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 12.5,
              color: palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto verde de "en línea".
class OnlineDot extends StatelessWidget {
  final Color border;
  final double size;

  const OnlineDot({super.key, required this.border, this.size = 12});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF22C55E),
      shape: BoxShape.circle,
      border: Border.all(color: border, width: 2),
    ),
  );
}

/// Color estable por persona para su nombre en los grupos.
Color senderColor(String id) {
  const colors = [
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
  ];
  return colors[id.hashCode.abs() % colors.length];
}

/// "hoy a las 14:05", "ayer a las 9:30" o "12/11/2026".
String lastSeenLabel(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final hhmm =
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';
  final day = DateTime(when.year, when.month, when.day);
  final diff = DateTime(today.year, today.month, today.day).difference(day);
  if (diff.inDays == 0) return 'hoy a las $hhmm';
  if (diff.inDays == 1) return 'ayer a las $hhmm';
  return '${when.day.toString().padLeft(2, '0')}/'
      '${when.month.toString().padLeft(2, '0')}/${when.year}';
}
