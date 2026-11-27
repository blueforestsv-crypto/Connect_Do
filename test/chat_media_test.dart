import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/main_content/chats/chat_media_screen.dart';
import 'package:connect_do/screens/media/media_viewer_screen.dart';

Map<String, dynamic> _msg(String id, {String content = '', Map? attachment}) =>
    {
      'id': id,
      'sender_id': 'luis',
      'receiver_id': 'ana',
      'content': content,
      'attachment': attachment,
      'is_read': true,
      'created_at': DateTime.now().toIso8601String(),
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'access_token': 't'}));

  test('enlaces dentro de un mensaje', () {
    expect(linksIn('Mira https://ues.edu.sv/becas. Y http://x.com/a?b=1, ok'), [
      'https://ues.edu.sv/becas',
      'http://x.com/a?b=1',
    ]);
    expect(linksIn('sin enlaces'), isEmpty);
  });

  test('cuánto falta del video', () {
    expect(
      remainingSeconds(
        const Duration(seconds: 12),
        const Duration(seconds: 90),
      ),
      78,
    );
    // Nunca negativo.
    expect(
      remainingSeconds(
        const Duration(seconds: 95),
        const Duration(seconds: 90),
      ),
      0,
    );
  });

  testWidgets('archivos, enlaces y documentos por pestañas', (tester) async {
    final asked = <String>[];
    final mock = MockClient((request) async {
      final kind = request.url.queryParameters['kind']!;
      asked.add('${request.url.path}?$kind');
      final body = switch (kind) {
        'files' => [
          _msg(
            '1',
            attachment: {
              'type': 'file',
              'url':
                  'https://res.cloudinary.com/x/raw/upload/v1/connect_do/chat/u/t.pdf',
              'name': 'Tesis.pdf',
              'size_bytes': 1048576,
            },
          ),
        ],
        'links' => [_msg('2', content: 'Becas: https://ues.edu.sv/becas')],
        _ => <Map>[],
      };
      return http.Response(jsonEncode(body), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatMediaScreen(
            chatId: 'luis',
            isGroup: false,
            title: 'Luis',
            myId: 'ana',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin fotos ni videos'), findsOneWidget);

      await tester.tap(find.text('Documentos'));
      await tester.pumpAndSettle();
      expect(find.text('Tesis.pdf'), findsOneWidget);

      await tester.tap(find.text('Enlaces'));
      await tester.pumpAndSettle();
      expect(find.text('ues.edu.sv'), findsOneWidget);
    }, () => mock);

    expect(asked, [
      '/chats/luis/media?media',
      '/chats/luis/media?files',
      '/chats/luis/media?links',
    ]);
  });
}
