import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final Color textColor;
  final int maxLines;
  final double fontSize;

  const ExpandableText({
    super.key,
    required this.text,
    required this.textColor,
    this.maxLines = 4,
    this.fontSize = 15,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
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
