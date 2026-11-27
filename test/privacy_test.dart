import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/settings/privacy_screen.dart';
import 'package:connect_do/screens/settings/sessions_screen.dart';
import 'package:connect_do/services/privacy_service.dart';

String _fakeToken(String jti) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'sub': 'ana', 'jti': jti})}.firma';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'refresh_token': _fakeToken('mio'),
    });
  });

  test('reconoce la sesión de este teléfono', () {
    expect(PrivacyService.jtiOf(_fakeToken('abc123')), 'abc123');
    expect(PrivacyService.jtiOf('no-es-un-token'), isNull);
  });

  testWidgets('cambiar quién puede escribirme', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final sent = <Map<String, dynamic>>[];
    final mock = MockClient((request) async {
      if (request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sent.add(body);
        return http.Response(
          jsonEncode({
            'message_privacy': body['message_privacy'] ?? 'contacts',
            'story_privacy': 'contacts',
            'show_presence': true,
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'message_privacy': 'contacts',
          'story_privacy': 'contacts',
          'show_presence': true,
        }),
        200,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cualquier persona'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent, [
      {'message_privacy': 'everyone'},
    ]);
    expect(find.text('Sesiones activas'), findsOneWidget);
    expect(find.text('Descargar mis datos'), findsOneWidget);
  });

  testWidgets('sesiones: la mía primero y sin botón de cerrar', (tester) async {
    final mock = MockClient((request) async {
      return http.Response(
        jsonEncode([
          {
            'id': '1',
            'jti': 'otro',
            'device_name': 'Navegador web',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'id': '2',
            'jti': 'mio',
            'device_name': 'Teléfono Android',
            'created_at': DateTime.now().toIso8601String(),
          },
        ]),
        200,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: SessionsScreen()));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('Este dispositivo'), findsOneWidget);
    final mine = tester.getTopLeft(find.text('Teléfono Android')).dy;
    final web = tester.getTopLeft(find.text('Navegador web')).dy;
    expect(mine, lessThan(web));
    // Solo la otra sesión tiene botón para cerrarla.
    expect(find.byTooltip('Cerrar esta sesión'), findsOneWidget);
    expect(find.text('Cerrar todas las demás'), findsOneWidget);
  });
}
