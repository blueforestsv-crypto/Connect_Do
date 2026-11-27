import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/common/app_sheet.dart';
import 'package:connect_do/services/sticker_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Abre el selector y devuelve el sticker elegido (o null).
Future<StickerModel?> showStickerPicker(BuildContext context) {
  return showAppSheet<StickerModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StickerPicker(),
  );
}

/// Imagen de un sticker (sin fondo de burbuja).
class StickerImage extends StatelessWidget {
  final String url;
  final double size;

  const StickerImage({super.key, required this.url, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image(
        image: CachedNetworkImageProvider(
          CloudinaryUrl.sticker(url, size: (size * 2.5).round()),
        ),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder:
            (_, __, ___) => Icon(
              PhosphorIconsRegular.smileySad,
              color: AuthPalette.of(context).muted,
              size: size * 0.4,
            ),
      ),
    );
  }
}

class _StickerPicker extends StatefulWidget {
  const _StickerPicker();

  @override
  State<_StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<_StickerPicker> {
  List<StickerModel> _stickers = StickerService.cached ?? [];
  bool _loading = StickerService.cached == null;
  String? _busy; // texto de progreso al importar

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await StickerService.mine(refresh: true);
      if (mounted) {
        setState(() {
          _stickers = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = 'Abriendo…');
    try {
      final added = await StickerService.importFromFiles(
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _busy = 'Subiendo $done de $total…');
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _stickers = StickerService.cached ?? _stickers;
      });
      if (added > 0) {
        showAuthMessage(
          context,
          added == 1 ? '1 sticker agregado' : '$added stickers agregados',
          type: AuthMessageType.success,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = null);
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _fromPhoto() async {
    setState(() => _busy = 'Creando sticker…');
    try {
      final sticker = await StickerService.createFromPhoto();
      if (!mounted) return;
      setState(() {
        _busy = null;
        if (sticker != null) _stickers = StickerService.cached ?? _stickers;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = null);
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _showAddMenu() {
    showAppSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.whatsappLogo,
                    color: Color(0xFF25D366),
                  ),
                  title: Text(
                    'Importar mis stickers de WhatsApp',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  subtitle: Text(
                    'Busca la carpeta:\n${StickerService.whatsAppFolder}',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12,
                      color: palette.muted,
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _import();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.image,
                    color: Brand.blue,
                  ),
                  title: Text(
                    'Crear desde una foto',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _fromPhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(StickerModel sticker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            content: StickerImage(url: sticker.url, size: 120),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Quitar de mis stickers',
                  style: TextStyle(color: Brand.danger),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await StickerService.delete(sticker);
      if (mounted) setState(() => _stickers.remove(sticker));
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Brand.radiusLg),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: palette.fieldBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Row(
              children: [
                Text(
                  'Mis stickers',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                const Spacer(),
                if (_busy != null)
                  Text(
                    _busy!,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                _loading
                    ? const Center(
                      child: CircularProgressIndicator(color: Brand.blue),
                    )
                    : GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: _stickers.length + 1,
                      itemBuilder: (_, index) {
                        if (index == 0) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _busy == null ? _showAddMenu : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.fieldFill,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: palette.fieldBorder),
                              ),
                              child:
                                  _busy == null
                                      ? const Icon(
                                        PhosphorIconsBold.plus,
                                        color: Brand.blue,
                                      )
                                      : const Padding(
                                        padding: EdgeInsets.all(22),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Brand.blue,
                                        ),
                                      ),
                            ),
                          );
                        }
                        final sticker = _stickers[index - 1];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, sticker),
                          onLongPress: () => _confirmDelete(sticker),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: StickerImage(url: sticker.url, size: 80),
                          ),
                        );
                      },
                    ),
          ),
          if (!_loading && _stickers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Toca + para importar tus stickers de WhatsApp\no crear uno '
                'desde una foto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 13,
                  color: palette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
