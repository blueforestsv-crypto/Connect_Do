import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/services/live_location_service.dart';
import 'package:connect_do/services/realtime_service.dart';
import 'package:connect_do/theme/brand.dart';

/// Documentos que se pueden enviar por chat.
const documentExtensions = [
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'csv',
  'zip',
  'rar',
  'odt',
  'ods',
  'odp',
  'rtf',
];

/// "1,2 MB", "830 KB".
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

String fileExtension(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

(IconData, Color) _fileStyle(String extension) => switch (extension) {
  'pdf' => (PhosphorIconsFill.filePdf, const Color(0xFFDC2626)),
  'doc' ||
  'docx' ||
  'odt' ||
  'rtf' => (PhosphorIconsFill.fileDoc, const Color(0xFF2563EB)),
  'xls' ||
  'xlsx' ||
  'ods' ||
  'csv' => (PhosphorIconsFill.fileXls, const Color(0xFF16A34A)),
  'ppt' ||
  'pptx' ||
  'odp' => (PhosphorIconsFill.filePpt, const Color(0xFFEA580C)),
  'zip' || 'rar' => (PhosphorIconsFill.fileZip, const Color(0xFF7C3AED)),
  _ => (PhosphorIconsFill.fileText, const Color(0xFF64748B)),
};

/// Documento dentro de la burbuja: ícono, nombre, tamaño; al tocarlo se abre.
class FileBubble extends StatelessWidget {
  final String name;
  final String? url;
  final int? sizeBytes;
  final bool onDark;

  /// Mientras se sube (0 a 1, o null si aún no empieza).
  final double? progress;
  final bool uploading;

  const FileBubble({
    super.key,
    required this.name,
    this.url,
    this.sizeBytes,
    this.onDark = false,
    this.progress,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final extension = fileExtension(name);
    final (icon, color) = _fileStyle(extension);
    final fg = onDark ? Colors.white : palette.title;
    final details = [
      if (formatBytes(sizeBytes).isNotEmpty) formatBytes(sizeBytes),
      if (extension.isNotEmpty) extension.toUpperCase(),
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:
          url == null || uploading
              ? null
              : () => launchUrl(
                Uri.parse(url!),
                mode: LaunchMode.externalApplication,
              ),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              onDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 34, color: onDark ? Colors.white : color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            uploading
                ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    color: onDark ? Colors.white : color,
                  ),
                )
                : Icon(
                  PhosphorIconsRegular.downloadSimple,
                  size: 20,
                  color: fg.withValues(alpha: 0.8),
                ),
          ],
        ),
      ),
    );
  }
}

/// Mapa de OpenStreetMap (gratis, sin clave). Pide los mapas con el nombre
/// de la app, como exige su política de uso.
class _OsmMap extends StatelessWidget {
  final LatLng point;

  const _OsmMap({required this.point});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      // Se reconstruye cuando la ubicación se mueve (tiempo real).
      key: ValueKey('${point.latitude},${point.longitude}'),
      options: MapOptions(
        initialCenter: point,
        initialZoom: 15.5,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.blueforest.connectdo',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: const Icon(
                PhosphorIconsFill.mapPin,
                color: Color(0xFFDC2626),
                size: 44,
              ),
            ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap', style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}

/// Ubicación dentro de la burbuja (fija o en tiempo real).
class LocationBubble extends StatelessWidget {
  final String? messageId;
  final double lat;
  final double lng;
  final DateTime? liveUntil;
  final bool isMe;
  final bool isGroup;
  final String senderName;

  const LocationBubble({
    super.key,
    this.messageId,
    required this.lat,
    required this.lng,
    this.liveUntil,
    required this.isMe,
    this.isGroup = false,
    this.senderName = '',
  });

  bool get isLive => liveUntil != null;
  bool get isActive => liveUntil?.isAfter(DateTime.now()) ?? false;

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fg = isMe ? Colors.white : AuthPalette.of(context).title;
    final label =
        !isLive
            ? 'Ubicación'
            : isActive
            ? 'En tiempo real · hasta las ${_hhmm(liveUntil!)}'
            : 'Ubicación en tiempo real (finalizó)';

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => LocationViewerScreen(
                          messageId: messageId,
                          lat: lat,
                          lng: lng,
                          liveUntil: liveUntil,
                          title: senderName,
                        ),
                  ),
                ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 140,
                child: AbsorbPointer(child: _OsmMap(point: LatLng(lat, lng))),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? PhosphorIconsFill.broadcast
                      : PhosphorIconsFill.mapPin,
                  size: 16,
                  color: isActive ? const Color(0xFF22C55E) : fg,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe && isActive && messageId != null)
            ValueListenableBuilder(
              valueListenable: LiveLocationService.instance.sharing,
              builder: (context, _, __) {
                final mine = LiveLocationService.instance.isSharing(messageId!);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed:
                        mine
                            ? () =>
                                LiveLocationService.instance.stop(messageId!)
                            : null,
                    icon: Icon(
                      mine
                          ? PhosphorIconsRegular.stopCircle
                          : PhosphorIconsRegular.info,
                      size: 18,
                    ),
                    label: Text(
                      mine ? 'Dejar de compartir' : 'Se pausó al cerrar la app',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Mapa a pantalla completa. Si es en tiempo real, se mueve solo.
class LocationViewerScreen extends StatefulWidget {
  final String? messageId;
  final double lat;
  final double lng;
  final DateTime? liveUntil;
  final String title;

  const LocationViewerScreen({
    super.key,
    this.messageId,
    required this.lat,
    required this.lng,
    this.liveUntil,
    this.title = '',
  });

  @override
  State<LocationViewerScreen> createState() => _LocationViewerScreenState();
}

class _LocationViewerScreenState extends State<LocationViewerScreen> {
  late LatLng _point = LatLng(widget.lat, widget.lng);
  final _map = MapController();
  StreamSubscription<Map<String, dynamic>>? _live;

  @override
  void initState() {
    super.initState();
    _live = RealtimeService.instance.events.listen((event) {
      if (event['type'] != 'location' ||
          event['message_id']?.toString() != widget.messageId) {
        return;
      }
      final a = event['attachment'];
      if (a is! Map || a['lat'] == null || a['lng'] == null) return;
      final next = LatLng(
        (a['lat'] as num).toDouble(),
        (a['lng'] as num).toDouble(),
      );
      setState(() => _point = next);
      _map.move(next, _map.camera.zoom);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.liveUntil?.isAfter(DateTime.now()) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          live
              ? '${widget.title} · en tiempo real'.trim()
              : (widget.title.isEmpty ? 'Ubicación' : widget.title),
        ),
      ),
      body: FlutterMap(
        mapController: _map,
        options: MapOptions(initialCenter: _point, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.blueforest.connectdo',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _point,
                width: 52,
                height: 52,
                alignment: Alignment.topCenter,
                child: const Icon(
                  PhosphorIconsFill.mapPin,
                  color: Color(0xFFDC2626),
                  size: 52,
                ),
              ),
            ],
          ),
          const SimpleAttributionWidget(
            source: Text('OpenStreetMap', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.blue,
        foregroundColor: Colors.white,
        onPressed:
            () => launchUrl(
              Uri.parse(
                'https://www.google.com/maps/search/?api=1&query='
                '${_point.latitude},${_point.longitude}',
              ),
              mode: LaunchMode.externalApplication,
            ),
        icon: const Icon(PhosphorIconsRegular.navigationArrow),
        label: const Text('Abrir en Google Maps'),
      ),
    );
  }
}
