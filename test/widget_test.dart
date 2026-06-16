// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_ena/main.dart';
import 'package:project_ena/screens/auth/register/welcome_screen.dart';

void main() {
  testWidgets('App inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialScreen: WelcomeScreen()));

    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
