import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/theme/brand.dart';

void _open(String path) {
  launchUrl(
    Uri.parse('${ApiConfig.baseUrl}$path'),
    mode: LaunchMode.externalApplication,
  );
}

List<InlineSpan> _links(AuthPalette palette) {
  final link = TextStyle(
    fontFamily: Brand.displayFont,
    fontWeight: FontWeight.w700,
    color: Brand.blue,
  );
  return [
    TextSpan(
      text: 'Términos',
      style: link,
      recognizer: TapGestureRecognizer()..onTap = () => _open('/terminos'),
    ),
    const TextSpan(text: ' y la '),
    TextSpan(
      text: 'Política de privacidad',
      style: link,
      recognizer: TapGestureRecognizer()..onTap = () => _open('/privacidad'),
    ),
  ];
}

/// Casilla obligatoria para crear una cuenta con correo.
class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;
  final bool enabled;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: value,
                activeColor: Brand.blue,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13,
                      height: 1.4,
                      color: palette.body,
                    ),
                    children: [
                      const TextSpan(text: 'Tengo 16 años o más y acepto los '),
                      ..._links(palette),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 12.5,
                color: Brand.danger,
              ),
            ),
          ),
      ],
    );
  }
}

/// Nota bajo el botón de Google: al continuar se aceptan los términos.
class GoogleTermsNote extends StatelessWidget {
  const GoogleTermsNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 12,
            height: 1.4,
            color: palette.muted,
          ),
          children: [
            const TextSpan(
              text:
                  'Al continuar con Google confirmas que tienes 16 años o más '
                  'y aceptas los ',
            ),
            ..._links(palette),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
