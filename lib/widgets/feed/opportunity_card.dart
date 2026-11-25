import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/application_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/feed/expandable_text.dart';
import 'package:connect_do/widgets/feed/publication_actions.dart';
import 'package:connect_do/widgets/feed/publication_header.dart';
import 'package:connect_do/widgets/feed/publication_media.dart';
import 'package:connect_do/widgets/feed/feed_card_shell.dart';

/// Ícono y color de cada tipo de oportunidad.
(IconData, Color) opportunityStyle(String type) {
  switch (type) {
    case 'job':
      return (PhosphorIconsRegular.briefcase, Brand.blue);
    case 'internship':
      return (PhosphorIconsRegular.student, const Color(0xFF8B5CF6));
    case 'social_service':
      return (PhosphorIconsRegular.handHeart, Brand.green);
    case 'freelance':
      return (PhosphorIconsRegular.laptop, const Color(0xFFF59E0B));
    default:
      return (PhosphorIconsRegular.briefcase, Brand.blue);
  }
}

class OpportunityCard extends StatefulWidget {
  final PublicationModel post;
  final VoidCallback? onDelete;
  final VoidCallback? onHide;
  final VoidCallback? onSavedChanged;
  final ValueChanged<PublicationModel>? onChanged;

  const OpportunityCard({
    super.key,
    required this.post,
    this.onDelete,
    this.onHide,
    this.onSavedChanged,
    this.onChanged,
  });

  @override
  State<OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends State<OpportunityCard> {
  final ApplicationService _applicationService = ApplicationService();

  bool isApplying = false;
  bool _appliedHere = false;

  /// También cuenta las postulaciones hechas antes (cargadas por el feed).
  bool get hasApplied =>
      _appliedHere ||
      ApplicationService.appliedPublicationIds.contains(widget.post.id);

  Future<void> _apply() async {
    if (isApplying || hasApplied) return;

    setState(() => isApplying = true);

    try {
      await _applicationService.applyToPublication(
        publicationId: widget.post.id,
        coverMessage:
            'Hola, me interesa aplicar a ${widget.post.displayTitle}.',
      );

      if (!mounted) return;
      setState(() => _appliedHere = true);
      showAuthMessage(
        context,
        'Postulación enviada. ¡Mucho éxito!',
        type: AuthMessageType.success,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.contains('Ya aplicaste')) {
        setState(() => _appliedHere = true);
      }
      showAuthMessage(context, message);
    } finally {
      if (mounted) setState(() => isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final post = widget.post;
    final (icon, color) = opportunityStyle(post.type);

    return FeedCardShell(
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PublicationHeader(
            post: post,
            onDelete: widget.onDelete,
            onHide: widget.onHide,
          ),
          const SizedBox(height: 14),
          _TypeBadge(icon: icon, color: color, label: post.typeLabel),
          if (post.title.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.title,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 19,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: palette.title,
              ),
            ),
          ],
          if (post.hasLocation || post.hasModality) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (post.hasLocation)
                  _InfoChip(
                    icon: PhosphorIconsRegular.mapPin,
                    label: post.location!,
                  ),
                if (post.hasModality)
                  _InfoChip(
                    icon: PhosphorIconsRegular.laptop,
                    label: post.modalityLabel,
                  ),
              ],
            ),
          ],
          if (post.description.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'DETALLES',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                color: palette.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            ExpandableText(text: post.description, textColor: palette.label),
          ],
          if (post.hasAnyMedia) ...[
            const SizedBox(height: 14),
            PublicationMedia(post: post),
          ],
          // No tiene sentido postularse a una oportunidad propia.
          if (!post.isMine) ...[
            const SizedBox(height: 16),
            _buildApplyButton(palette),
          ],
          const SizedBox(height: 12),
          PublicationActions(
            post: post,
            onSavedChanged: widget.onSavedChanged,
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton(AuthPalette palette) {
    if (hasApplied) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: Brand.green.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Brand.radiusMd),
          border: Border.all(color: Brand.green.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsFill.checkCircle, color: Brand.success, size: 20),
            SizedBox(width: 8),
            Text(
              'Postulación enviada',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Brand.success,
              ),
            ),
          ],
        ),
      );
    }

    return GradientButton(
      text: 'Aplicar a esta oportunidad',
      isLoading: isApplying,
      trailingIcon: PhosphorIconsRegular.paperPlaneRight,
      onPressed: _apply,
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _TypeBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AuthPalette.of(context).isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.fieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.body),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              color: palette.label,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
