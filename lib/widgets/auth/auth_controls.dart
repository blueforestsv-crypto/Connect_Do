import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/theme/brand.dart';

// =====================================================
// CAMPO DE TEXTO
// =====================================================

/// Campo con etiqueta arriba, ícono que se ilumina al enfocar y error en línea.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final String? errorText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Widget? trailingLabel;
  final String? prefixText;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.trailingLabel,
    this.prefixText,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;

    final multiline = widget.maxLines > 1;

    final iconColor =
        hasError
            ? Brand.danger
            : focused
            ? Brand.blue
            : palette.muted;

    Widget? trailing = widget.trailingLabel;
    if (trailing == null && widget.maxLength != null) {
      // Contador de caracteres junto a la etiqueta.
      trailing = ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder:
            (context, value, _) => Text(
              '${value.text.characters.length}/${widget.maxLength}',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 12,
                color: palette.muted,
              ),
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthFieldLabel(widget.label, trailing: trailing),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: multiline ? null : Brand.fieldHeight,
          padding:
              multiline
                  ? const EdgeInsets.symmetric(vertical: 14)
                  : EdgeInsets.zero,
          decoration: authFieldDecoration(
            palette,
            focused: focused,
            hasError: hasError,
          ),
          child: Row(
            crossAxisAlignment:
                multiline
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 14),
              Padding(
                padding: EdgeInsets.only(top: multiline ? 1 : 0),
                child: Icon(widget.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 10),
              if (widget.prefixText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    widget.prefixText!,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.label,
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  obscureText: widget.isPassword && _obscured,
                  autocorrect: !widget.isPassword,
                  enableSuggestions: !widget.isPassword,
                  maxLines: widget.isPassword ? 1 : widget.maxLines,
                  minLines: multiline ? 3 : 1,
                  maxLength: widget.maxLength,
                  inputFormatters: widget.inputFormatters,
                  textCapitalization:
                      widget.keyboardType == TextInputType.name
                          ? TextCapitalization.words
                          : multiline
                          ? TextCapitalization.sentences
                          : TextCapitalization.none,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: Brand.blue,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 15,
                    color: palette.title,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 15,
                      color: palette.muted,
                    ),
                  ),
                ),
              ),
              if (widget.isPassword)
                IconButton(
                  tooltip:
                      _obscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(
                    _obscured
                        ? PhosphorIconsRegular.eyeSlash
                        : PhosphorIconsRegular.eye,
                    size: 20,
                    color: palette.muted,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child:
              hasError
                  ? Padding(
                    padding: const EdgeInsets.only(top: 6, left: 2),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.warningCircle,
                          size: 15,
                          color: Brand.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.errorText!,
                            style: const TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 12.5,
                              color: Brand.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// =====================================================
// PIEZAS COMPARTIDAS DE LOS CAMPOS
// =====================================================
class AuthFieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AuthFieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: palette.label,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

BoxDecoration authFieldDecoration(
  AuthPalette palette, {
  bool focused = false,
  bool hasError = false,
}) {
  return BoxDecoration(
    color: focused ? palette.card : palette.fieldFill,
    borderRadius: BorderRadius.circular(Brand.radiusMd),
    border: Border.all(
      color:
          hasError
              ? Brand.danger
              : focused
              ? Brand.blue
              : palette.fieldBorder,
      width: focused || hasError ? 1.6 : 1,
    ),
    boxShadow:
        focused && !hasError
            ? [
              BoxShadow(
                color: Brand.blue.withValues(alpha: 0.12),
                spreadRadius: 4,
              ),
            ]
            : null,
  );
}

// =====================================================
// LISTA DESPLEGABLE
// =====================================================
class AuthDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String)? itemLabel;

  const AuthDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    // Si el valor guardado ya no existe en la lista, se muestra vacío.
    final safeValue = items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthFieldLabel(label),
        Container(
          height: Brand.fieldHeight,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: authFieldDecoration(palette),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: safeValue == null ? palette.muted : Brand.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeValue,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(Brand.radiusMd),
                    dropdownColor: palette.card,
                    menuMaxHeight: 360,
                    icon: Icon(
                      PhosphorIconsRegular.caretDown,
                      size: 18,
                      color: palette.muted,
                    ),
                    hint: Text(
                      hint,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 15,
                        color: palette.muted,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 15,
                      color: palette.title,
                    ),
                    items: [
                      for (final item in items)
                        DropdownMenuItem<String>(
                          value: item,
                          child: Text(
                            itemLabel?.call(item) ?? item,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// BOTÓN SECUNDARIO (CONTORNO)
// =====================================================
class OutlineActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const OutlineActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return SizedBox(
      height: Brand.fieldHeight + 2,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.card,
          foregroundColor: palette.title,
          side: BorderSide(color: palette.fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            // En pantallas angostas el texto se recorta en vez de desbordar.
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// BOTÓN PRINCIPAL CON DEGRADADO DE MARCA
// =====================================================
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? trailingIcon;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.trailingIcon = PhosphorIconsRegular.arrowRight,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || isLoading ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Brand.gradient,
          borderRadius: BorderRadius.circular(Brand.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Brand.blue.withValues(alpha: enabled ? 0.30 : 0),
              blurRadius: 18,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
            onTap:
                enabled
                    ? () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    }
                    : null,
            child: SizedBox(
              height: Brand.fieldHeight + 2,
              child: Center(
                child:
                    isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text,
                              style: const TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: Colors.white,
                              ),
                            ),
                            if (trailingIcon != null) ...[
                              const SizedBox(width: 8),
                              Icon(trailingIcon, color: Colors.white, size: 18),
                            ],
                          ],
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// ENLACE DE TEXTO ("¿No tienes cuenta? Regístrate")
// =====================================================
class AuthFooterLink extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback? onTap;

  const AuthFooterLink({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Text.rich(
          TextSpan(
            text: '$question ',
            style: TextStyle(color: palette.body),
            children: [
              TextSpan(
                text: action,
                style: const TextStyle(
                  color: Brand.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          style: const TextStyle(fontFamily: Brand.displayFont, fontSize: 14.5),
        ),
      ),
    );
  }
}

// =====================================================
// MENSAJES FLOTANTES
// =====================================================
enum AuthMessageType { error, success, info }

void showAuthMessage(
  BuildContext context,
  String message, {
  AuthMessageType type = AuthMessageType.error,
}) {
  final (color, icon) = switch (type) {
    AuthMessageType.error => (Brand.danger, PhosphorIconsRegular.warningCircle),
    AuthMessageType.success => (
      Brand.success,
      PhosphorIconsRegular.checkCircle,
    ),
    AuthMessageType.info => (
      const Color(0xFF1E293B),
      PhosphorIconsRegular.sparkle,
    ),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusMd),
        ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: Brand.displayFont,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
