import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/services/group_service.dart';
import 'package:connect_do/services/push_service.dart';
import 'package:connect_do/services/realtime_service.dart';

Map<String, dynamic> _user(String id) => {
  'id': id,
  'email': '$id@mail.com',
  'first_name': id,
  'last_name': 'X',
};

Map<String, dynamic> _message(
  String id, {
  String from = 'luis',
  String content = '',
  Map<String, dynamic>? replyTo,
  Map<String, String> reactions = const {},
  bool deleted = false,
}) => {
  'id': id,
  'sender_id': from,
  'receiver_id': from == 'luis' ? 'ana' : 'luis',
  'content': content,
  'is_read': true,
  'reply_to': replyTo,
  'reactions': reactions,
  'is_deleted': deleted,
  'created_at': DateTime.now().toIso8601String(),
  'sender': _user(from),
  'receiver': _user(from == 'luis' ? 'ana' : 'luis'),
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'usuario_actual': jsonEncode({'id': 'ana'}),
    });
  });

  test('mensajes de grupo, respuestas, reacciones y eliminados', () {
    final group = ChatMessageModel.fromBackend({
      'id': 'g1',
      'group_id': 'grupo',
      'sender': {'id': 'luis', 'name': 'Luis Pérez'},
      'kind': 'user',
      'content': 'Hola grupo',
      'reactions': {'ana': '❤️'},
      'created_at': DateTime.now().toIso8601String(),
    }, currentUserId: 'ana');
    expect(group.senderId, 'luis');
    expect(group.senderName, 'Luis Pérez');
    expect(group.isMe, isFalse);
    expect(group.reactions, {'ana': '❤️'});

    final reply = ChatMessageModel.fromBackend(
      _message(
        'r',
        replyTo: {'id': '1', 'sender_id': 'ana', 'attachment_type': 'image'},
      ),
      currentUserId: 'ana',
    );
    expect(reply.replyTo!.preview, '📷 Foto');

    final deleted = ChatMessageModel.fromBackend(
      _message('d', deleted: true),
      currentUserId: 'ana',
    );
    expect(deleted.isDeleted, isTrue);
  });

  test('última conexión legible', () {
    final now = DateTime(2026, 11, 27, 18, 0);
    expect(
      lastSeenLabel(DateTime(2026, 11, 27, 9, 5), now: now),
      'hoy a las 09:05',
    );
    expect(
      lastSeenLabel(DateTime(2026, 11, 26, 22, 30), now: now),
      'ayer a las 22:30',
    );
    expect(lastSeenLabel(DateTime(2026, 11, 2, 8), now: now), '02/11/2026');
  });

  test('grupo en la lista de chats', () {
    final chat = ChatListModel.fromGroup(
      ChatGroup.fromJson({
        'id': 'g',
        'name': 'Tesis',
        'unread_count': 2,
        'last_message': {
          'sender': {'id': 'luis', 'name': 'Luis Pérez'},
          'kind': 'user',
          'content': 'Nos vemos',
          'created_at': DateTime.now().toIso8601String(),
        },
      }),
      'ana',
    );
    expect(chat.isGroup, isTrue);
    expect(chat.senderPrefix, 'Luis');
    expect(chat.lastMessage, 'Nos vemos');
    expect(chat.unreadCount, 2);
  });

  test('el push de grupo abre el grupo', () {
    final screen = PushService.destinationFor({
      'type': 'group_message',
      'group_id': 'g',
      'group_name': 'Tesis',
    });
    expect(screen, isA<IndividualChatScreen>());
    expect((screen as IndividualChatScreen).isGroup, isTrue);
  });

  testWidgets('en tiempo real: llega un mensaje, escribiendo y reacción', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/presence')) {
        return http.Response(jsonEncode({'online': true}), 200);
      }
      if (request.url.path.endsWith('/messages')) {
        return http.Response(
          jsonEncode([_message('1', content: 'Hola Ana')]),
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
      await tester.pumpAndSettle();
    }, () => mock);

    expect(find.text('Hola Ana'), findsOneWidget);
    expect(find.text('en línea'), findsOneWidget);

    RealtimeService.instance.debugEmit({
      'type': 'typing',
      'from': 'luis',
      'is_typing': true,
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('escribiendo…'), findsOneWidget);

    await http.runWithClient(() async {
      RealtimeService.instance.debugEmit({
        'type': 'message',
        'message': _message('2', content: '¿Vamos al café?'),
      });
      await tester.pump();
      await tester.pump();
    }, () => mock);
    expect(find.text('¿Vamos al café?'), findsOneWidget);
    // Al llegar el mensaje deja de mostrarse "escribiendo…".
    expect(find.text('escribiendo…'), findsNothing);

    RealtimeService.instance.debugEmit({
      'type': 'reaction',
      'message_id': '2',
      'reactions': {'ana': '👍'},
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('👍'), findsOneWidget);

    RealtimeService.instance.debugEmit({'type': 'deleted', 'message_id': '2'});
    await tester.pump();
    await tester.pump();
    expect(find.text('Mensaje eliminado'), findsOneWidget);

    // Cierra la pantalla (cancela temporizadores).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });
}
