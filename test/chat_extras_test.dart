import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/services/media_upload_service.dart';
import 'package:connect_do/widgets/chat/chat_attachments.dart';

void main() {
  test('documentos y ubicación se leen del servidor', () {
    final doc = ChatMessageModel.fromBackend({
      'id': '1',
      'sender_id': 'ana',
      'content': '',
      'created_at': DateTime.now().toIso8601String(),
      'attachment': {
        'type': 'file',
        'url':
            'https://res.cloudinary.com/x/raw/upload/v1/connect_do/chat/u/t.pdf',
        'name': 'Tesis.pdf',
        'size_bytes': 1572864,
      },
    }, currentUserId: 'ana');
    expect(doc.fileName, 'Tesis.pdf');
    expect(doc.sizeBytes, 1572864);

    final until = DateTime.now().add(const Duration(minutes: 15));
    final live = ChatMessageModel.fromBackend({
      'id': '2',
      'sender_id': 'luis',
      'content': '',
      'created_at': DateTime.now().toIso8601String(),
      'attachment': {
        'type': 'location',
        'url': 'https://www.google.com/maps?q=13.7,-89.2',
        'lat': 13.7,
        'lng': -89.2,
        'live_until': until.toUtc().toIso8601String(),
      },
    }, currentUserId: 'ana');
    expect(live.lat, 13.7);
    expect(live.liveUntil!.isAfter(DateTime.now()), isTrue);

    // Llega una posición nueva por tiempo real.
    live.applyLocation({'lat': 13.71, 'lng': -89.21});
    expect(live.lat, 13.71);
    expect(live.lng, -89.21);
  });

  test('vista previa de documentos y ubicaciones', () {
    expect(messagePreviewText('', {'type': 'file'}), '📄 Documento');
    expect(messagePreviewText('', {'type': 'location'}), '📍 Ubicación');
  });

  test('la subida manda exactamente los campos firmados', () {
    // Documentos: sin allowed_formats (Cloudinary rechazaría la firma).
    expect(
      signedFields({
        'signed_fields': {'folder': 'connect_do/chat/u', 'timestamp': '1'},
        'allowed_formats': 'pdf,docx',
        'folder': 'connect_do/chat/u',
        'timestamp': '1',
      }),
      {'folder': 'connect_do/chat/u', 'timestamp': '1'},
    );
    // Servidor anterior (sin signed_fields): los de siempre.
    expect(
      signedFields({
        'folder': 'f',
        'timestamp': '1',
        'allowed_formats': 'jpg',
      }).keys,
      containsAll(['folder', 'timestamp', 'allowed_formats']),
    );
  });

  test('tamaños legibles', () {
    expect(formatBytes(850 * 1024), '850 KB');
    expect(formatBytes(1572864), '1,5 MB');
    expect(formatBytes(null), '');
  });

  testWidgets('burbuja de documento', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FileBubble(name: 'Informe final.docx', sizeBytes: 2097152),
        ),
      ),
    );
    expect(find.text('Informe final.docx'), findsOneWidget);
    expect(find.text('2,0 MB · DOCX'), findsOneWidget);
  });
}
