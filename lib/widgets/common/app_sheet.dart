import 'package:flutter/material.dart';

import 'package:connect_do/theme/brand.dart';

/// Igual que showModalBottomSheet, pero deja libre el espacio de los
/// botones del teléfono (barra de navegación). En Android reciente la app
/// se dibuja hasta el borde y la última opción de las hojas quedaba
/// debajo de esos botones (p. ej. "Agregar a mis stickers").
///
/// Usar SIEMPRE esta en lugar de showModalBottomSheet.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  ShapeBorder? shape,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    shape: shape,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder:
        (sheetContext) => SheetBottomInset(
          color:
              backgroundColor == null || backgroundColor.a == 0
                  ? null
                  : backgroundColor,
          child: builder(sheetContext),
        ),
  );
}

/// Agrega debajo de la hoja una franja del alto de la barra de navegación,
/// del mismo color que la hoja. Dentro, la hoja ya no ve ese margen (así,
/// las que tenían su propio SafeArea no lo duplican).
class SheetBottomInset extends StatelessWidget {
  final Widget child;

  /// Color de la franja; por defecto, el de las tarjetas (el de las hojas).
  final Color? color;

  const SheetBottomInset({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewPadding.bottom;
    if (inset <= 0) return child;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: MediaQuery(
            data: media
                .removePadding(removeBottom: true)
                .removeViewPadding(removeBottom: true),
            child: child,
          ),
        ),
        ColoredBox(
          color: color ?? AuthPalette.of(context).card,
          child: SizedBox(height: inset, width: double.infinity),
        ),
      ],
    );
  }
}
