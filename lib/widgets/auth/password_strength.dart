import 'package:flutter/material.dart';

import 'package:connect_do/theme/brand.dart';

/// Medidor de seguridad de la contraseña en 4 segmentos.
class PasswordStrength extends StatelessWidget {
  final String password;

  const PasswordStrength({super.key, required this.password});

  int get _score {
    if (password.length < 8) return 1;
    var score = 1;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      score++;
    }
    return score.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final score = password.isEmpty ? 0 : _score;

    const labels = ['', 'Débil', 'Aceptable', 'Buena', 'Fuerte'];
    const colors = [
      Colors.transparent,
      Brand.danger,
      Brand.warning,
      Brand.blue,
      Brand.green,
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topLeft,
      child:
          password.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    for (var i = 1; i <= 4; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                i <= score
                                    ? colors[score]
                                    : palette.fieldBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      if (i < 4) const SizedBox(width: 6),
                    ],
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 66,
                      child: Text(
                        labels[score],
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors[score],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
