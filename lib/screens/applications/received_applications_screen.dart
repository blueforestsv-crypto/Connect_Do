import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/models/application_model.dart';
import 'package:connect_do/screens/applications/application_detail_screen.dart';
import 'package:connect_do/screens/applications/application_ui.dart';
import 'package:connect_do/services/application_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Quién se postuló a mis oportunidades.
class ReceivedApplicationsScreen extends StatefulWidget {
  const ReceivedApplicationsScreen({super.key});

  @override
  State<ReceivedApplicationsScreen> createState() =>
      _ReceivedApplicationsScreenState();
}

class _ReceivedApplicationsScreenState
    extends State<ReceivedApplicationsScreen> {
  List<ApplicationModel> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApplicationService.getReceivedApplications();
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

  List<ApplicationModel> _filter(int tab) => switch (tab) {
    0 => _items.where((a) => a.status == 'new').toList(),
    1 =>
      _items
          .where((a) => a.status != 'new' && ApplicationStatus.isOpen(a.status))
          .toList(),
    _ => _items.where((a) => !ApplicationStatus.isOpen(a.status)).toList(),
  };

  Future<void> _open(ApplicationModel application) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationDetailScreen(application: application),
      ),
    );
    // El detalle modifica el mismo objeto (estado); solo repintamos.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final visible = _filter(_tab);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Postulaciones recibidas'),
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
                            'Nuevas (${_filter(0).length})',
                            'En proceso (${_filter(1).length})',
                            'Cerradas',
                          ],
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                      ),
                    Expanded(
                      child:
                          visible.isEmpty
                              ? EmptyState(
                                icon:
                                    _hasError
                                        ? PhosphorIconsRegular.cloudSlash
                                        : PhosphorIconsRegular.usersThree,
                                title:
                                    _hasError
                                        ? 'No se pudieron cargar'
                                        : _items.isEmpty
                                        ? 'Sin postulaciones todavía'
                                        : 'Nada por aquí',
                                subtitle:
                                    _hasError
                                        ? 'Desliza hacia abajo para reintentar.'
                                        : _items.isEmpty
                                        ? 'Publica una pasantía o empleo y '
                                            'aquí verás a quienes se postulen.'
                                        : 'No hay postulaciones en esta '
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
                                    (_, i) => _ReceivedCard(
                                      application: visible[i],
                                      onTap: () => _open(visible[i]),
                                    ),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _ReceivedCard extends StatelessWidget {
  final ApplicationModel application;
  final VoidCallback onTap;

  const _ReceivedCard({required this.application, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final subtitle = [
      if (application.career != null) application.career!,
      if (application.university != null) application.university!,
    ].join(' · ');

    return BrandCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: application.studentName,
                photo: application.studentPhoto,
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: palette.title,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ApplicationStatusPill(status: application.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.briefcase,
                size: 15,
                color: palette.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  application.publicationTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.label,
                  ),
                ),
              ),
              if (application.hasCv) ...[
                const SizedBox(width: 8),
                const StatusPill(
                  label: 'CV',
                  color: Brand.green,
                  icon: PhosphorIconsBold.filePdf,
                ),
              ],
              const SizedBox(width: 8),
              Text(
                timeAgo(application.createdAt),
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
