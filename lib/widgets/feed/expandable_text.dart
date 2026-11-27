import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/screens/search/hashtag_screen.dart';
import 'package:connect_do/theme/brand.dart';

/// Texto que se corta con "Leer más" y donde los #hashtags y las
/// @menciones se pueden tocar.
class ExpandableText extends StatefulWidget {
  final String text;
  final Color textColor;
  final int maxLines;
  final double fontSize;

  /// Personas mencionadas: [{id, name}] (vienen del servidor).
  final List<Map<String, String>> mentions;

  const ExpandableText({
    super.key,
    required this.text,
    required this.textColor,
    this.maxLines = 4,
    this.fontSize = 15,
    this.mentions = const [],
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = buildRichSpans(
      context,
      widget.text,
      mentions: widget.mentions,
      recognizers: _recognizers,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: spans),
          style: TextStyle(
            fontSize: widget.fontSize,
            height: 1.5,
            color: widget.textColor,
          ),
          maxLines: _expanded ? null : widget.maxLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 200)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Mostrar menos' : 'Leer más',
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final _hashtag = RegExp(r'#[\wáéíóúüñÁÉÍÓÚÜÑ]{2,40}');

/// Divide [text] en partes normales, #hashtags y @menciones (solo las que
/// el servidor confirmó en [mentions]). Los [recognizers] los libera quien
/// llama.
List<InlineSpan> buildRichSpans(
  BuildContext context,
  String text, {
  List<Map<String, String>> mentions = const [],
  required List<TapGestureRecognizer> recognizers,
}) {
  const linkStyle = TextStyle(color: Brand.blue, fontWeight: FontWeight.w600);

  // Posiciones de cada mención "@Nombre Apellido" en el texto.
  final marks = <({int start, int end, String? userId, String? tag})>[];
  for (final mention in mentions) {
    final name = mention['name'] ?? '';
    if (name.isEmpty) continue;
    var from = 0;
    while (true) {
      final index = text.indexOf('@$name', from);
      if (index < 0) break;
      marks.add((
        start: index,
        end: index + name.length + 1,
        userId: mention['id'],
        tag: null,
      ));
      from = index + name.length + 1;
    }
  }
  for (final match in _hashtag.allMatches(text)) {
    final overlaps = marks.any(
      (m) => match.start < m.end && match.end > m.start,
    );
    if (!overlaps) {
      marks.add((
        start: match.start,
        end: match.end,
        userId: null,
        tag: match.group(0),
      ));
    }
  }
  marks.sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final mark in marks) {
    if (mark.start < cursor) continue;
    if (mark.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, mark.start)));
    }
    final recognizer =
        TapGestureRecognizer()
          ..onTap = () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        mark.userId != null
                            ? UserProfileScreen(userId: mark.userId!)
                            : HashtagScreen(tag: mark.tag!),
              ),
            );
          };
    recognizers.add(recognizer);
    spans.add(
      TextSpan(
        text: text.substring(mark.start, mark.end),
        style: linkStyle,
        recognizer: recognizer,
      ),
    );
    cursor = mark.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}
