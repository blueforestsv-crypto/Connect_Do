import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/safety/report_sheet.dart';
import 'package:connect_do/models/comment_model.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Panel inferior con los comentarios de una publicación (del servidor).
class CommentSheet extends StatefulWidget {
  final PublicationModel post;

  /// Se llama cada vez que cambia el total de comentarios.
  final ValueChanged<int>? onCountChanged;

  const CommentSheet({super.key, required this.post, this.onCountChanged});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  static const int _maxLength = 1000;

  final PublicationApiService _api = PublicationApiService();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isSending = false;

  /// Comentario que se está editando (el texto va en el mismo campo).
  CommentModel? _editing;

  String _myName = 'Tú';
  String _myPhoto = '';

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _loadMe();
    _loadComments();
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final user = await UserService.getUser();
    final name =
        '${user['firstName'] ?? user['first_name'] ?? ''} '
                '${user['lastName'] ?? user['last_name'] ?? ''}'
            .trim();
    final base64Photo = user['profile_image_base64']?.toString() ?? '';
    final googlePhoto = user['google_photo_url']?.toString() ?? '';

    if (!mounted) return;
    setState(() {
      _myName = name.isEmpty ? 'Tú' : name;
      _myPhoto = base64Photo.isNotEmpty ? base64Photo : googlePhoto;
    });
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final comments = await _api.getComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
      widget.onCountChanged?.call(comments.length);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  // ===============================
  // ENVIAR / EDITAR
  // ===============================
  Future<void> _submit() async {
    final text = _input.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      if (_editing != null) {
        final updated = await _api.updateComment(
          widget.post.id,
          _editing!.id,
          text,
        );
        if (!mounted) return;
        setState(() {
          final index = _comments.indexWhere((c) => c.id == updated.id);
          if (index != -1) _comments[index] = updated;
          _editing = null;
        });
      } else {
        final created = await _api.addComment(widget.post.id, text);
        if (!mounted) return;
        HapticFeedback.lightImpact();
        setState(() => _comments.add(created));
        widget.onCountChanged?.call(_comments.length);
        _scrollToEnd();
      }
      _input.clear();
    } catch (error) {
      if (mounted) showAuthMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startEditing(CommentModel comment) {
    setState(() => _editing = comment);
    _input
      ..text = comment.text
      ..selection = TextSelection.collapsed(offset: comment.text.length);
    _inputFocus.requestFocus();
  }

  void _cancelEditing() {
    setState(() => _editing = null);
    _input.clear();
  }

  Future<void> _delete(CommentModel comment) async {
    final index = _comments.indexOf(comment);
    setState(() => _comments.remove(comment));

    try {
      await _api.deleteComment(widget.post.id, comment.id);
      widget.onCountChanged?.call(_comments.length);
      if (_editing?.id == comment.id) _cancelEditing();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _comments.insert(index.clamp(0, _comments.length), comment),
      );
      showAuthMessage(context, error.toString());
    }
  }

  void _showOptions(CommentModel comment) {
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);

        Widget option(
          IconData icon,
          String text,
          Color color,
          VoidCallback onTap,
        ) {
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              text,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            onTap: () {
              Navigator.pop(sheetContext);
              onTap();
            },
          );
        }

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
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: palette.fieldBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (comment.isMine)
                  option(
                    PhosphorIconsRegular.pencilSimple,
                    'Editar comentario',
                    palette.title,
                    () => _startEditing(comment),
                  ),
                if (comment.canDelete)
                  option(
                    PhosphorIconsRegular.trash,
                    'Eliminar comentario',
                    Brand.danger,
                    () => _delete(comment),
                  ),
                if (!comment.isMine)
                  option(
                    PhosphorIconsRegular.flag,
                    'Reportar comentario',
                    palette.title,
                    () => showReportSheet(
                      context,
                      targetType: 'comment',
                      targetId: comment.id,
                    ),
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
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.fieldBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Text(
                    'Comentarios',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.title,
                    ),
                  ),
                  if (_comments.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Brand.blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_comments.length}',
                        style: const TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.blue,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(PhosphorIconsRegular.x, color: palette.muted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.cardBorder),
            Expanded(child: _buildBody(palette)),
            _buildInput(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AuthPalette palette) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Brand.blue, strokeWidth: 2.5),
      );
    }

    if (_loadError != null) {
      return _CenteredMessage(
        icon: PhosphorIconsRegular.cloudSlash,
        title: 'No se pudieron cargar',
        subtitle: _loadError!,
        action: TextButton.icon(
          onPressed: _loadComments,
          icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
          label: const Text('Reintentar'),
        ),
      );
    }

    if (_comments.isEmpty) {
      return const _CenteredMessage(
        icon: PhosphorIconsRegular.chatTeardropText,
        title: 'Aún no hay comentarios',
        subtitle: 'Sé la primera persona en comentar.',
      );
    }

    return ListView.separated(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _buildComment(_comments[index], palette),
    );
  }

  Widget _buildComment(CommentModel comment, AuthPalette palette) {
    final isPostAuthor =
        widget.post.authorId.isNotEmpty &&
        comment.authorId == widget.post.authorId;
    return GestureDetector(
      // Mantener presionado: editar/eliminar (míos) o reportar (de otros).
      onLongPress: () => _showOptions(comment),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: comment.authorName,
            photo: comment.authorPhoto,
            radius: 17,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color:
                        _editing?.id == comment.id
                            ? Brand.blue.withValues(alpha: 0.08)
                            : palette.fieldFill,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      topLeft: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              comment.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: palette.title,
                              ),
                            ),
                          ),
                          if (isPostAuthor) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Brand.green.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Autor',
                                style: TextStyle(
                                  fontFamily: Brand.displayFont,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Brand.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.text,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 14.5,
                          height: 1.4,
                          color: palette.label,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4),
                  child: Row(
                    children: [
                      Text(
                        timeAgo(comment.createdAt) +
                            (comment.wasEdited ? ' · editado' : ''),
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12,
                          color: palette.muted,
                        ),
                      ),
                      ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _showOptions(comment),
                          child: Text(
                            'Opciones',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.body,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(AuthPalette palette) {
    final canSend = _input.text.trim().isNotEmpty && !_isSending;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.cardBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 15,
                    color: Brand.blue,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Editando comentario',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Brand.blue,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelEditing,
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: UserAvatar(name: _myName, photo: _myPhoto, radius: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: palette.fieldFill,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: palette.fieldBorder),
                  ),
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: _maxLength,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: Brand.blue,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 15,
                      color: palette.title,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario…',
                      hintStyle: TextStyle(
                        fontFamily: Brand.displayFont,
                        color: palette.muted,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: canSend ? Brand.gradient : null,
                  color: canSend ? null : palette.fieldBorder,
                ),
                child: IconButton(
                  tooltip: _editing != null ? 'Guardar' : 'Enviar',
                  onPressed: canSend ? _submit : null,
                  icon:
                      _isSending
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Icon(
                            _editing != null
                                ? PhosphorIconsRegular.check
                                : PhosphorIconsFill.paperPlaneRight,
                            size: 19,
                            color: canSend ? Colors.white : palette.muted,
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Brand.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: Brand.blue),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 13.5,
                color: palette.muted,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
