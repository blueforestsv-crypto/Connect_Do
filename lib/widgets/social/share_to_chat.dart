import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/chat_service.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Marca con la que viaja una publicación compartida en un mensaje.
/// El chat la muestra como tarjeta que abre la publicación.
final sharedPostPattern = RegExp(r'^\[pub:([0-9a-fA-F-]{36})\]\s?([\s\S]*)$');

String sharedPostMessage(PublicationModel post) {
  final title = post.displayTitle.trim();
  return '[pub:${post.id}] ${title.isEmpty ? 'Publicación' : title}';
}

/// Elegir un contacto y enviarle la publicación por chat.
Future<void> sharePublicationToChat(
  BuildContext context,
  PublicationModel post,
) async {
  final contact = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ContactPicker(),
  );
  if (contact == null || !context.mounted) return;

  try {
    await ChatService.sendMessage(
      contactId: contact['id'].toString(),
      content: sharedPostMessage(post),
    );
    if (context.mounted) {
      showAuthMessage(
        context,
        'Enviada a ${contact['first_name'] ?? 'tu contacto'}',
        type: AuthMessageType.success,
      );
    }
  } catch (_) {
    if (context.mounted) showAuthMessage(context, 'No se pudo enviar.');
  }
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker();

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  List<Map<String, dynamic>>? _contacts;
  String _query = '';

  @override
  void initState() {
    super.initState();
    ContactService.getAcceptedContacts()
        .then((list) {
          if (mounted) setState(() => _contacts = list);
        })
        .catchError((_) {
          if (mounted) setState(() => _contacts = []);
        });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    String name(Map<String, dynamic> c) =>
        '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
    final contacts =
        (_contacts ?? [])
            .where((c) => name(c).toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Material(
      color: palette.card,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Brand.radiusLg),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                  hintText: 'Enviar a…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child:
                  _contacts == null
                      ? const Center(
                        child: CircularProgressIndicator(color: Brand.blue),
                      )
                      : contacts.isEmpty
                      ? Center(
                        child: Text(
                          'Aún no tienes contactos.',
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            color: palette.muted,
                          ),
                        ),
                      )
                      : ListView(
                        children: [
                          for (final c in contacts)
                            ListTile(
                              leading: UserAvatar(
                                name: name(c),
                                photo:
                                    c['profile_image_base64']?.toString() ?? '',
                              ),
                              title: Text(
                                name(c),
                                style: TextStyle(
                                  fontFamily: Brand.displayFont,
                                  fontWeight: FontWeight.w600,
                                  color: palette.title,
                                ),
                              ),
                              trailing: const Icon(
                                PhosphorIconsRegular.paperPlaneRight,
                                color: Brand.blue,
                              ),
                              onTap: () => Navigator.pop(context, c),
                            ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
