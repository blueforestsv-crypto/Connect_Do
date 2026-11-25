import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:connect_do/theme/brand.dart';

/// Casillas para un código numérico. Un solo TextField invisible encima
/// permite pegar el código completo y el autocompletado del sistema.
class CodeInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final bool hasError;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  const CodeInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = false,
    this.onCompleted,
  });

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return GestureDetector(
      onTap: _focus.requestFocus,
      child: Stack(
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              final text = value.text;

              return Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0)
                      SizedBox(width: i == widget.length ~/ 2 ? 14 : 8),
                    Expanded(child: _box(palette, text, i)),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (value.length == widget.length) {
                    widget.onCompleted?.call(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(AuthPalette palette, String text, int index) {
    final digit = index < text.length ? text[index] : '';
    final active =
        _focus.hasFocus &&
        (index == text.length ||
            (index == widget.length - 1 && text.length == widget.length));

    final border =
        widget.hasError
            ? Brand.danger
            : active
            ? Brand.blue
            : digit.isNotEmpty
            ? Brand.green.withValues(alpha: 0.6)
            : palette.fieldBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? palette.card : palette.fieldFill,
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        border: Border.all(
          color: border,
          width: active || widget.hasError ? 1.8 : 1,
        ),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: palette.title,
        ),
      ),
    );
  }
}
