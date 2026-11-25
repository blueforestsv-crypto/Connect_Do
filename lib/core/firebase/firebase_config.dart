import 'package:firebase_core/firebase_core.dart';

/// Datos PÚBLICOS de la app Android en Firebase (no son secretos: son los
/// mismos que trae google-services.json). Se copian de la consola de
/// Firebase → Configuración del proyecto → Tus apps → app Android.
///
/// Mientras estén vacíos, la app funciona igual pero sin notificaciones push.
class FirebaseConfig {
  const FirebaseConfig._();

  /// "Clave de API web" / current_key.
  static const String apiKey = '';

  /// "ID de la app", empieza con 1:...:android:...
  static const String appId = '';

  /// "Número del proyecto" (Project number).
  static const String messagingSenderId = '';

  /// "ID del proyecto" (Project ID).
  static const String projectId = '';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
  );
}
