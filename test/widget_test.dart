// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/screens/auth/register/welcome_screen.dart';

void main() {
  testWidgets('La pantalla de bienvenida muestra la marca y las acciones', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));

    await tester.pump();

    expect(find.text('Oportunidades reales'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Ya tengo cuenta'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    // La pantalla sigue montada y funcional.
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
