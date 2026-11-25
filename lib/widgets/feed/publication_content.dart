import 'package:flutter/material.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/feed/expandable_text.dart';

class PublicationContent extends StatelessWidget {
  final PublicationModel post;

  const PublicationContent({super.key, required this.post});

  /// En publicaciones generales el título se arma con el inicio del texto;
  /// si es así, no se muestra para no repetir la misma frase.
  bool get _hasTitle {
    final title = post.title.trim();
    if (title.isEmpty) return false;

    final prefix = title.replaceAll(RegExp(r'(\.\.\.|…)$'), '').trim();
    final repeatsText =
        prefix.isNotEmpty && post.description.trim().startsWith(prefix);

    return !(post.type == 'general' && repeatsText);
  }

  bool get _hasDescription => post.description.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasTitle)
          Text(
            post.title,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 16.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: palette.title,
            ),
          ),
        if (_hasDescription) ...[
          const SizedBox(height: 6),
          ExpandableText(text: post.description, textColor: palette.label),
        ],
        if (!_hasTitle && !_hasDescription && !post.hasAnyMedia)
          Text(
            'Publicación sin contenido disponible.',
            style: TextStyle(fontSize: 14, color: palette.muted),
          ),
      ],
    );
  }
}
