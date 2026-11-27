import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/jobs/jobs_screen.dart';
import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/services/professional_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'token'});
  });

  test('periodo de una experiencia', () {
    final entry = ProfileEntry(
      id: '1',
      kind: 'experience',
      title: 'Dev',
      startDate: DateTime(2024, 1),
      endDate: DateTime(2025, 3),
    );
    expect(entry.period, 'ene 2024 – mar 2025 · 1 año 3 meses');
    expect(entry.toJson()['start_date'], '2024-01-01');

    final current = ProfileEntry(
      id: '2',
      kind: 'education',
      title: 'Sistemas',
      startDate: DateTime(2023, 2),
      endDate: DateTime(2024, 1),
      isCurrent: true,
    );
    expect(current.period, startsWith('feb 2023 – actualidad'));
    expect(current.toJson()['end_date'], isNull);
  });

  testWidgets('el buscador de empleos manda los filtros', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final queries = <Map<String, String>>[];
    final mock = MockClient((request) async {
      queries.add(request.url.queryParameters);
      return http.Response('[]', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: JobsScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Pasantías'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Remoto'));
      await tester.pump(const Duration(milliseconds: 100));
    }, () => mock);

    expect(queries.first['opportunities'], 'true');
    expect(queries.last['type'], 'internship');
    expect(queries.last['modality'], 'remote');
    expect(find.text('Sin resultados'), findsOneWidget);
  });

  testWidgets('perfil ajeno: trayectoria, insignia y validar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'user_id': 'ana',
          'first_name': 'Ana',
          'last_name': 'López',
          'headline': 'Estudiante de Sistemas · Flutter',
          'skills': ['Flutter'],
          'skill_details': [
            {'name': 'Flutter', 'count': 2, 'endorsed_by_me': false},
          ],
          'entries': [
            {
              'id': 'e1',
              'kind': 'education',
              'title': 'Ingeniería en Sistemas',
              'organization': 'UES',
              'start_date': '2022-01-01',
              'is_current': true,
            },
          ],
          'is_me': false,
          'contact_status': 'accepted',
          'account_type': 'student',
        }),
        200,
      ),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: UserProfileScreen(userId: 'ana')),
      );
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('Estudiante de Sistemas · Flutter'), findsOneWidget);
    expect(find.text('Ingeniería en Sistemas'), findsOneWidget);
    expect(find.text('2 contactos lo validaron'), findsOneWidget);
    expect(find.text('Validar'), findsOneWidget);
  });
}
