import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:connect_do/screens/account/forgot_password_screen.dart';

void main() {
  testWidgets('recuperar contraseña: correo → código → contraseña nueva', (
    tester,
  ) async {
    final calls = <String, Map<String, dynamic>>{};

    final mock = MockClient((request) async {
      calls[request.url.path] =
          jsonDecode(request.body) as Map<String, dynamic>;

      if (request.url.path == '/auth/password-reset/request') {
        return http.Response(
          jsonEncode({'message': 'ok', 'debug_code': '123456'}),
          200,
        );
      }
      return http.Response(jsonEncode({'message': 'listo'}), 200);
    });

    String? returnedEmail;

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      returnedEmail = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => const ForgotPasswordScreen(
                                initialEmail: 'ana@gmail.com',
                              ),
                        ),
                      );
                    },
                    child: const Text('abrir'),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Paso 1: el correo ya viene escrito.
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();
      expect(calls['/auth/password-reset/request'], {'email': 'ana@gmail.com'});
      expect(find.text('Crea una contraseña nueva'), findsOneWidget);

      // Paso 2: código + contraseña nueva.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'NuevaClave2027');
      await tester.pump();
      await tester.ensureVisible(find.text('Cambiar contraseña'));
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }, () => mock);

    expect(calls['/auth/password-reset/confirm'], {
      'email': 'ana@gmail.com',
      'code': '123456',
      'new_password': 'NuevaClave2027',
    });
    expect(returnedEmail, 'ana@gmail.com');
  });

  testWidgets('recuperar contraseña: valida la contraseña corta', (
    tester,
  ) async {
    final mock = MockClient(
      (request) async => http.Response(jsonEncode({'message': 'ok'}), 200),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: 'ana@gmail.com'),
        ),
      );
      await tester.tap(find.text('Enviar código'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'corta');
      await tester.ensureVisible(find.text('Cambiar contraseña'));
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pump();

      expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
    }, () => mock);
  });
}
