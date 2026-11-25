import 'package:flutter/widgets.dart';

/// Fuera de la web no hay botón oficial: nunca se llama en móvil.
Widget buildGoogleWebButton({
  required bool signUp,
  required bool dark,
  required double width,
}) {
  return const SizedBox.shrink();
}
