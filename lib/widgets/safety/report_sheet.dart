import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/safety_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Pide el motivo y envía el reporte. [targetType]: user | publication |
/// comment | story | message.
Future<void> showReportSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? title,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => _ReasonSheet(
          title:
              title ??
              switch (targetType) {
                'user' => 'Reportar cuenta',
                'publication' => 'Reportar publicación',
                'comment' => 'Reportar comentario',
                'story' => 'Reportar historia',
                _ => 'Reportar mensaje',
              },
        ),
  );
  if (reason == null || !context.mounted) return;

  try {
    await SafetyService.report(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
    );
    if (context.mounted) {
      showAuthMessage(
        context,
        'Gracias. Revisaremos el reporte; quien reportaste no sabrá que '
        'fuiste tú.',
        type: AuthMessageType.success,
      );
    }
  } catch (error) {
    if (context.mounted) {
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

/// Confirma y bloquea. Devuelve true si se bloqueó.
Future<bool> confirmBlock(
  BuildContext context, {
  required String userId,
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text('¿Bloquear a $name?'),
          content: const Text(
            'No podrá ver tu perfil, tus publicaciones ni escribirte, y '
            'dejarán de ser contactos. No le avisaremos. Puedes desbloquearle '
            'en Configuración.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Bloquear',
                style: TextStyle(color: Brand.danger),
              ),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await SafetyService.block(userId);
    if (context.mounted) {
      showAuthMessage(
        context,
        '$name fue bloqueado',
        type: AuthMessageType.success,
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
    return false;
  }
}

class _ReasonSheet extends StatelessWidget {
  final String title;

  const _ReasonSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Material(
      color: palette.card,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Brand.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  '¿Por qué lo reportas? Es anónimo.',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13,
                    color: palette.muted,
                  ),
                ),
              ),
              for (final entry in reportReasons.entries)
                ListTile(
                  dense: true,
                  leading: Icon(
                    PhosphorIconsRegular.flag,
                    color: palette.muted,
                    size: 20,
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
