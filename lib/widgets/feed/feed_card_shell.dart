import 'package:flutter/material.dart';

import 'package:connect_do/theme/brand.dart';

/// Contenedor visual común de las tarjetas del feed.
class FeedCardShell extends StatelessWidget {
  final Widget child;

  /// Franja superior de color (se usa en oportunidades).
  final Color? accent;

  const FeedCardShell({super.key, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (accent != null) Container(height: 4, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: child,
          ),
        ],
      ),
    );
  }
}
