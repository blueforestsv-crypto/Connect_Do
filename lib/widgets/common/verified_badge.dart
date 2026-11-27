import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/theme/brand.dart';

/// Insignia de empresa: ✓ azul si está verificada; un maletín gris si es una
/// empresa aún sin verificar (para que la gente lo sepa).
class VerifiedBadge extends StatelessWidget {
  final bool verified;
  final double size;

  const VerifiedBadge({super.key, required this.verified, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: verified ? 'Empresa verificada' : 'Empresa sin verificar',
      child: Icon(
        verified ? PhosphorIconsFill.sealCheck : PhosphorIconsRegular.briefcase,
        size: size,
        color: verified ? Brand.blue : AuthPalette.of(context).muted,
      ),
    );
  }
}
