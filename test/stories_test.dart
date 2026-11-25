import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/stories/story_viewer_screen.dart';
import 'package:connect_do/services/story_service.dart';
import 'package:connect_do/widgets/stories/stories_row.dart';

const _url =
    'https://res.cloudinary.com/x/image/upload/v1/connect_do/story/u/a.jpg';

Map<String, dynamic> _group(
  String id,
  String name, {
  bool isMe = false,
  bool viewed = false,
}) => {
  'user': {'id': id, 'first_name': name, 'last_name': 'X'},
  'is_me': isMe,
  'has_unseen': !viewed,
  'stories': [
    {
      'id': 's-$id',
      'type': 'image',
      'url': _url,
      'caption': 'Hola desde $name',
      'created_at': DateTime.now().toIso8601String(),
      'expires_at':
          DateTime.now().add(const Duration(hours: 20)).toIso8601String(),
      'viewed': viewed || isMe,
      'views_count': isMe ? 3 : null,
    },
  ],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'usuario_actual': jsonEncode({'id': 'yo', 'firstName': 'Frank'}),
    });
  });

  testWidgets('la fila muestra "Tu historia" y a los contactos', (
    tester,
  ) async {
    final mock = MockClient(
      (request) async => http.Response(
        jsonEncode([
          _group('yo', 'Frank', isMe: true),
          _group('ana', 'Ana'),
          _group('luis', 'Luis', viewed: true),
        ]),
        200,
      ),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StoriesRow())),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    }, () => mock);

    expect(find.text('Tu historia'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
  });

  testWidgets('el visor marca vista la historia ajena y permite responder', (
    tester,
  ) async {
    final calls = <String>[];
    final mock = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return http.Response('{}', 200);
    });

    final groups = [StoryGroup.fromJson(_group('ana', 'Ana'))];

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(home: StoryViewerScreen(groups: groups)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hola desde Ana'), findsOneWidget);
      expect(find.text('Responder a Ana…'), findsOneWidget);
      expect(groups.first.stories.first.viewed, isTrue);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump(const Duration(milliseconds: 300));
    }, () => mock);

    expect(calls, contains('POST /stories/s-ana/view'));
  });

  testWidgets('en mi historia se ve el contador de vistas', (tester) async {
    final mock = MockClient((request) async => http.Response('[]', 200));
    final groups = [StoryGroup.fromJson(_group('yo', 'Frank', isMe: true))];

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(home: StoryViewerScreen(groups: groups)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('Borrar historia'), findsOneWidget);
      expect(find.textContaining('Responder'), findsNothing);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump(const Duration(milliseconds: 300));
    }, () => mock);
  });
}
