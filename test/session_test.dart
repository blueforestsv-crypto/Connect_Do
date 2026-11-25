import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/services/auth_service.dart';

/// JWT de prueba que vence dentro de [inMinutes] (negativo = ya venció).
String _jwt(int inMinutes) {
  String part(Map<String, dynamic> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final exp =
      DateTime.now().add(Duration(minutes: inMinutes)).millisecondsSinceEpoch ~/
      1000;
  return '${part({'alg': 'HS256'})}.${part({'sub': 'ana', 'exp': exp})}.firma';
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  test('con el token vigente no llama al servidor', () async {
    await _prefs({'access_token': _jwt(25), 'refresh_token': 'r1'});
    var calls = 0;
    final mock = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });

    final ok = await http.runWithClient(
      AuthService.ensureFreshSession,
      () => mock,
    );

    expect(ok, isTrue);
    expect(calls, 0);
  });

  test('con el token vencido lo renueva y lo guarda', () async {
    final prefs = await _prefs({
      'access_token': _jwt(-10),
      'refresh_token': 'r1',
    });
    final fresh = _jwt(30);
    final mock = MockClient((request) async {
      expect(request.url.path, '/auth/refresh');
      expect(jsonDecode(request.body), {'refresh_token': 'r1'});
      return http.Response(jsonEncode({'access_token': fresh}), 200);
    });

    final ok = await http.runWithClient(
      AuthService.ensureFreshSession,
      () => mock,
    );

    expect(ok, isTrue);
    expect(prefs.getString('access_token'), fresh);
  });

  test('si el servidor rechaza la sesión devuelve false', () async {
    await _prefs({'access_token': _jwt(-10), 'refresh_token': 'viejo'});
    final mock = MockClient((_) async => http.Response('{}', 401));

    expect(
      await http.runWithClient(AuthService.ensureFreshSession, () => mock),
      isFalse,
    );
  });

  test('sin conexión devuelve null (no cierra la sesión)', () async {
    await _prefs({'access_token': _jwt(-10), 'refresh_token': 'r1'});
    final mock = MockClient((_) async => throw http.ClientException('sin red'));

    expect(
      await http.runWithClient(AuthService.ensureFreshSession, () => mock),
      isNull,
    );
  });

  test('"Cerrar sesión" recuerda la cuenta para "Continuar como"', () async {
    final prefs = await _prefs({
      'access_token': _jwt(20),
      'refresh_token': 'r1',
      'sesion_activa': true,
      'usuario_actual': jsonEncode({'email': 'ana@gmail.com'}),
    });
    final calls = <String>[];
    final mock = MockClient((request) async {
      calls.add(request.url.path);
      return http.Response('', 204);
    });

    await http.runWithClient(
      () => AuthService.logout(forgetUser: false),
      () => mock,
    );

    expect(prefs.getBool('sesion_activa'), isFalse);
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), 'r1');
    expect(prefs.getString('usuario_actual'), isNotNull);
    expect(calls, isNot(contains('/auth/logout')));
  });

  test('"Usar otra cuenta" / olvidar revoca la sesión', () async {
    final prefs = await _prefs({
      'access_token': _jwt(20),
      'refresh_token': 'r1',
      'usuario_actual': jsonEncode({'email': 'ana@gmail.com'}),
    });
    final calls = <String>[];
    final mock = MockClient((request) async {
      calls.add(request.url.path);
      return http.Response('', 204);
    });

    await http.runWithClient(AuthService.logout, () => mock);

    expect(calls, contains('/auth/logout'));
    expect(prefs.getString('refresh_token'), isNull);
    expect(prefs.getString('usuario_actual'), isNull);
  });
}
