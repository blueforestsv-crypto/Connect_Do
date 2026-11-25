import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/widgets/chat/voice_note_player.dart';

Map<String, dynamic> _user(String id) => {
  'id': id,
  'email': '$id@mail.com',
  'first_name': id,
  'last_name': 'X',
};

Map<String, dynamic> _message(
  String id, {
  String content = '',
  Map<String, dynamic>? attachment,
}) => {
  'id': id,
  'sender_id': 'luis',
  'receiver_id': 'ana',
  'content': content,
  'attachment': attachment,
  'is_read': true,
  'created_at': DateTime.now().toIso8601String(),
  'sender': _user('luis'),
  'receiver': _user('ana'),
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'usuario_actual': jsonEncode({'id': 'ana'}),
    });
  });

  testWidgets('muestra foto, nota de voz y texto', (tester) async {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/messages')) {
        return http.Response(
          jsonEncode([
            _message('1', content: 'Hola'),
            _message(
              '2',
              content: 'Mira esto',
              attachment: {
                'type': 'image',
                'url':
                    'https://res.cloudinary.com/x/image/upload/v1/connect_do/chat/a.jpg',
                'width': 800,
                'height': 600,
              },
            ),
            _message(
              '3',
              attachment: {
                'type': 'audio',
                'url':
                    'https://res.cloudinary.com/x/video/upload/v1/connect_do/chat/n.m4a',
                'duration': 7,
              },
            ),
          ]),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IndividualChatScreen(
            chatId: 'luis',
            chatName: 'Luis X',
            chatAvatar: '',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Mira esto'), findsOneWidget);
      expect(find.byType(VoiceNotePlayer), findsOneWidget);
      expect(find.text('0:07'), findsOneWidget);
      // Sin texto escrito, el botón principal graba (micrófono).
      expect(find.byTooltip('Grabar nota de voz'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hola de vuelta');
      await tester.pump();
      expect(find.byTooltip('Enviar'), findsOneWidget);

      // Cierra la pantalla para detener la actualización automática.
      await tester.pumpWidget(const SizedBox());
    }, () => mock);
  });
}
