import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/screens/media/document_viewer_screen.dart';
import 'package:connect_do/screens/media/media_viewer_screen.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/screens/applications/application_ui.dart';
import 'package:connect_do/widgets/chat/chat_attachments.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/media/media_gallery.dart';

/// Lo compartido en una conversación: fotos y videos, documentos y enlaces.
Future<List<ChatMessageModel>> fetchShared({
  required String chatId,
  required bool isGroup,
  required String kind,
  required String myId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final path = isGroup ? '/groups/$chatId/media' : '/chats/$chatId/media';
  final response = await http.get(
    Uri.parse(
      '${ApiConfig.baseUrl}$path',
    ).replace(queryParameters: {'kind': kind, 'limit': '200'}),
    headers: {
      'Authorization': 'Bearer ${prefs.getString('access_token') ?? ''}',
    },
  );
  if (response.statusCode != 200) {
    throw Exception('No se pudo cargar.');
  }
  return [
    for (final raw in jsonDecode(utf8.decode(response.bodyBytes)) as List)
      ChatMessageModel.fromBackend(
        Map<String, dynamic>.from(raw as Map),
        currentUserId: myId,
      ),
  ];
}

final _linkPattern = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// Enlaces dentro de un texto (sin el punto o la coma final).
List<String> linksIn(String text) => [
  for (final m in _linkPattern.allMatches(text))
    m.group(0)!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), ''),
];

class ChatMediaScreen extends StatefulWidget {
  final String chatId;
  final bool isGroup;
  final String title;
  final String myId;

  const ChatMediaScreen({
    super.key,
    required this.chatId,
    required this.isGroup,
    required this.title,
    required this.myId,
  });

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> {
  static const _kinds = ['media', 'files', 'links'];

  int _tab = 0;
  final Map<String, List<ChatMessageModel>?> _data = {};
  final Map<String, bool> _failed = {};

  @override
  void initState() {
    super.initState();
    _load('media');
  }

  Future<void> _load(String kind) async {
    setState(() => _failed[kind] = false);
    try {
      final items = await fetchShared(
        chatId: widget.chatId,
        isGroup: widget.isGroup,
        kind: kind,
        myId: widget.myId,
      );
      if (mounted) setState(() => _data[kind] = items);
    } catch (_) {
      if (mounted) setState(() => _failed[kind] = true);
    }
  }

  void _select(int index) {
    setState(() => _tab = index);
    if (_data[_kinds[index]] == null) _load(_kinds[index]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final kind = _kinds[_tab];
    final items = _data[kind];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, widget.title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentTabs(
              labels: const ['Multimedia', 'Documentos', 'Enlaces'],
              index: _tab,
              onChanged: _select,
            ),
          ),
          Expanded(
            child:
                _failed[kind] == true
                    ? EmptyState(
                      icon: PhosphorIconsRegular.cloudSlash,
                      title: 'No se pudo cargar',
                      subtitle: 'Desliza hacia abajo para reintentar.',
                      action: TextButton(
                        onPressed: () => _load(kind),
                        child: const Text('Reintentar'),
                      ),
                    )
                    : items == null
                    ? const Center(
                      child: CircularProgressIndicator(color: Brand.blue),
                    )
                    : RefreshIndicator(
                      color: Brand.blue,
                      onRefresh: () => _load(kind),
                      child: switch (kind) {
                        'media' => _MediaGrid(items: items),
                        'files' => _FileList(items: items),
                        _ => _LinkList(items: items),
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

// EmptyState ya es una lista desplazable (sirve para "jalar y recargar").
Widget _empty(IconData icon, String text) =>
    EmptyState(icon: icon, title: text, subtitle: 'Aún no hay nada aquí.');

class _MediaGrid extends StatelessWidget {
  final List<ChatMessageModel> items;

  const _MediaGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final media = [
      for (final m in items)
        if (m.asMediaItem != null) m.asMediaItem!,
    ];
    if (media.isEmpty) {
      return _empty(PhosphorIconsRegular.images, 'Sin fotos ni videos');
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: media.length,
      itemBuilder: (context, i) {
        final item = media[i];
        return GestureDetector(
          onTap:
              () => Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black,
                  pageBuilder:
                      (_, __, ___) =>
                          MediaViewerScreen(items: media, initialIndex: i),
                  transitionsBuilder:
                      (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                ),
              ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: CachedNetworkImageProvider(
                  item.isVideo
                      ? CloudinaryUrl.videoPoster(item.url, width: 300)
                      : CloudinaryUrl.square(item.url, size: 300),
                ),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const ColoredBox(color: Colors.black12),
              ),
              if (item.isVideo)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.videoCamera,
                        color: Colors.white,
                        size: 14,
                      ),
                      if (item.duration != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          formatDuration(item.duration!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(blurRadius: 4)],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FileList extends StatelessWidget {
  final List<ChatMessageModel> items;

  const _FileList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _empty(PhosphorIconsRegular.fileText, 'Sin documentos');
    }
    final palette = AuthPalette.of(context);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = items[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FileBubble(
              name: m.fileName ?? 'Documento',
              url: m.attachmentUrl,
              sizeBytes: m.sizeBytes,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Text(
                '${m.isMe ? 'Tú' : (m.senderName ?? '').split(' ').first} · '
                '${formatChatDate(m.createdAt.toIso8601String())}',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinkList extends StatelessWidget {
  final List<ChatMessageModel> items;

  const _LinkList({required this.items});

  @override
  Widget build(BuildContext context) {
    final links = [
      for (final m in items)
        for (final url in linksIn(m.text)) (url, m),
    ];
    if (links.isEmpty) {
      return _empty(PhosphorIconsRegular.link, 'Sin enlaces');
    }
    final palette = AuthPalette.of(context);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: links.length,
      separatorBuilder:
          (_, __) => Divider(height: 1, indent: 72, color: palette.cardBorder),
      itemBuilder: (context, i) {
        final (url, m) = links[i];
        final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Brand.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(PhosphorIconsRegular.link, color: Brand.blue),
          ),
          title: Text(
            host,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontWeight: FontWeight.w700,
              color: palette.title,
            ),
          ),
          subtitle: Text(
            url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Brand.blue, fontSize: 12.5),
          ),
          trailing: Text(
            formatChatDate(m.createdAt.toIso8601String()),
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          onTap:
              () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
        );
      },
    );
  }
}

/// Para el botón de un documento dentro de una burbuja.
void openChatDocument(BuildContext context, ChatMessageModel m) {
  final url = m.attachmentUrl;
  if (url == null) return;
  openDocument(context, url: url, name: m.fileName ?? 'documento');
}
