/// Configuración de OAuth con Google.
///
/// Los Client IDs se crean en Google Cloud Console (APIs y servicios >
/// Credenciales) y se pasan al compilar:
///
///   flutter run \
///     --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com \
///     --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com
///
/// GOOGLE_SERVER_CLIENT_ID es el cliente tipo "Aplicación web": el backend lo
/// usa como audiencia (GOOGLE_CLIENT_IDS) para validar el id_token.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  /// Web Client ID de Google Cloud. No es secreto (va dentro de la app), así
  /// que puede quedar escrito aquí para no pasarlo en cada compilación.
  /// Un --dart-define=GOOGLE_SERVER_CLIENT_ID=... lo reemplaza.
  static const String _defaultServerClientId =
      '4976582749-5hinphr7n60krs2mp9niumhrdqnmqv0c.apps.googleusercontent.com';

  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: _defaultServerClientId,
  );

  /// Solo iOS/macOS (cliente tipo "iOS").
  static const String iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static bool get isConfigured => serverClientId.isNotEmpty;
}
