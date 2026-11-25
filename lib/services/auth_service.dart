import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/services/push_service.dart';
import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/core/api/google_auth_config.dart';
import 'package:connect_do/utils/academic_options.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  const AuthService._();

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': cleanEmail, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw AuthException(
        _errorDetail(response, 'No se pudo iniciar sesión. Intenta de nuevo.'),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final accessToken = data['access_token']?.toString() ?? '';
    final refreshToken = data['refresh_token']?.toString() ?? '';

    if (accessToken.isEmpty) {
      throw Exception('El backend no devolvió access_token.');
    }

    await _saveSession(accessToken: accessToken, refreshToken: refreshToken);

    await _saveCurrentUser(accessToken);
    await _syncCurrentProfileFromBackend();
  }

  // =====================================================
  // REGISTRO CORTO: CREA LA CUENTA E INICIA SESIÓN
  // =====================================================
  /// Crea la cuenta en el backend, inicia sesión y deja la verificación de
  /// correo pendiente. La contraseña no se guarda en el dispositivo.
  static Future<void> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? university,
  }) async {
    final cleanEmail = email.trim();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': cleanEmail,
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
      }),
    );

    if (response.statusCode == 409) {
      throw const AuthException(
        'Ya existe una cuenta con este correo. Inicia sesión.',
      );
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AuthException(
        _errorDetail(response, 'No se pudo crear la cuenta.'),
      );
    }

    // Limpia datos de un usuario anterior antes de iniciar sesión.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario_actual');

    await login(email: cleanEmail, password: password);

    await prefs.setBool(pendingVerificationKey, true);

    if (university != null && university.isNotEmpty) {
      await _mergeLocalUserData({'university': university});
      await _syncProfileWithBackend({'university': university});
    }
  }

  // =====================================================
  // OAUTH CON GOOGLE
  // =====================================================
  /// El plugin solo admite UNA llamada a initialize(): si se repite (por
  /// ejemplo, tras un primer intento fallido) lanza "init() has already been
  /// called". Por eso se guarda el Future y se reutiliza siempre.
  static Future<void>? _googleInit;

  static Future<void> _ensureGoogleInitialized() {
    if (!GoogleAuthConfig.isConfigured) {
      return Future.error(
        const AuthException(
          'El inicio con Google aún no está configurado en esta versión.',
        ),
      );
    }

    return _googleInit ??= _initializeGoogle();
  }

  static Future<void> _initializeGoogle() {
    final isApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    // En web el ID va como clientId (serverClientId no existe allí).
    // En Android/iOS va como serverClientId, para que el id_token sea para
    // el backend.
    if (kIsWeb) {
      return GoogleSignIn.instance.initialize(
        clientId: GoogleAuthConfig.serverClientId,
      );
    }

    return GoogleSignIn.instance.initialize(
      serverClientId: GoogleAuthConfig.serverClientId,
      clientId:
          isApple && GoogleAuthConfig.iosClientId.isNotEmpty
              ? GoogleAuthConfig.iosClientId
              : null,
    );
  }

  /// En web el inicio de sesión ocurre con el botón oficial de Google; la app
  /// debe preparar el plugin antes de dibujarlo y escuchar estos eventos.
  static Future<void> prepareGoogleSignIn() => _ensureGoogleInitialized();

  static Stream<GoogleSignInAuthenticationEvent> get googleAuthEvents =>
      GoogleSignIn.instance.authenticationEvents;

  /// Inicia sesión o crea la cuenta con Google (OAuth 2.0 / OpenID Connect)
  /// en Android/iOS, abriendo el selector de cuentas.
  ///
  /// Devuelve `true` si la cuenta es nueva, `false` si ya existía y `null`
  /// si la persona canceló el selector de cuentas.
  static Future<bool?> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthException(
        'Este dispositivo no permite iniciar sesión con Google.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (e) {
      debugPrint('Google Sign-In falló: ${e.code} ${e.description}');

      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          // En Android, Google también responde "canceled" cuando rechaza la
          // configuración (p. ej. "[16] Account reauth failed" o "[28444]
          // Developer console is not set up correctly"). Solo es una
          // cancelación real si la persona cerró el selector.
          final detail = (e.description ?? '').trim();
          if (detail.isEmpty ||
              RegExp(r'cancel', caseSensitive: false).hasMatch(detail) &&
                  !RegExp(r'\[\d+\]').hasMatch(detail)) {
            return null;
          }
          throw AuthException(
            'Google rechazó el inicio de sesión: $detail. '
            'Revisa el cliente Android (paquete y SHA-1) y la pantalla de '
            'consentimiento en Google Cloud.',
          );
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          // Casi siempre: falta el cliente Android en Google Cloud o el
          // SHA-1 / nombre de paquete no coinciden.
          throw const AuthException(
            'Google no reconoce esta versión de la app. '
            'Revisa el cliente Android (paquete y SHA-1) en Google Cloud.',
          );
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const AuthException(
            'Este teléfono no tiene una cuenta de Google disponible.',
          );
        default:
          throw AuthException(
            'No se pudo conectar con Google (${e.code.name}).',
          );
      }
    }

    return completeGoogleSignIn(account);
  }

  /// Envía el id_token de Google al backend y guarda la sesión.
  /// Lo usan tanto el flujo móvil como el botón oficial de Google en web.
  /// Devuelve `true` si la cuenta es nueva.
  static Future<bool> completeGoogleSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google no devolvió un token de identidad.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode != 200) {
      await GoogleSignIn.instance.signOut();
      throw AuthException(
        _errorDetail(response, 'No se pudo iniciar sesión con Google.'),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token']?.toString() ?? '';
    final isNewUser = data['is_new_user'] == true;

    if (accessToken.isEmpty) {
      throw const AuthException('El backend no devolvió access_token.');
    }

    await _saveSession(
      accessToken: accessToken,
      refreshToken: data['refresh_token']?.toString() ?? '',
    );
    await _saveCurrentUser(accessToken);
    await _syncCurrentProfileFromBackend();

    final prefs = await SharedPreferences.getInstance();
    // Google ya verificó el correo.
    await prefs.setBool(pendingVerificationKey, false);

    final extra = <String, dynamic>{};

    final photoUrl = account.photoUrl ?? '';
    final currentJson = prefs.getString('usuario_actual') ?? '';
    final current =
        currentJson.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(currentJson) as Map<String, dynamic>;

    if (photoUrl.isNotEmpty &&
        (current['google_photo_url']?.toString() ?? '').isEmpty) {
      extra['google_photo_url'] = photoUrl;
    }

    if (isNewUser) {
      final university = AcademicOptions.universityFromEmail(account.email);
      if (university != null) {
        extra['university'] = university;
        await _syncProfileWithBackend({'university': university});
      }
    }

    if (extra.isNotEmpty) await _mergeLocalUserData(extra);

    return isNewUser;
  }

  // =====================================================
  // VERIFICACIÓN DE CORREO CON CÓDIGO
  // =====================================================
  static const String pendingVerificationKey = 'verificacion_pendiente';

  /// Pide al backend un código nuevo. Devuelve el código solo cuando el
  /// servidor corre en modo development (no hay proveedor de correo).
  static Future<String?> requestVerificationCode(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/email-verification/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );

    if (response.statusCode != 200) {
      throw AuthException(
        _errorDetail(response, 'No se pudo enviar el código.'),
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final debugCode = data['debug_code']?.toString() ?? '';

    return debugCode.isEmpty ? null : debugCode;
  }

  static Future<void> confirmVerificationCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    if (token.isEmpty) {
      throw const AuthException('Tu sesión expiró. Inicia sesión de nuevo.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/email-verification/confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode != 200) {
      throw AuthException(
        _errorDetail(response, 'El código es incorrecto o ha vencido.'),
      );
    }

    await prefs.setBool(pendingVerificationKey, false);
  }

  // =====================================================
  // RECUPERAR / CAMBIAR CONTRASEÑA Y CORREO
  // =====================================================

  /// Envía un código para restablecer la contraseña. Devuelve el código solo
  /// si el servidor está en development sin proveedor de correo.
  static Future<String?> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/password-reset/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    final data = _decodeOrThrow(response, 'No se pudo enviar el código.');
    final debugCode = data['debug_code']?.toString() ?? '';
    return debugCode.isEmpty ? null : debugCode;
  }

  static Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/password-reset/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'code': code,
        'new_password': newPassword,
      }),
    );
    _decodeOrThrow(response, 'No se pudo cambiar la contraseña.');
  }

  /// [currentPassword] puede ir vacío si la cuenta se creó con Google y
  /// todavía no tiene contraseña.
  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/password/change'),
      headers: await _authHeaders(),
      body: jsonEncode({
        if (currentPassword.isNotEmpty) 'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    final data = _decodeOrThrow(response, 'No se pudo cambiar la contraseña.');
    return data['message']?.toString() ?? 'Contraseña actualizada.';
  }

  static Future<String?> requestEmailChange({
    required String newEmail,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/email-change/request'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'new_email': newEmail.trim(),
        if (password.isNotEmpty) 'password': password,
      }),
    );
    final data = _decodeOrThrow(response, 'No se pudo enviar el código.');
    final debugCode = data['debug_code']?.toString() ?? '';
    return debugCode.isEmpty ? null : debugCode;
  }

  /// Confirma el correo nuevo y lo guarda también en el teléfono.
  static Future<void> confirmEmailChange(String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/email-change/confirm'),
      headers: await _authHeaders(),
      body: jsonEncode({'code': code}),
    );
    final data = _decodeOrThrow(response, 'No se pudo cambiar el correo.');
    final email = data['email']?.toString() ?? '';
    if (email.isNotEmpty) await _mergeLocalUserData({'email': email});
  }

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (token.isEmpty) {
      throw const AuthException('Tu sesión expiró. Inicia sesión de nuevo.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeOrThrow(
    http.Response response,
    String fallback,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(_errorDetail(response, fallback));
    }
    try {
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _errorDetail(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    } catch (_) {}

    return fallback;
  }

  static Future<void> _saveSession({
    required String accessToken,
    String refreshToken = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('access_token', accessToken);

    if (refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    } else {
      await prefs.remove('refresh_token');
    }

    await prefs.setBool('sesion_activa', true);
  }

  static Future<void> _saveCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) return;

    final userData = jsonDecode(response.body) as Map<String, dynamic>;

    final backendUserData = <String, dynamic>{
      'id': userData['id']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'firstName': userData['first_name']?.toString() ?? '',
      'lastName': userData['last_name']?.toString() ?? '',
      'first_name': userData['first_name']?.toString() ?? '',
      'last_name': userData['last_name']?.toString() ?? '',
    };

    await _mergeLocalUserData(backendUserData, preserveOnlyIfSameUser: true);
  }

  static Future<void> _mergeLocalUserData(
    Map<String, dynamic> newData, {
    bool preserveOnlyIfSameUser = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final existingUserJson = prefs.getString('usuario_actual');

    Map<String, dynamic> existingUserData = {};

    if (existingUserJson != null && existingUserJson.isNotEmpty) {
      try {
        existingUserData = jsonDecode(existingUserJson) as Map<String, dynamic>;
      } catch (_) {
        existingUserData = {};
      }
    }

    final existingId = existingUserData['id']?.toString() ?? '';
    final existingEmail = existingUserData['email']?.toString() ?? '';

    final newId = newData['id']?.toString() ?? '';
    final newEmail = newData['email']?.toString() ?? '';

    final sameUser =
        (existingId.isNotEmpty && newId.isNotEmpty && existingId == newId) ||
        (existingEmail.isNotEmpty &&
            newEmail.isNotEmpty &&
            existingEmail.toLowerCase() == newEmail.toLowerCase());

    final Map<String, dynamic> mergedUserData;

    if (preserveOnlyIfSameUser && !sameUser) {
      mergedUserData = <String, dynamic>{
        ...newData,
        'profile_image_base64':
            newData['profile_image_base64']?.toString() ?? '',
        'profile_image_path': newData['profile_image_path']?.toString() ?? '',
        'profile_image_name': newData['profile_image_name']?.toString() ?? '',
        'google_photo_url': newData['google_photo_url']?.toString() ?? '',

        // CV local / demo
        'cv_url': newData['cv_url']?.toString() ?? '',
        'cv_file_base64': newData['cv_file_base64']?.toString() ?? '',
        'cv_file_name': newData['cv_file_name']?.toString() ?? '',
        'cv_file_path': newData['cv_file_path']?.toString() ?? '',
        'cv_path': newData['cv_path']?.toString() ?? '',
        'cv_file_size': newData['cv_file_size'] ?? 0,

        'career': newData['career']?.toString() ?? '',
        'cycle': newData['cycle']?.toString() ?? '',
        'phone': newData['phone']?.toString() ?? '',
        'description': newData['description']?.toString() ?? '',
        'portfolio_link': newData['portfolio_link']?.toString() ?? '',
        'skills': newData['skills'] ?? [],
      };
    } else {
      mergedUserData = <String, dynamic>{...existingUserData, ...newData};

      // Blindaje: si newData no trae CV, conservar el CV anterior.
      mergedUserData['cv_url'] =
          newData['cv_url']?.toString().isNotEmpty == true
              ? newData['cv_url']?.toString()
              : existingUserData['cv_url']?.toString() ?? '';

      mergedUserData['cv_file_base64'] =
          newData['cv_file_base64']?.toString().isNotEmpty == true
              ? newData['cv_file_base64']?.toString()
              : existingUserData['cv_file_base64']?.toString() ?? '';

      mergedUserData['cv_file_name'] =
          newData['cv_file_name']?.toString().isNotEmpty == true
              ? newData['cv_file_name']?.toString()
              : existingUserData['cv_file_name']?.toString() ?? '';

      mergedUserData['cv_file_path'] =
          newData['cv_file_path']?.toString().isNotEmpty == true
              ? newData['cv_file_path']?.toString()
              : existingUserData['cv_file_path']?.toString() ?? '';

      mergedUserData['cv_path'] =
          newData['cv_path']?.toString().isNotEmpty == true
              ? newData['cv_path']?.toString()
              : existingUserData['cv_path']?.toString() ?? '';

      mergedUserData['cv_file_size'] =
          newData['cv_file_size'] ?? existingUserData['cv_file_size'] ?? 0;
    }

    await prefs.setString('usuario_actual', jsonEncode(mergedUserData));
  }

  static Future<void> _syncCurrentProfileFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      if (accessToken.isEmpty) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profiles/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200) return;

      final profileData = jsonDecode(response.body) as Map<String, dynamic>;

      final currentUserJson = prefs.getString('usuario_actual');

      Map<String, dynamic> currentUser = {};

      if (currentUserJson != null && currentUserJson.isNotEmpty) {
        try {
          currentUser = jsonDecode(currentUserJson) as Map<String, dynamic>;
        } catch (_) {
          currentUser = {};
        }
      }

      // Guardamos backup local antes de actualizar desde backend.
      final localCvUrl = currentUser['cv_url']?.toString() ?? '';
      final localCvFileBase64 = currentUser['cv_file_base64']?.toString() ?? '';
      final localCvFileName = currentUser['cv_file_name']?.toString() ?? '';
      final localCvFilePath = currentUser['cv_file_path']?.toString() ?? '';
      final localCvPath = currentUser['cv_path']?.toString() ?? '';
      final localCvFileSize = currentUser['cv_file_size'] ?? 0;

      currentUser['phone'] = profileData['phone']?.toString() ?? '';
      currentUser['university'] = profileData['university']?.toString() ?? '';
      currentUser['level'] = profileData['academic_level']?.toString() ?? '';
      currentUser['career'] = profileData['career']?.toString() ?? '';
      currentUser['cycle'] = profileData['academic_cycle']?.toString() ?? '';
      currentUser['description'] = profileData['bio']?.toString() ?? '';
      currentUser['portfolio_link'] =
          profileData['portfolio_url']?.toString() ?? '';

      currentUser['profile_image_base64'] =
          profileData['profile_image_base64']?.toString() ?? '';

      currentUser['google_photo_url'] =
          profileData['avatar_url']?.toString() ?? '';

      // CV: si backend no devuelve CV, conservar lo local.
      final backendCvUrl = profileData['cv_url']?.toString() ?? '';

      currentUser['cv_url'] =
          backendCvUrl.isNotEmpty ? backendCvUrl : localCvUrl;

      currentUser['cv_file_base64'] = localCvFileBase64;
      currentUser['cv_file_name'] = localCvFileName;
      currentUser['cv_file_path'] = localCvFilePath;
      currentUser['cv_path'] = localCvPath;
      currentUser['cv_file_size'] = localCvFileSize;

      await prefs.setString('usuario_actual', jsonEncode(currentUser));
    } catch (_) {
      // No rompemos login por un fallo de perfil.
    }
  }

  static Future<void> _syncProfileWithBackend(
    Map<String, dynamic> userData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token') ?? '';

      if (accessToken.isEmpty) return;

      final body = <String, dynamic>{
        'phone': userData['phone']?.toString(),
        'university': userData['university']?.toString(),
        'academic_level': userData['level']?.toString(),
        'career': userData['career']?.toString(),
        'academic_cycle': userData['cycle']?.toString(),
        'bio': userData['description']?.toString(),
        'portfolio_url': userData['portfolio_link']?.toString(),
        'profile_image_base64': userData['profile_image_base64']?.toString(),

        // Por ahora el backend maneja cv_url como referencia/nombre demo.
        'cv_url':
            userData['cv_url']?.toString().isNotEmpty == true
                ? userData['cv_url']?.toString()
                : userData['cv_file_name']?.toString(),
      };

      body.removeWhere((key, value) {
        if (value == null) return true;
        if (value is String && value.trim().isEmpty) return true;
        return false;
      });

      if (body.isEmpty) return;

      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/profiles/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
    } catch (_) {
      // No rompemos el registro si el perfil no se pudo sincronizar.
    }
  }

  /// Trae del servidor los datos del perfil (teléfono, carrera, foto...) y
  /// los guarda en el teléfono. No falla si no hay conexión.
  static Future<void> refreshProfileFromBackend() =>
      _syncCurrentProfileFromBackend();

  /// Cierra la sesión. Con [forgetUser] en false se conserva la tarjeta de
  /// "Hola de nuevo" en el login (sin token, se pedirá la contraseña).
  static Future<void> logout({bool forgetUser = true}) async {
    final prefs = await SharedPreferences.getInstance();

    // Este teléfono deja de recibir push de la cuenta (antes de borrar tokens).
    await PushService.unregisterDevice();

    // Revoca la sesión en el servidor (mejor esfuerzo: sin red, igual sale).
    final refreshToken = prefs.getString('refresh_token') ?? '';
    if (refreshToken.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.setBool('sesion_activa', false);
    await prefs.remove(pendingVerificationKey);

    // Para que la próxima vez se muestre el selector de cuentas de Google.
    if (_googleInit != null) {
      try {
        await _googleInit;
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }

    // Para evitar que aparezca usuario anterior en login rápido.
    if (forgetUser) await prefs.remove('usuario_actual');
  }
}
