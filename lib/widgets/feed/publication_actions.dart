import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/services/saved_publication_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/comment_sheet.dart';

/// Contadores y botones: me gusta, comentar, guardar y compartir.
class PublicationActions extends StatefulWidget {
  final PublicationModel post;
  final VoidCallback? onSavedChanged;

  /// Avisa al feed cuando cambian likes o comentarios, para que el estado
  /// se conserve al desplazarse y volver.
  final ValueChanged<PublicationModel>? onChanged;

  const PublicationActions({
    super.key,
    required this.post,
    this.onSavedChanged,
    this.onChanged,
  });

  @override
  State<PublicationActions> createState() => _PublicationActionsState();
}

class _PublicationActionsState extends State<PublicationActions>
    with SingleTickerProviderStateMixin {
  static final PublicationApiService _api = PublicationApiService();

  late bool _liked = widget.post.likedByMe;
  late int _likes = widget.post.likes;
  late int _comments = widget.post.comments;
  bool _saved = false;
  bool _likeInFlight = false;

  late final AnimationController _likeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _likeScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.9, end: 1), weight: 30),
  ]).animate(CurvedAnimation(parent: _likeController, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void didUpdateWidget(covariant PublicationActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al refrescar el feed llegan datos nuevos del servidor.
    if (oldWidget.post != widget.post && !_likeInFlight) {
      _liked = widget.post.likedByMe;
      _likes = widget.post.likes;
      _comments = widget.post.comments;
    }
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedPublicationService.isSaved(widget.post.id);
    if (mounted) setState(() => _saved = saved);
  }

  void _notifyChanged() {
    widget.onChanged?.call(
      widget.post.copyWith(
        likes: _likes,
        comments: _comments,
        likedByMe: _liked,
      ),
    );
  }

  // ===============================
  // ME GUSTA (optimista)
  // ===============================
  Future<void> _toggleLike() async {
    if (_likeInFlight) return;

    final previousLiked = _liked;
    final previousLikes = _likes;
    final next = !_liked;

    HapticFeedback.lightImpact();
    if (next) _likeController.forward(from: 0);

    setState(() {
      _likeInFlight = true;
      _liked = next;
      _likes = (_likes + (next ? 1 : -1)).clamp(0, 1 << 31);
    });

    try {
      final result = await _api.setLiked(widget.post.id, liked: next);
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likes = result.likesCount;
      });
      _notifyChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likes = previousLikes;
      });
      showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

  // ===============================
  // GUARDAR (local)
  // ===============================
  Future<void> _toggleSave() async {
    HapticFeedback.selectionClick();

    if (_saved) {
      await SavedPublicationService.removeSavedPublication(widget.post.id);
    } else {
      await SavedPublicationService.savePublication(widget.post);
    }

    if (!mounted) return;
    setState(() => _saved = !_saved);
    widget.onSavedChanged?.call();

    showAuthMessage(
      context,
      _saved ? 'Guardada en tu perfil' : 'Se quitó de guardados',
      type: AuthMessageType.info,
    );
  }

  // ===============================
  // COMENTARIOS
  // ===============================
  Future<void> _openComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CommentSheet(
            post: widget.post,
            onCountChanged: (count) {
              if (!mounted) return;
              setState(() => _comments = count);
              _notifyChanged();
            },
          ),
    );
  }

  // ===============================
  // COMPARTIR
  // ===============================
  Future<void> _share() async {
    final post = widget.post;
    final buffer =
        StringBuffer()
          ..writeln('Mira esta publicación de ${post.userName} en Connect Do:');

    if (post.title.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(post.title.trim());
    }
    if (post.description.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(post.description.trim());
    }

    try {
      final filePath = post.filePath ?? post.imagePath;
      final hasLocalFile =
          filePath != null &&
          filePath.startsWith('/') &&
          File(filePath).existsSync();

      if (hasLocalFile) {
        await Share.shareXFiles([XFile(filePath)], text: buffer.toString());
      } else {
        await Share.share(buffer.toString());
      }
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo compartir.');
    }
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Column(
      children: [
        Divider(height: 1, color: palette.cardBorder),
        const SizedBox(height: 6),
        Row(
          children: [
            ScaleTransition(
              scale: _likeScale,
              child: _ActionButton(
                icon:
                    _liked
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsRegular.heart,
                semanticLabel: _liked ? 'Quitar me gusta' : 'Me gusta',
                count: _likes,
                color: _liked ? const Color(0xFFEF4444) : palette.body,
                onTap: _toggleLike,
              ),
            ),
            _ActionButton(
              icon: PhosphorIconsRegular.chatCircle,
              semanticLabel: 'Comentarios',
              count: _comments,
              color: palette.body,
              onTap: _openComments,
            ),
            _ActionButton(
              icon: PhosphorIconsRegular.shareFat,
              semanticLabel: 'Compartir',
              color: palette.body,
              onTap: _share,
            ),
            const Spacer(),
            _ActionButton(
              icon:
                  _saved
                      ? PhosphorIconsFill.bookmarkSimple
                      : PhosphorIconsRegular.bookmarkSimple,
              semanticLabel: _saved ? 'Quitar de guardados' : 'Guardar',
              color: _saved ? Brand.blue : palette.body,
              onTap: _toggleSave,
            ),
          ],
        ),
      ],
    );
  }
}

/// Botón de acción: ícono y, si aplica, contador al lado.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final Color color;
  final VoidCallback onTap;
  final int? count;

  const _ActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    this.count,
  });

  String get _countText {
    final value = count ?? 0;
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)} mil';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final showCount = (count ?? 0) > 0;

    return Semantics(
      button: true,
      label: showCount ? '$semanticLabel, $count' : semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          // Área táctil mínima recomendada.
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child:
                      showCount
                          ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              _countText,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
