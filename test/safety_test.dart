import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/widgets/auth/terms_widgets.dart';
import 'package:connect_do/widgets/safety/report_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'token'});
  });

  testWidgets('reportar envía el motivo elegido', (tester) async {
    Map<String, dynamic>? sent;
    final mock = MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'id': 'r1'}), 201);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => showReportSheet(
                          context,
                          targetType: 'publication',
                          targetId: 'p1',
                        ),
                    child: const Text('abrir'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar publicación'), findsOneWidget);
      await tester.tap(find.text('Oferta de empleo falsa'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(sent, {
      'target_type': 'publication',
      'target_id': 'p1',
      'reason': 'fake_job',
    });
  });

  testWidgets('la casilla de términos muestra su error', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder:
                (context, setState) => TermsCheckbox(
                  value: accepted,
                  errorText:
                      accepted ? null : 'Debes aceptar para crear tu cuenta.',
                  onChanged: (v) => setState(() => accepted = v),
                ),
          ),
        ),
      ),
    );

    expect(find.text('Debes aceptar para crear tu cuenta.'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(accepted, isTrue);
    expect(find.text('Debes aceptar para crear tu cuenta.'), findsNothing);
  });
}
