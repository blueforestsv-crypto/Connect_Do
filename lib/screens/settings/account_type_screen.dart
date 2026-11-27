import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/services/auth_service.dart';
import 'package:connect_do/services/professional_service.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/common/verified_badge.dart';

/// Elegir entre cuenta de estudiante o de empresa. Solo las empresas
/// publican empleos y pasantías; las verificadas llevan la insignia ✓.
class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  static const _sizes = ['1-10', '11-50', '51-200', '201-500', '500+'];

  final _name = TextEditingController();
  final _sector = TextEditingController();
  String? _size;

  String _type = 'student';
  String _savedType = 'student';
  bool _verified = false;
  bool _requested = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _sector.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await AuthService.refreshAccount();
    final user = await UserService.getUser();
    final profile = await ProfileService.getMyProfile();
    if (!mounted) return;
    setState(() {
      _type = _savedType = user['account_type']?.toString() ?? 'student';
      _verified = user['company_verified'] == true;
      _name.text = profile?['company_name']?.toString() ?? '';
      _sector.text = profile?['company_sector']?.toString() ?? '';
      _size = profile?['company_size']?.toString();
      if (!_sizes.contains(_size)) _size = null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_type == 'company' && _name.text.trim().length < 2) {
      showAuthMessage(context, 'Escribe el nombre de la empresa.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ProfessionalService.setAccountType(
        accountType: _type,
        companyName: _type == 'company' ? _name.text.trim() : null,
        sector: _sector.text.trim(),
        size: _size,
      );
      await AuthService.refreshAccount();
      if (!mounted) return;
      setState(() {
        _savedType = result['account_type']?.toString() ?? _type;
        _verified = result['company_verified'] == true;
        _requested = result['verification_requested'] == true;
      });
      showAuthMessage(
        context,
        _type == 'company'
            ? 'Ahora eres una cuenta de empresa'
            : 'Ahora eres una cuenta personal',
        type: AuthMessageType.success,
      );
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestVerification() async {
    setState(() => _saving = true);
    try {
      await ProfessionalService.requestVerification();
      if (!mounted) return;
      setState(() => _requested = true);
      showAuthMessage(
        context,
        'Listo. Revisaremos tu empresa y te avisaremos.',
        type: AuthMessageType.success,
      );
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Tipo de cuenta'),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Option(
                    selected: _type == 'student',
                    icon: PhosphorIconsRegular.student,
                    title: 'Personal',
                    subtitle:
                        'Estudiantes y profesionales: postúlate, conecta y '
                        'publica.',
                    onTap: () => setState(() => _type = 'student'),
                  ),
                  const SizedBox(height: 10),
                  _Option(
                    selected: _type == 'company',
                    icon: PhosphorIconsRegular.buildings,
                    title: 'Empresa',
                    subtitle:
                        'Publica empleos y pasantías y recibe postulaciones.',
                    onTap: () => setState(() => _type = 'company'),
                  ),
                  if (_type == 'company') ...[
                    const SizedBox(height: 20),
                    AuthTextField(
                      controller: _name,
                      label: 'Nombre de la empresa',
                      hint: 'Tech SV',
                      icon: PhosphorIconsRegular.buildings,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _sector,
                      label: 'Sector (opcional)',
                      hint: 'Tecnología, banca, salud…',
                      icon: PhosphorIconsRegular.tag,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 14),
                    const AuthFieldLabel('Tamaño (opcional)'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in _sizes)
                          ChoiceChip(
                            label: Text('$size personas'),
                            selected: _size == size,
                            onSelected:
                                (v) => setState(() => _size = v ? size : null),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(
                    text: 'Guardar',
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                  if (_savedType == 'company') ...[
                    const SizedBox(height: 24),
                    BrandCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              VerifiedBadge(verified: _verified, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                _verified
                                    ? 'Empresa verificada'
                                    : 'Empresa sin verificar',
                                style: TextStyle(
                                  fontFamily: Brand.displayFont,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: palette.title,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _verified
                                ? 'Tus ofertas llevan la insignia ✓, así los '
                                    'estudiantes saben que son reales.'
                                : 'Las empresas verificadas generan más '
                                    'confianza. Para pedirla, completa en tu '
                                    'perfil el logo, la descripción y el sitio '
                                    'web.',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 13.5,
                              height: 1.4,
                              color: palette.body,
                            ),
                          ),
                          if (!_verified) ...[
                            const SizedBox(height: 12),
                            OutlineActionButton(
                              text:
                                  _requested
                                      ? 'Verificación pedida'
                                      : 'Pedir verificación',
                              icon: PhosphorIconsRegular.sealCheck,
                              onPressed:
                                  _requested || _saving
                                      ? null
                                      : _requestVerification,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
    );
  }
}

class _Option extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Option({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Material(
      color: selected ? Brand.blue.withValues(alpha: 0.08) : palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? Brand.blue : palette.cardBorder,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Brand.blue : palette.muted,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 13,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsRegular.circle,
                color: selected ? Brand.blue : palette.fieldBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
