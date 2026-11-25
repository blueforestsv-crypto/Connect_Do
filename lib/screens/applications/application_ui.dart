import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/application_model.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Color e ícono de cada estado de postulación.
(Color, IconData) applicationStatusStyle(String status) {
  return switch (status) {
    'reviewed' => (Brand.blue, PhosphorIconsBold.eye),
    'contacted' => (const Color(0xFF0EA5E9), PhosphorIconsBold.chatCircle),
    'interview' => (const Color(0xFF8B5CF6), PhosphorIconsBold.calendarCheck),
    'selected' => (Brand.success, PhosphorIconsBold.sealCheck),
    'rejected' => (const Color(0xFF94A3B8), PhosphorIconsBold.x),
    _ => (const Color(0xFFF59E0B), PhosphorIconsBold.paperPlaneTilt),
  };
}

class ApplicationStatusPill extends StatelessWidget {
  final String status;

  const ApplicationStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = applicationStatusStyle(status);
    return StatusPill(
      label: ApplicationStatus.label(status),
      color: color,
      icon: icon,
    );
  }
}

/// Barra de 4 pasos: Enviada → Vista → Entrevista → Resultado.
class ApplicationProgress extends StatelessWidget {
  final String status;

  const ApplicationProgress({super.key, required this.status});

  int get _step => switch (status) {
    'new' => 0,
    'reviewed' || 'contacted' => 1,
    'interview' => 2,
    _ => 3,
  };

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final (color, _) = applicationStatusStyle(status);
    final labels = [
      'Enviada',
      'Vista',
      'Entrevista',
      status == 'rejected' ? 'Cerrada' : 'Resultado',
    ];

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= _step ? color : palette.fieldBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign:
                      i == 0
                          ? TextAlign.start
                          : i == 3
                          ? TextAlign.end
                          : TextAlign.center,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 11,
                    fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                    color: i == _step ? palette.title : palette.muted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Selector de 2–3 opciones con fondo deslizante.
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index ? palette.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow:
                        i == index
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: i == index ? palette.title : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
