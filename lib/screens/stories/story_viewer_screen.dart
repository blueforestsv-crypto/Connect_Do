import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:connect_do/services/social_service.dart';
import 'package:connect_do/widgets/safety/report_sheet.dart';
import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/services/story_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Historias a pantalla completa. Desliza entre personas; dentro de cada
/// una avanzan solas.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialGroup;

  const StoryViewerScreen({
    super.key,
    required this.groups,
    this.initialGroup = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialGroup,
  );
  late int _current = widget.initialGroup;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _nextGroup() {
    if (_current + 1 < widget.groups.length) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.maybePop(context);
    }
  }

  void _previousGroup() {
    if (_current > 0) {
      _pages.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Deslizar hacia abajo cierra.
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 600) Navigator.pop(context);
          },
          child: PageView.builder(
            controller: _pages,
            itemCount: widget.groups.length,
            onPageChanged: (page) => setState(() => _current = page),
            itemBuilder:
                (_, index) => _GroupPlayer(
                  key: ValueKey(widget.groups[index].user.id),
                  group: widget.groups[index],
                  active: index == _current,
                  onFinished: _nextGroup,
                  onBeforeFirst: _previousGroup,
                  onDeleted: () {
                    if (widget.groups[index].stories.isEmpty) _nextGroup();
                  },
                ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// HISTORIAS DE UNA PERSONA
// =====================================================
class _GroupPlayer extends StatefulWidget {
  final StoryGroup group;
  final bool active;
  final VoidCallback onFinished;
  final VoidCallback onBeforeFirst;
  final VoidCallback onDeleted;

  const _GroupPlayer({
    super.key,
    required this.group,
    required this.active,
    required this.onFinished,
    required this.onBeforeFirst,
    required this.onDeleted,
  });

  @override
  State<_GroupPlayer> createState() => _GroupPlayerState();
}

class _GroupPlayerState extends State<_GroupPlayer>
    with SingleTickerProviderStateMixin {
  static const Duration _photoDuration = Duration(seconds: 5);

  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });

  final TextEditingController _reply = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  late int _index = widget.group.isMe ? 0 : widget.group.firstUnseenIndex;
  VideoPlayerController? _video;
  bool _paused = false;
  bool _loading = true;

  StoryItem get _story => widget.group.stories[_index];

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(() {
      // Mientras escribe una respuesta, la historia se detiene.
      _replyFocus.hasFocus ? _pause() : _resume();
    });
    if (widget.active) _show();
  }

  @override
  void didUpdateWidget(covariant _GroupPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _show();
    if (!widget.active && oldWidget.active) {
      _progress.stop();
      _video?.pause();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _video?.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    if (widget.group.stories.isEmpty) return;
    _progress
      ..stop()
      ..value = 0;
    final old = _video;
    _video = null;
    old?.dispose();
    setState(() => _loading = true);

    final story = _story;
    if (!widget.group.isMe && !widget.group.isHighlight && !story.viewed) {
      story.viewed = true;
      StoryService.markViewed(story.id);
    }

    if (story.isVideo) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(CloudinaryUrl.video(story.url)),
      );
      _video = controller;
      try {
        await controller.initialize();
        if (!mounted || _video != controller) return;
        _progress.duration = controller.value.duration;
        setState(() => _loading = false);
        if (widget.active && !_paused) {
          controller.play();
          _progress.forward();
        }
      } catch (_) {
        if (mounted) _next();
      }
    } else {
      _progress.duration = _photoDuration;
      // La foto empieza a contar cuando terminó de cargar (ver _onImageLoaded).
    }
  }

  void _onImageLoaded() {
    if (!_loading) return;
    setState(() => _loading = false);
    if (widget.active && !_paused) _progress.forward();
  }

  void _next() {
    if (_index + 1 < widget.group.stories.length) {
      setState(() => _index++);
      _show();
    } else {
      widget.onFinished();
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
      _show();
    } else {
      widget.onBeforeFirst();
    }
  }

  void _pause() {
    _paused = true;
    _progress.stop();
    _video?.pause();
  }

  void _resume() {
    if (_replyFocus.hasFocus) return;
    _paused = false;
    if (!_loading && widget.active) {
      _progress.forward();
      _video?.play();
    }
  }

  static const _reactions = [
    '\u2764\ufe0f',
    '\ud83d\ude02',
    '\ud83d\ude2e',
    '\ud83d\ude22',
    '\ud83d\udc4f',
    '\ud83d\udd25',
  ];

  Future<void> _react(String emoji) async {
    HapticFeedback.mediumImpact();
    final story = _story;
    try {
      await ChatService.sendMessage(
        contactId: widget.group.user.id,
        content: 'Reaccionó $emoji a tu historia',
        attachment: {
          'type': story.type,
          'url': story.url,
          if (story.width != null) 'width': story.width,
          if (story.height != null) 'height': story.height,
        },
      );
      if (mounted) {
        showAuthMessage(
          context,
          'Enviaste $emoji',
          type: AuthMessageType.success,
        );
      }
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo enviar la reacción.');
    }
  }

  Future<void> _addToHighlight() async {
    _pause();
    final story = _story;
    List<Highlight> existing = [];
    try {
      existing = await SocialService.highlights(widget.group.user.id);
    } catch (_) {}
    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.plusCircle,
                    color: Brand.blue,
                  ),
                  title: Text(
                    'Nueva destacada',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w700,
                      color: palette.title,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ''),
                ),
                for (final h in existing)
                  ListTile(
                    leading: const Icon(
                      PhosphorIconsRegular.star,
                      color: Brand.blue,
                    ),
                    title: Text(
                      h.title,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontWeight: FontWeight.w600,
                        color: palette.title,
                      ),
                    ),
                    onTap: () => Navigator.pop(sheetContext, h.id),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) {
      _resume();
      return;
    }

    try {
      if (choice.isEmpty) {
        final controller = TextEditingController();
        final title = await showDialog<String>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Nombre de la destacada'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    hintText: 'Proyectos, eventos…',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed:
                        () => Navigator.pop(
                          dialogContext,
                          controller.text.trim(),
                        ),
                    child: const Text('Crear'),
                  ),
                ],
              ),
        );
        controller.dispose();
        if (title == null || title.isEmpty) {
          _resume();
          return;
        }
        await SocialService.createHighlight(title, [story.id]);
      } else {
        await SocialService.addToHighlight(choice, [story.id]);
      }
      if (mounted) {
        showAuthMessage(
          context,
          'Destacada en tu perfil',
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
    _resume();
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final story = _story;
    _reply.clear();
    _replyFocus.unfocus();
    try {
      await ChatService.sendMessage(
        contactId: widget.group.user.id,
        content: '↩️ Respuesta a tu historia: $text',
        attachment: {
          'type': story.type,
          'url': story.url,
          if (story.width != null) 'width': story.width,
          if (story.height != null) 'height': story.height,
        },
      );
      if (mounted) {
        showAuthMessage(
          context,
          'Respuesta enviada',
          type: AuthMessageType.success,
        );
      }
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo enviar la respuesta.');
    }
  }

  Future<void> _showViewers() async {
    _pause();
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ViewersSheet(storyId: _story.id),
    );
    _resume();
  }

  Future<void> _delete() async {
    _pause();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('¿Borrar esta historia?'),
            content: const Text('Nadie podrá volver a verla.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Borrar',
                  style: TextStyle(color: Brand.danger),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      _resume();
      return;
    }
    try {
      await StoryService.delete(_story.id);
      if (!mounted) return;
      setState(() {
        widget.group.stories.removeAt(_index);
        if (_index >= widget.group.stories.length) {
          _index = (widget.group.stories.length - 1).clamp(0, 1 << 20);
        }
      });
      if (widget.group.stories.isEmpty) {
        widget.onDeleted();
      } else {
        _paused = false;
        _show();
      }
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo borrar.');
      _resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.stories.isEmpty) return const SizedBox.shrink();
    final story = _story;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ---------- contenido ----------
        Center(
          child:
              story.isVideo
                  ? (_video != null && _video!.value.isInitialized
                      ? AspectRatio(
                        aspectRatio: _video!.value.aspectRatio,
                        child: VideoPlayer(_video!),
                      )
                      : Image(
                        image: CachedNetworkImageProvider(
                          CloudinaryUrl.videoPoster(story.url, width: 1080),
                        ),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ))
                  : Image(
                    image: CachedNetworkImageProvider(
                      CloudinaryUrl.image(story.url, width: 1440),
                    ),
                    key: ValueKey(story.id),
                    fit: BoxFit.contain,
                    frameBuilder: (_, child, frame, __) {
                      if (frame != null) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _onImageLoaded(),
                        );
                      }
                      return child;
                    },
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _onImageLoaded(),
                      );
                      return const Icon(
                        PhosphorIconsRegular.imageBroken,
                        color: Colors.white54,
                        size: 48,
                      );
                    },
                  ),
        ),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          ),

        // ---------- toques: izquierda / derecha / mantener ----------
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _previous,
                onLongPressStart: (_) => _pause(),
                onLongPressEnd: (_) => _resume(),
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _next,
                onLongPressStart: (_) => _pause(),
                onLongPressEnd: (_) => _resume(),
              ),
            ),
          ],
        ),

        // ---------- arriba: barras y autor ----------
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              10,
              MediaQuery.of(context).padding.top + 8,
              4,
              16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < widget.group.stories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder:
                                (_, __) => LinearProgressIndicator(
                                  minHeight: 2.5,
                                  value:
                                      i < _index
                                          ? 1
                                          : i == _index
                                          ? _progress.value
                                          : 0,
                                  color: Colors.white,
                                  backgroundColor: Colors.white30,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    UserAvatar(
                      name: widget.group.user.name,
                      photo: widget.group.user.photo,
                      radius: 17,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.group.isMe ? 'Tu historia' : widget.group.user.name}'
                        '  ·  ${timeAgo(story.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Brand.displayFont,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!widget.group.isMe && !widget.group.isHighlight)
                      IconButton(
                        tooltip: 'Reportar historia',
                        onPressed: () async {
                          _pause();
                          await showReportSheet(
                            context,
                            targetType: 'story',
                            targetId: story.id,
                          );
                          _resume();
                        },
                        icon: const Icon(
                          PhosphorIconsRegular.flag,
                          color: Colors.white,
                        ),
                      ),
                    if (widget.group.isMe && !widget.group.isHighlight) ...[
                      IconButton(
                        tooltip: 'Destacar en mi perfil',
                        onPressed: _addToHighlight,
                        icon: const Icon(
                          PhosphorIconsRegular.star,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    if (widget.group.isMe && !widget.group.isHighlight)
                      IconButton(
                        tooltip: 'Borrar historia',
                        onPressed: _delete,
                        icon: const Icon(
                          PhosphorIconsRegular.trash,
                          color: Colors.white,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        PhosphorIconsRegular.x,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ---------- abajo: texto y acciones ----------
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              24,
              12,
              12 + bottomInset + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((story.caption ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      story.caption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: Brand.displayFont,
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.35,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                    ),
                  ),
                if (widget.group.isHighlight)
                  const SizedBox.shrink()
                else if (widget.group.isMe)
                  TextButton.icon(
                    onPressed: _showViewers,
                    icon: const Icon(
                      PhosphorIconsRegular.eye,
                      color: Colors.white,
                    ),
                    label: Text(
                      '${story.viewsCount ?? 0}',
                      style: const TextStyle(
                        fontFamily: Brand.displayFont,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  )
                else ...[
                  // Reacciones rápidas: le llegan por chat.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final emoji in _reactions)
                          GestureDetector(
                            onTap: () => _react(emoji),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white54),
                          ),
                          child: TextField(
                            controller: _reply,
                            focusNode: _replyFocus,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendReply(),
                            decoration: InputDecoration(
                              hintText:
                                  'Responder a '
                                  '${widget.group.user.name.split(' ').first}…',
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Enviar respuesta',
                        onPressed: _sendReply,
                        icon: const Icon(
                          PhosphorIconsFill.paperPlaneRight,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// QUIÉN LA VIO
// =====================================================
class _ViewersSheet extends StatelessWidget {
  final String storyId;

  const _ViewersSheet({required this.storyId});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Brand.radiusLg),
        ),
      ),
      child: FutureBuilder<List<StoryViewerEntry>>(
        future: StoryService.viewers(storyId),
        builder: (context, snapshot) {
          final title = Text(
            snapshot.hasData ? 'Vista por ${snapshot.data!.length}' : 'Vistas',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: palette.title,
            ),
          );

          if (!snapshot.hasData) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Brand.blue),
                ),
              ],
            );
          }

          final viewers = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 8),
              if (viewers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nadie la ha visto todavía.',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      color: palette.muted,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final viewer in viewers)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(
                            name: viewer.user.name,
                            photo: viewer.user.photo,
                          ),
                          title: Text(
                            viewer.user.name,
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontWeight: FontWeight.w600,
                              color: palette.title,
                            ),
                          ),
                          trailing: Text(
                            timeAgo(viewer.viewedAt),
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              color: palette.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
