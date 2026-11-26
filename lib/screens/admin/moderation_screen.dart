import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/applications/application_ui.dart';
import 'package:connect_do/services/safety_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/cloudinary_url.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Panel de moderación (solo administradores): revisar reportes y actuar.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  static const _statuses = ['pending', 'actioned', 'dismissed'];

  int _tab = 0;
  List<AdminReport>? _reports;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final reports = await SafetyService.adminReports(status: _statuses[_tab]);
      if (mounted) setState(() => _reports = reports);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _resolve(AdminReport report, String action) async {
    if (action == 'suspend_user') {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text('¿Suspender a ${report.targetUserName}?'),
              content: const Text(
                'No podrá entrar a la app y su contenido dejará de verse.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text(
                    'Suspender',
                    style: TextStyle(color: Brand.danger),
                  ),
                ),
              ],
            ),
      );
      if (ok != true) return;
    }

    setState(() => _busy.add(report.id));
    try {
      await SafetyService.resolve(report.id, action);
      if (!mounted) return;
      setState(
        () => _reports!.removeWhere((r) => r.targetId == report.targetId),
      );
      showAuthMessage(context, 'Listo', type: AuthMessageType.success);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(report.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final reports = _reports;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Moderación'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentTabs(
              labels: const ['Pendientes', 'Con acción', 'Descartados'],
              index: _tab,
              onChanged: (i) {
                setState(() {
                  _tab = i;
                  _reports = null;
                });
                _load();
              },
            ),
          ),
          Expanded(
            child:
                reports == null && _error == null
                    ? const Center(
                      child: CircularProgressIndicator(color: Brand.blue),
                    )
                    : RefreshIndicator(
                      color: Brand.blue,
                      onRefresh: _load,
                      child:
                          reports == null || reports.isEmpty
                              ? EmptyState(
                                icon:
                                    _error != null
                                        ? PhosphorIconsRegular.lockKey
                                        : PhosphorIconsRegular.shieldCheck,
                                title:
                                    _error != null
                                        ? 'Sin acceso'
                                        : 'Todo en orden',
                                subtitle: _error ?? 'No hay reportes aquí.',
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  32,
                                ),
                                itemCount: reports.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder:
                                    (_, i) => _ReportCard(
                                      report: reports[i],
                                      busy: _busy.contains(reports[i].id),
                                      showActions: _tab == 0,
                                      onAction:
                                          (action) =>
                                              _resolve(reports[i], action),
                                    ),
                              ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final AdminReport report;
  final bool busy;
  final bool showActions;
  final ValueChanged<String> onAction;

  const _ReportCard({
    required this.report,
    required this.busy,
    required this.showActions,
    required this.onAction,
  });

  static const _types = {
    'user': 'Cuenta',
    'publication': 'Publicación',
    'comment': 'Comentario',
    'story': 'Historia',
    'message': 'Mensaje',
  };

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final preview = report.preview ?? '';
    final imageUrl = RegExp(
      r'https://res\.cloudinary\.com/\S+',
    ).firstMatch(preview)?.group(0);
    final text = preview.replaceAll(imageUrl ?? '\u0000', '').trim();

    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: _types[report.targetType] ?? report.targetType,
                color: Brand.blue,
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: reportReasons[report.reason] ?? report.reason,
                color: Brand.danger,
              ),
              const Spacer(),
              Text(
                timeAgo(report.createdAt),
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'De: ${report.targetUserName}'
            '${report.reportsAgainstUser > 1 ? '  ·  ${report.reportsAgainstUser} reportes en total' : ''}',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontWeight: FontWeight.w700,
              color: palette.title,
            ),
          ),
          Text(
            'Reportó: ${report.reporterName}',
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 12.5,
              color: palette.muted,
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(Brand.radiusSm),
              ),
              child: Text(
                text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 13.5,
                  color: palette.label,
                ),
              ),
            ),
          ],
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(Brand.radiusSm),
              child: Image.network(
                imageUrl.contains('/video/')
                    ? CloudinaryUrl.videoPoster(imageUrl, width: 600)
                    : CloudinaryUrl.image(imageUrl, width: 600),
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if ((report.details ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '“${report.details}”',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontStyle: FontStyle.italic,
                color: palette.body,
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            busy
                ? const Center(
                  child: CircularProgressIndicator(color: Brand.blue),
                )
                : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => onAction('dismiss'),
                      child: const Text('Descartar'),
                    ),
                    if (report.targetType != 'user')
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.blue,
                        ),
                        onPressed: () => onAction('remove_content'),
                        child: const Text('Quitar contenido'),
                      ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Brand.danger,
                      ),
                      onPressed: () => onAction('suspend_user'),
                      child: const Text('Suspender cuenta'),
                    ),
                  ],
                ),
          ],
        ],
      ),
    );
  }
}
