import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/core/firebase/firebase_config.dart';
import 'package:connect_do/screens/applications/my_applications_screen.dart';
import 'package:connect_do/screens/applications/received_applications_screen.dart';
import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';
import 'package:connect_do/screens/main_content/notification/notifications_screen.dart';
import 'package:connect_do/services/push_service.dart';

void main() {
  test('cada push abre su pantalla', () {
    expect(
      PushService.destinationFor({
        'type': 'like',
        'related_publication_id': 'p1',
      }),
      isA<PublicationDetailScreen>(),
    );
    expect(
      PushService.destinationFor({'type': 'message'}),
      isA<ChatListScreen>(),
    );
    expect(
      PushService.destinationFor({'type': 'application_new'}),
      isA<ReceivedApplicationsScreen>(),
    );
    expect(
      PushService.destinationFor({'type': 'application_status'}),
      isA<MyApplicationsScreen>(),
    );
    // Sin publicación o tipo desconocido: la lista de notificaciones.
    expect(
      PushService.destinationFor({'type': 'like'}),
      isA<NotificationsScreen>(),
    );
    expect(PushService.destinationFor({}), isA<NotificationsScreen>());
  });

  test('sin datos de Firebase, el push queda apagado sin errores', () async {
    if (FirebaseConfig.isConfigured) return;
    await PushService.init();
    await PushService.registerDevice();
    await PushService.unregisterDevice();
  });
}
