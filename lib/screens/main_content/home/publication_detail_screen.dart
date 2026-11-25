import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/auth/auth_layout.dart';
import 'package:connect_do/widgets/publication_card.dart';

/// Una publicación abierta desde una notificación.
class PublicationDetailScreen extends StatefulWidget {
  final String publicationId;

  const PublicationDetailScreen({super.key, required this.publicationId});

  @override
  State<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  final PublicationApiService _api = PublicationApiService();

  bool _isLoading = true;
  PublicationModel? _publication;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    PublicationModel? found;
    try {
      found = await _api.getPublication(widget.publicationId);
    } catch (_) {
      found = null;
    }

    if (!mounted) return;
    setState(() {
      _publication = found;
      _isLoading = false;
    });
  }

  Future<void> _delete() async {
    final publication = _publication;
    if (publication == null) return;

    try {
      await _api.deletePublication(publication.id);
      if (!mounted) return;
      Navigator.pop(context);
      showAuthMessage(
        context,
        'Publicación eliminada',
        type: AuthMessageType.info,
      );
    } catch (_) {
      if (mounted) {
        showAuthMessage(context, 'No se pudo eliminar la publicación.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            AuthBackButton(onTap: () => Navigator.maybePop(context)),
            const SizedBox(width: 12),
            Text(
              'Publicación',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : _publication == null
              ? _buildNotFound(palette)
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: ResponsiveHelper.bottomSafe(context) + 24,
                  ),
                  children: [
                    PublicationCard(
                      post: _publication!,
                      onDelete: _delete,
                      onChanged:
                          (updated) => setState(() => _publication = updated),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildNotFound(AuthPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Brand.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsRegular.newspaper,
                size: 32,
                color: Brand.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Esta publicación ya no está disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.title,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Puede que la hayan eliminado o que ya no tengas acceso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 14,
                color: palette.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
