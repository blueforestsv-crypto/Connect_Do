import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/applications/my_applications_screen.dart';
import 'package:connect_do/screens/applications/received_applications_screen.dart';
import 'package:connect_do/screens/people/user_profile_screen.dart';

Map<String, dynamic> application({String status = 'new'}) => {
  'id': 'app-1',
  'publication_id': 'pub-1',
  'student_id': 'ana',
  'company_id': 'empresa',
  'status': status,
  'profile_snapshot': {
    'first_name': 'Ana',
    'last_name': 'López',
    'career': 'Ingeniería en Sistemas',
    'university': 'UES',
    'cv_url': 'cv.pdf',
  },
  'cv_url': 'cv.pdf',
  'cover_message': 'Me interesa mucho.',
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
  'publication': {
    'id': 'pub-1',
    'title': 'Desarrollador Flutter junior',
    'type': 'job',
    'location': 'San Salvador',
    'modality': 'Híbrido',
  },
  'student': {
    'id': 'ana',
    'email': 'ana@ues.edu.sv',
    'first_name': 'Ana',
    'last_name': 'López',
  },
  'company': {
    'id': 'empresa',
    'email': 'rrhh@empresa.com',
    'first_name': 'Tech',
    'last_name': 'SV',
  },
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'token'});
  });

  testWidgets('recibidas: abrir marca vista y seleccionar avisa', (
    tester,
  ) async {
    final patches = <String>[];

    final mock = MockClient((request) async {
      if (request.method == 'PATCH') {
        final status = (jsonDecode(request.body) as Map)['status'] as String;
        patches.add(status);
        return http.Response(jsonEncode(application(status: status)), 200);
      }
      return http.Response(jsonEncode([application()]), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: ReceivedApplicationsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana López'), findsOneWidget);
      expect(find.text('Nuevas (1)'), findsOneWidget);

      await tester.tap(find.text('Ana López'));
      await tester.pumpAndSettle();

      expect(find.text('Ver currículum'), findsOneWidget);
      expect(find.text('Me interesa mucho.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Seleccionar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(patches, ['reviewed', 'selected']);
  });

  testWidgets('mis postulaciones: muestra estado y empresa', (tester) async {
    final mock = MockClient(
      (request) async =>
          http.Response(jsonEncode([application(status: 'interview')]), 200),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyApplicationsScreen()));
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('Desarrollador Flutter junior'), findsOneWidget);
    expect(find.text('Activas (1)'), findsOneWidget);
    expect(find.textContaining('Tech SV'), findsOneWidget);
    // Una vez en la píldora y otra en la barra de pasos.
    expect(find.text('Entrevista'), findsNWidgets(2));
  });

  testWidgets('perfil ajeno: botón Conectar y datos privados ocultos', (
    tester,
  ) async {
    final requests = <String>[];

    final mock = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'id': 'req-1'}), 201);
      }
      return http.Response(
        jsonEncode({
          'user_id': 'ana',
          'first_name': 'Ana',
          'last_name': 'López',
          'career': 'Ingeniería en Sistemas',
          'university': 'UES',
          'bio': 'Me gusta crear apps.',
          'skills': ['Flutter', 'Figma'],
          'has_cv': true,
          'email': null,
          'phone': null,
          'is_me': false,
          'contact_status': requests.length > 1 ? 'pending_sent' : 'none',
        }),
        200,
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: UserProfileScreen(userId: 'ana')),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Flutter'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Flutter'), findsOneWidget);
      final privacyNote = find.text(
        'Su correo y teléfono se muestran solo a sus contactos.',
      );
      await tester.scrollUntilVisible(
        privacyNote,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(privacyNote, findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitud enviada'), findsWidgets);
    }, () => mock);

    expect(requests, contains('POST /contacts/requests/ana'));
  });

  testWidgets('perfil privado: candado y sin datos', (tester) async {
    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'user_id': 'luis',
          'first_name': 'Luis',
          'last_name': 'Pérez',
          'university': 'UCA',
          'is_me': false,
          'is_private': true,
          'limited': true,
          'contact_status': 'none',
        }),
        200,
      ),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: UserProfileScreen(userId: 'luis')),
      );
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('Perfil privado'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
    expect(find.text('Ver sus publicaciones'), findsNothing);
  });
}
