import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/widgets/comment_sheet.dart';
import 'package:connect_do/widgets/feed/expandable_text.dart';
import 'package:connect_do/widgets/social/mention_suggestions.dart';
import 'package:connect_do/widgets/social/share_to_chat.dart';

Map<String, dynamic> _comment(
  String id,
  String text, {
  String? parent,
  int likes = 0,
}) => {
  'id': id,
  'publication_id': 'p1',
  'text': text,
  'parent_id': parent,
  'likes_count': likes,
  'liked_by_me': false,
  'created_at': DateTime.now().toIso8601String(),
  'updated_at': DateTime.now().toIso8601String(),
  'author': {'id': 'u$id', 'first_name': 'Persona', 'last_name': id},
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'token'});
  });

  testWidgets('hashtags y menciones se pueden tocar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpandableText(
            text: 'Hola @Ana López, mira #Flutter y #UES',
            textColor: Colors.black,
            mentions: [
              {'id': 'ana', 'name': 'Ana López'},
            ],
          ),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final links = <String>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
        links.add(span.text!);
      }
      return true;
    });
    expect(links, ['@Ana López', '#Flutter', '#UES']);
  });

  test('las menciones borradas del texto no se envían', () {
    final tracker =
        MentionTracker()
          ..add('ana', 'Ana López')
          ..add('luis', 'Luis Pérez');
    expect(tracker.idsIn('Hola @Ana López'), ['ana']);
  });

  test('publicación compartida por chat', () {
    final post = PublicationModel.fromJson({
      'id': '11111111-2222-3333-4444-555555555555',
      'type': 'general',
      'title': 'Hackatón UES',
      'description': 'Vengan todos',
      'created_at': DateTime.now().toIso8601String(),
    });
    final message = sharedPostMessage(post);
    final match = sharedPostPattern.firstMatch(message)!;
    expect(match.group(1), post.id);
    expect(match.group(2), 'Hackatón UES');
  });

  testWidgets('comentarios: respuestas debajo del original y me gusta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/comments')) {
        return http.Response(
          jsonEncode([
            _comment('1', 'Primero'),
            _comment('2', 'Otro'),
            _comment('3', 'Respuesta al primero', parent: '1', likes: 4),
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    final post = PublicationModel.fromJson({
      'id': 'p1',
      'type': 'general',
      'title': 'Hola',
      'description': 'Una publicación',
      'created_at': DateTime.now().toIso8601String(),
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CommentSheet(post: post))),
      );
      await tester.pumpAndSettle();
    }, () => mock);

    final first = tester.getTopLeft(find.text('Primero')).dy;
    final reply = tester.getTopLeft(find.text('Respuesta al primero')).dy;
    final other = tester.getTopLeft(find.text('Otro')).dy;
    // La respuesta va justo debajo de su original, antes del siguiente.
    expect(reply, greaterThan(first));
    expect(reply, lessThan(other));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Responder'), findsNWidgets(3));
  });
}
