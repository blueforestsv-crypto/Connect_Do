import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:record/record.dart';

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

/// Conversación con un contacto. Se actualiza cada pocos segundos.
class IndividualChatScreen extends StatefulWidget {
  /// Id del contacto cuya conversación está abierta ahora (o null).
  static String? get openChatId => _IndividualChatScreenState.openChatId;

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

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
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
    _pollTimer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (openChatId == widget.chatId) openChatId = null;
    _pollTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _myId = (await UserService.getUser())['id']?.toString() ?? '';
    await _fetch(initial: true);
    _startPolling();
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
      final data = await ChatService.getMessages(
        contactId: widget.chatId,
        after: complete ? null : newest,
      );
      final incoming =
          data
              .map((m) => ChatMessageModel.fromBackend(m, currentUserId: _myId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Solo marca como leído si hay mensajes nuevos del otro sin leer.
      if (incoming.any((m) => !m.isMe && !m.isRead)) {
        ChatService.markAsRead(contactId: widget.chatId).ignore();
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
    setState(() => _pending.insert(0, pending));
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
      final created = await ChatService.sendMessage(
        contactId: widget.chatId,
        content: pending.text,
        attachment:
            pending.attachmentUrl == null
                ? null
                : {
                  'type': pending.attachmentType,
                  'url': pending.attachmentUrl,
                  if (pending.width != null) 'width': pending.width,
                  if (pending.height != null) 'height': pending.height,
                  if (pending.duration != null) 'duration': pending.duration,
                },
      );
      if (!mounted) return;
      final sent = ChatMessageModel.fromBackend(created, currentUserId: _myId)
        // Se conserva la vista local para que la foto no "parpadee".
        ..localBytes = pending.localBytes;
      setState(() {
        _pending.remove(pending);
        _messages.insert(0, sent);
      });
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
            child: Row(
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
          ),
        );
      },
    );
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
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: Icon(
              PhosphorIconsRegular.dotsThreeVertical,
              color: palette.title,
            ),
            onSelected: (value) async {
              if (value == 'report') {
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
                (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Reportar')),
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
                            newer.isMe == message.isMe &&
                            _sameDay(newer.createdAt, message.createdAt);

                        return Column(
                          children: [
                            if (showDay) _DayChip(date: message.createdAt),
                            _Bubble(
                              message: message,
                              tight: groupedWithNewer,
                              onMediaTap: () => _openMedia(message),
                              onStickerLongPress:
                                  () => _stickerOptions(message),
                              onReport:
                                  message.isMe || message.id.startsWith('local')
                                      ? null
                                      : () => showReportSheet(
                                        context,
                                        targetType: 'message',
                                        targetId: message.id,
                                      ),
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
  final VoidCallback? onFailedTap;
  final VoidCallback? onMediaTap;
  final VoidCallback? onStickerLongPress;
  final VoidCallback? onReport;

  const _Bubble({
    required this.message,
    required this.tight,
    this.onFailedTap,
    this.onMediaTap,
    this.onStickerLongPress,
    this.onReport,
  });

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
          onTap: onFailedTap,
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
    final failed = message.status == MessageStatus.failed;

    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.minute.toString().padLeft(2, '0')}';

    final metaColor =
        isMe ? Colors.white.withValues(alpha: 0.75) : palette.muted;

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
                  if (message.hasVisual) _visual(palette),
                  if (message.attachmentType == 'audio') _audio(palette),
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
  final String text;
  final DateTime createdAt;
  final bool isMe;

  /// Para mis mensajes: si el otro ya lo leyó.
  final bool isRead;
  MessageStatus status;

  /// Adjunto: image | video | audio.
  final String? attachmentType;
  String? attachmentUrl;
  int? width;
  int? height;
  double? duration;

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
  });

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

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      text: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      isMe: json['sender_id']?.toString() == currentUserId,
      isRead: json['is_read'] == true,
      attachmentType: attachment?['type']?.toString(),
      attachmentUrl: attachment?['url']?.toString(),
      width: (attachment?['width'] as num?)?.toInt(),
      height: (attachment?['height'] as num?)?.toInt(),
      duration: (attachment?['duration'] as num?)?.toDouble(),
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
