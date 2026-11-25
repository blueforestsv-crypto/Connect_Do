import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/screens/stories/new_story_screen.dart';

// PNG de 1x1 px.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('la descripción queda abajo, sobre el teclado', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    // Teclado abierto: 300 px lógicos.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: NewStoryScreen(initialImage: _png)),
    );
    await tester.pump();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final field = tester.getRect(find.byType(TextField));
    final title = tester.getRect(find.text('Nueva historia'));

    // Justo encima del teclado (780 - 300 = 480 de alto útil).
    expect(field.bottom, lessThanOrEqualTo(screen.height - 300));
    expect(field.bottom, greaterThan(screen.height - 300 - 80));
    // Y debajo de la foto, no arriba de la pantalla.
    expect(field.top, greaterThan(title.bottom + 100));
  });
}
