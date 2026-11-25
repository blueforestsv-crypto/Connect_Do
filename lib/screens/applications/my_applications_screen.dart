import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/application_model.dart';
import 'package:connect_do/screens/applications/application_ui.dart';
import 'package:connect_do/screens/main_content/home/publication_detail_screen.dart';
import 'package:connect_do/services/application_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Las oportunidades a las que me postulé y en qué van.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  List<ApplicationModel> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _showClosed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApplicationService.getMyApplications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasError = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _withdraw(ApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('¿Retirar postulación?'),
            content: Text(
              'La empresa dejará de ver tu postulación a '
              '«${application.publicationTitle}».',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Retirar',
                  style: TextStyle(color: Brand.danger),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await ApplicationService.withdraw(application);
      if (!mounted) return;
      setState(() => _items.remove(application));
      showAuthMessage(
        context,
        'Postulación retirada',
        type: AuthMessageType.success,
      );
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
    final open = _items.where((a) => ApplicationStatus.isOpen(a.status));
    final closed = _items.where((a) => !ApplicationStatus.isOpen(a.status));
    final visible = (_showClosed ? closed : open).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Mis postulaciones'),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  color: Brand.blue,
                  strokeWidth: 2.5,
                ),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child: Column(
                  children: [
                    if (_items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: SegmentTabs(
                          labels: [
                            'Activas (${open.length})',
                            'Cerradas (${closed.length})',
                          ],
                          index: _showClosed ? 1 : 0,
                          onChanged:
                              (i) => setState(() => _showClosed = i == 1),
                        ),
                      ),
                    Expanded(
                      child:
                          visible.isEmpty
                              ? EmptyState(
                                icon:
                                    _hasError
                                        ? PhosphorIconsRegular.cloudSlash
                                        : PhosphorIconsRegular.briefcase,
                                title:
                                    _hasError
                                        ? 'No se pudieron cargar'
                                        : _items.isEmpty
                                        ? 'Aún no te postulas'
                                        : 'Nada por aquí',
                                subtitle:
                                    _hasError
                                        ? 'Desliza hacia abajo para reintentar.'
                                        : _items.isEmpty
                                        ? 'Cuando apliques a una pasantía o '
                                            'empleo del inicio, verás aquí '
                                            'cómo avanza.'
                                        : 'No tienes postulaciones en esta '
                                            'sección.',
                              )
                              : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  ResponsiveHelper.bottomSafe(context) + 24,
                                ),
                                itemCount: visible.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder:
                                    (_, i) => _MyApplicationCard(
                                      application: visible[i],
                                      onWithdraw: () => _withdraw(visible[i]),
                                    ),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _MyApplicationCard extends StatelessWidget {
  final ApplicationModel application;
  final VoidCallback onWithdraw;

  const _MyApplicationCard({
    required this.application,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final details = [
      application.companyName,
      if (application.modality != null) application.modality!,
      if (application.location != null) application.location!,
    ].join(' · ');

    return BrandCard(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => PublicationDetailScreen(
                    publicationId: application.publicationId,
                  ),
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  application.publicationTitle,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ApplicationStatusPill(status: application.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            details,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 13,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 14),
          ApplicationProgress(status: application.status),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Enviada · ${timeAgo(application.createdAt)}',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12.5,
                  color: palette.muted,
                ),
              ),
              const Spacer(),
              if (application.status != 'selected')
                TextButton(
                  onPressed: onWithdraw,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: palette.muted,
                  ),
                  child: const Text(
                    'Retirar',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
