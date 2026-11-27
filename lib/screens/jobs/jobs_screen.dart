import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/common/app_sheet.dart';
import 'package:connect_do/models/publication_model.dart';
import 'package:connect_do/services/professional_service.dart';
import 'package:connect_do/services/publication_api_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/publication_card.dart';

const jobTypes = <String, String>{
  'internship': 'Pasantías',
  'job': 'Empleos',
  'social_service': 'Servicio social',
  'freelance': 'Freelance',
};

const jobModalities = <String, String>{
  'remote': 'Remoto',
  'hybrid': 'Híbrido',
  'onsite': 'Presencial',
};

/// Buscador de oportunidades con filtros y alertas.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  static const _pageSize = 15;

  final _api = PublicationApiService();
  final _search = TextEditingController();
  final _location = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  String? _type;
  String? _modality;
  bool _verifiedOnly = false;

  List<PublicationModel> _results = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _location.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<List<PublicationModel>> _fetch(int offset) => _api.getPublications(
    opportunities: true,
    type: _type,
    modality: _modality,
    location: _location.text,
    query: _search.text,
    verifiedOnly: _verifiedOnly,
    limit: _pageSize,
    offset: offset,
  );

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final page = await _fetch(0);
      if (!mounted || request != _request) return;
      setState(() {
        _results = page;
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _results = []);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_results.length);
      if (!mounted || request != _request) return;
      final known = _results.map((p) => p.id).toSet();
      setState(() {
        _results.addAll(page.where((p) => !known.contains(p.id)));
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onTextChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  bool get _hasFilters =>
      _search.text.trim().isNotEmpty ||
      _location.text.trim().isNotEmpty ||
      _type != null ||
      _modality != null;

  Future<void> _createAlert() async {
    if (!_hasFilters) {
      showAuthMessage(
        context,
        'Elige al menos un filtro (texto, tipo, modalidad o lugar).',
        type: AuthMessageType.info,
      );
      return;
    }
    try {
      await ProfessionalService.createAlert(
        query: _search.text,
        type: _type,
        modality: _modality,
        location: _location.text,
      );
      if (mounted) {
        showAuthMessage(
          context,
          'Te avisaremos cuando publiquen algo así',
          type: AuthMessageType.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  void _showAlerts() {
    showAppSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AlertsSheet(),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Brand.blue.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontFamily: Brand.displayFont,
          fontWeight: FontWeight.w600,
          color: selected ? Brand.blue : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(
        context,
        'Empleos y pasantías',
        actions: [
          IconButton(
            tooltip: 'Mis alertas',
            onPressed: _showAlerts,
            icon: Icon(PhosphorIconsRegular.bellRinging, color: palette.title),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Brand.blue,
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AuthTextField(
                controller: _search,
                label: 'Buscar',
                hint: 'Flutter, contabilidad, diseño…',
                icon: PhosphorIconsRegular.magnifyingGlass,
                textInputAction: TextInputAction.search,
                onChanged: _onTextChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AuthTextField(
                controller: _location,
                label: 'Lugar',
                hint: 'San Salvador, Santa Ana…',
                icon: PhosphorIconsRegular.mapPin,
                onChanged: _onTextChanged,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final type in jobTypes.entries)
                    _chip(type.value, _type == type.key, () {
                      setState(
                        () => _type = _type == type.key ? null : type.key,
                      );
                      _load();
                    }),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final modality in jobModalities.entries)
                    _chip(modality.value, _modality == modality.key, () {
                      setState(
                        () =>
                            _modality =
                                _modality == modality.key ? null : modality.key,
                      );
                      _load();
                    }),
                  _chip('✓ Solo verificadas', _verifiedOnly, () {
                    setState(() => _verifiedOnly = !_verifiedOnly);
                    _load();
                  }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: OutlineActionButton(
                text: 'Avisarme de ofertas así',
                icon: PhosphorIconsRegular.bellSimpleRinging,
                onPressed: _createAlert,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: Brand.blue),
                ),
              )
            else if (_results.isEmpty)
              const SizedBox(
                height: 320,
                child: EmptyState(
                  icon: PhosphorIconsRegular.briefcase,
                  title: 'Sin resultados',
                  subtitle:
                      'Prueba con otros filtros o crea una alerta para que te '
                      'avisemos.',
                ),
              )
            else
              for (var i = 0; i < _results.length; i++)
                PublicationCard(
                  key: ValueKey(_results[i].id),
                  post: _results[i],
                  index: i,
                ),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: Brand.blue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertsSheet extends StatefulWidget {
  const _AlertsSheet();

  @override
  State<_AlertsSheet> createState() => _AlertsSheetState();
}

class _AlertsSheetState extends State<_AlertsSheet> {
  List<JobAlert>? _alerts;

  @override
  void initState() {
    super.initState();
    ProfessionalService.alerts()
        .then((alerts) {
          if (mounted) setState(() => _alerts = alerts);
        })
        .catchError((_) {
          if (mounted) setState(() => _alerts = []);
        });
  }

  String _describe(JobAlert alert) => [
    if ((alert.query ?? '').isNotEmpty) '“${alert.query}”',
    if (alert.type != null) jobTypes[alert.type] ?? alert.type!,
    if (alert.modality != null)
      jobModalities[alert.modality] ?? alert.modality!,
    if ((alert.location ?? '').isNotEmpty) alert.location!,
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final alerts = _alerts;

    return Material(
      color: palette.card,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Brand.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Mis alertas',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.title,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (alerts == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Aún no tienes alertas. Elige filtros y toca "Avisarme de '
                  'ofertas así".',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    color: palette.muted,
                  ),
                ),
              )
            else
              for (final alert in alerts)
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.bellRinging,
                    color: Brand.blue,
                  ),
                  title: Text(
                    _describe(alert),
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontWeight: FontWeight.w600,
                      color: palette.title,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Borrar alerta',
                    icon: const Icon(
                      PhosphorIconsRegular.trash,
                      color: Brand.danger,
                    ),
                    onPressed: () async {
                      await ProfessionalService.deleteAlert(alert.id);
                      if (mounted) setState(() => alerts.remove(alert));
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
