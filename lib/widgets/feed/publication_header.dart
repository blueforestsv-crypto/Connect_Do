import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/safety/report_sheet.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Autor, tiempo, visibilidad y menú de opciones de una publicación.
class PublicationHeader extends StatelessWidget {
  final PublicationModel post;

  /// Eliminar (solo se ofrece si la publicación es del usuario actual).
  final VoidCallback? onDelete;

  /// Ocultar del feed (solo se ofrece si no es del usuario actual).
  final VoidCallback? onHide;

  const PublicationHeader({
    super.key,
    required this.post,
    this.onDelete,
    this.onHide,
  });

  IconData get _visibilityIcon {
    switch (post.visibility) {
      case 'public':
        return PhosphorIconsRegular.globeHemisphereWest;
      case 'private':
        return PhosphorIconsRegular.lockSimple;
      default:
        return PhosphorIconsRegular.usersThree;
    }
  }

  bool get _canDelete => post.isMine && onDelete != null;
  bool get _canHide => !post.isMine && onHide != null;
  bool get _canReport => !post.isMine && post.id.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Row(
      children: [
        GestureDetector(
          onTap: () => _openAuthor(context),
          child: UserAvatar(name: post.userName, photo: post.userPhoto),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openAuthor(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timeAgo(post.createdAt),
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12.5,
                        color: palette.muted,
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                    Tooltip(
                      message: post.visibilityLabel,
                      child: Icon(
                        _visibilityIcon,
                        size: 13,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_canDelete || _canHide || _canReport)
          IconButton(
            tooltip: 'Opciones',
            onPressed: () => _showOptions(context),
            icon: Icon(
              PhosphorIconsRegular.dotsThree,
              color: palette.muted,
              size: 24,
            ),
          ),
      ],
    );
  }

  void _openAuthor(BuildContext context) {
    if (post.authorId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: post.authorId),
      ),
    );
  }

  void _showOptions(BuildContext context) {
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
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: palette.fieldBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (_canHide)
                  _OptionTile(
                    icon: PhosphorIconsRegular.eyeSlash,
                    color: palette.label,
                    title: 'Ocultar publicación',
                    subtitle: 'Dejarás de verla en tu inicio',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onHide!();
                    },
                  ),
                if (_canReport)
                  _OptionTile(
                    icon: PhosphorIconsRegular.flag,
                    color: palette.label,
                    title: 'Reportar publicación',
                    subtitle: 'Es anónimo',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showReportSheet(
                        context,
                        targetType: 'publication',
                        targetId: post.id,
                      );
                    },
                  ),
                if (_canReport && post.authorId.isNotEmpty)
                  _OptionTile(
                    icon: PhosphorIconsRegular.prohibit,
                    color: Brand.danger,
                    title: 'Bloquear a ${post.userName.split(' ').first}',
                    subtitle: 'No verás nada suyo ni podrá escribirte',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final blocked = await confirmBlock(
                        context,
                        userId: post.authorId,
                        name: post.userName,
                      );
                      if (blocked) onHide?.call();
                    },
                  ),
                if (_canDelete)
                  _OptionTile(
                    icon: PhosphorIconsRegular.trash,
                    color: Brand.danger,
                    title: 'Eliminar publicación',
                    subtitle: 'Se borrará para todos',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmDelete(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final palette = AuthPalette.of(context);

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusLg),
            ),
            title: Text(
              '¿Eliminar publicación?',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
            content: Text(
              'Se borrará junto con sus comentarios y me gusta. '
              'Esta acción no se puede deshacer.',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                height: 1.4,
                color: palette.body,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancelar', style: TextStyle(color: palette.body)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Brand.radiusSm),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onDelete!();
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.radiusMd),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Brand.radiusSm),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontWeight: FontWeight.w600,
          color: color == Brand.danger ? Brand.danger : palette.title,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 12.5,
          color: palette.muted,
        ),
      ),
      onTap: onTap,
    );
  }
}
