import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

/// Botón oficial de Google Identity Services. En web es la única forma
/// permitida de iniciar sesión; el resultado llega por
/// GoogleSignIn.instance.authenticationEvents.
Widget buildGoogleWebButton({
  required bool signUp,
  required bool dark,
  required double width,
}) {
  return google_web.renderButton(
    configuration: google_web.GSIButtonConfiguration(
      type: google_web.GSIButtonType.standard,
      theme:
          dark
              ? google_web.GSIButtonTheme.filledBlack
              : google_web.GSIButtonTheme.outline,
      size: google_web.GSIButtonSize.large,
      text:
          signUp
              ? google_web.GSIButtonText.signupWith
              : google_web.GSIButtonText.continueWith,
      shape: google_web.GSIButtonShape.rectangular,
      logoAlignment: google_web.GSIButtonLogoAlignment.center,
      // Google limita el ancho a 400 px.
      minimumWidth: width.clamp(200, 400),
      locale: 'es',
    ),
  );
}
