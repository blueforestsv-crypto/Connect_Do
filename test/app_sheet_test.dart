import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/widgets/common/app_sheet.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, Widget content) async {
    // Teléfono con barra de navegación de 48 px lógicos (3 botones).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(bottom: 144);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => showAppSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => content,
                      ),
                  child: const Text('abrir'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  const screenHeight = 2400 / 3;
  const navBar = 48.0;

  testWidgets('la última opción queda encima de los botones del teléfono', (
    tester,
  ) async {
    await openSheet(
      tester,
      const Material(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Responder')),
            ListTile(title: Text('Agregar a mis stickers')),
          ],
        ),
      ),
    );
    final bottom = tester.getBottomLeft(find.text('Agregar a mis stickers')).dy;
    expect(bottom, lessThanOrEqualTo(screenHeight - navBar));
  });

  testWidgets('las hojas con su propio SafeArea no duplican el margen', (
    tester,
  ) async {
    await openSheet(
      tester,
      const Material(child: SafeArea(child: ListTile(title: Text('Última')))),
    );
    final tile = tester.getRect(find.byType(ListTile));
    // Justo encima de la barra: ni tapada ni con el doble de espacio.
    expect(tile.bottom, closeTo(screenHeight - navBar, 1));
  });
}
