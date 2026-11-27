import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:connect_do/widgets/profile/profile_entries_section.dart';
import 'package:connect_do/widgets/common/verified_badge.dart';
import 'package:connect_do/services/professional_service.dart';
import 'package:connect_do/widgets/safety/report_sheet.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/screens/people/user_posts_screen.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Perfil de cualquier persona (también el propio, "como lo ven los demás").
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _profile;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ProfileService.getPublicProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _text(String key) {
    final value = _profile?[key]?.toString().trim() ?? '';
    return value == 'null' ? '' : value;
  }

  String get _name => '${_text('first_name')} ${_text('last_name')}'.trim();
  String get _status => _text('contact_status');

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) {
        showAuthMessage(context, success, type: AuthMessageType.success);
      }
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleEndorse(SkillDetail skill) async {
    final endorse = !skill.endorsedByMe;
    setState(() {
      skill.endorsedByMe = endorse;
      skill.count += endorse ? 1 : -1;
    });
    try {
      final updated = await ProfessionalService.endorse(
        widget.userId,
        skill.name,
        endorse: endorse,
      );
      if (!mounted) return;
      setState(() {
        _profile!['skill_details'] = [
          for (final s in updated)
            {
              'name': s.name,
              'count': s.count,
              'endorsed_by_me': s.endorsedByMe,
            },
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        skill.endorsedByMe = !endorse;
        skill.count += endorse ? -1 : 1;
      });
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _connect() => _run(
    () => ContactService.sendContactRequest(receiverId: widget.userId),
    'Solicitud enviada',
  );

  void _accept() => _run(
    () => ContactService.acceptRequest(_text('contact_request_id')),
    '¡Ahora son contactos!',
  );

  Future<void> _openCv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ProfileService.openCv(widget.userId);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => IndividualChatScreen(
              chatId: widget.userId,
              chatName: _name,
              chatAvatar: _text('profile_image_base64'),
            ),
      ),
    );
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(
      value.startsWith('http') ? value : 'https://$value',
    );
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showAuthMessage(context, 'No se pudo abrir el enlace.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(
        context,
        _profile == null ? 'Perfil' : _name,
        actions: [
          if (_profile != null && _profile!['is_me'] != true)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              icon: Icon(
                PhosphorIconsRegular.dotsThreeVertical,
                color: palette.title,
              ),
              onSelected: (value) async {
                if (value == 'report') {
                  showReportSheet(
                    context,
                    targetType: 'user',
                    targetId: widget.userId,
                  );
                } else if (value == 'block') {
                  final blocked = await confirmBlock(
                    context,
                    userId: widget.userId,
                    name: _name,
                  );
                  if (blocked && context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(value: 'report', child: Text('Reportar')),
                    PopupMenuItem(
                      value: 'block',
                      child: Text(
                        'Bloquear',
                        style: TextStyle(color: Brand.danger),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body:
          _profile == null
              ? (_error == null
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: Brand.blue,
                      strokeWidth: 2.5,
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _load,
                    child: EmptyState(
                      icon: PhosphorIconsRegular.userCircleDashed,
                      title: 'No se pudo abrir',
                      subtitle: _error!,
                    ),
                  ))
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child: _buildBody(palette),
              ),
    );
  }

  Widget _buildBody(AuthPalette palette) {
    final isMe = _profile!['is_me'] == true;
    final limited = _profile!['limited'] == true;
    final hasCv = _profile!['has_cv'] == true;
    final skills =
        (_profile!['skills'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
    final skillDetails = [
      for (final item in (_profile!['skill_details'] as List? ?? const []))
        SkillDetail.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    final entries = [
      for (final item in (_profile!['entries'] as List? ?? const []))
        ProfileEntry.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
    final isCompany = _profile!['account_type'] == 'company';
    final canEndorse = !isMe && _status == 'accepted';

    final academic = <(IconData, String)>[
      if (_text('university').isNotEmpty)
        (PhosphorIconsRegular.graduationCap, _text('university')),
      if (_text('career').isNotEmpty)
        (PhosphorIconsRegular.books, _text('career')),
      if (_text('academic_level').isNotEmpty)
        (PhosphorIconsRegular.student, _text('academic_level')),
      if (_text('academic_cycle').isNotEmpty)
        (
          PhosphorIconsRegular.calendarBlank,
          'Ciclo ${_text('academic_cycle')}',
        ),
    ];

    final contact = <(IconData, String)>[
      if (_text('email').isNotEmpty)
        (PhosphorIconsRegular.envelopeSimple, _text('email')),
      if (_text('phone').isNotEmpty)
        (PhosphorIconsRegular.phone, _text('phone')),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        ResponsiveHelper.bottomSafe(context) + 24,
      ),
      children: [
        BrandCard(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              UserAvatar(
                name: _name,
                photo: _text('profile_image_base64'),
                radius: 44,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: palette.title,
                      ),
                    ),
                  ),
                  if (isCompany) ...[
                    const SizedBox(width: 6),
                    VerifiedBadge(
                      verified: _profile!['company_verified'] == true,
                      size: 20,
                    ),
                  ],
                ],
              ),
              if (_text('headline').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _text('headline'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.label,
                  ),
                ),
              ],
              if (isCompany &&
                  (_text('company_sector').isNotEmpty ||
                      _text('company_size').isNotEmpty)) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (_text('company_sector').isNotEmpty)
                      _text('company_sector'),
                    if (_text('company_size').isNotEmpty)
                      '${_text('company_size')} personas',
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    color: palette.muted,
                  ),
                ),
              ],
              if (!isCompany && _text('career').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    _text('career'),
                    if (_text('university').isNotEmpty) _text('university'),
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13.5,
                    color: palette.muted,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (isMe)
                Text(
                  'Así ven tu perfil las demás personas.',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13,
                    color: palette.muted,
                  ),
                )
              else
                _buildActions(),
            ],
          ),
        ),
        if (limited)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: BrandCard(
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.lockKey,
                    size: 30,
                    color: palette.muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Perfil privado',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.title,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cuando acepte tu solicitud podrás ver su información y '
                    'sus publicaciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 13.5,
                      height: 1.4,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!limited)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: BrandCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _InfoRow(
                PhosphorIconsRegular.newspaper,
                isMe ? 'Ver mis publicaciones' : 'Ver sus publicaciones',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => UserPostsScreen(
                              userId: widget.userId,
                              userName: _name,
                            ),
                      ),
                    ),
              ),
            ),
          ),
        if (_text('bio').isNotEmpty)
          _Section(
            title: isCompany ? 'Sobre la empresa' : 'Sobre mí',
            child: Text(
              _text('bio'),
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 14.5,
                height: 1.5,
                color: palette.label,
              ),
            ),
          ),
        if (academic.isNotEmpty)
          _Section(
            title: 'Formación',
            child: Column(
              children: [for (final (i, t) in academic) _InfoRow(i, t)],
            ),
          ),
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ProfileEntriesSection(entries: entries),
          ),
        if (skills.isNotEmpty)
          _Section(
            title: 'Habilidades',
            child: Column(
              children: [
                for (final skill
                    in skillDetails.isNotEmpty
                        ? skillDetails
                        : [
                          for (final s in skills)
                            SkillDetail(name: s, count: 0, endorsedByMe: false),
                        ])
                  _SkillRow(
                    skill: skill,
                    canEndorse: canEndorse,
                    onToggle: () => _toggleEndorse(skill),
                  ),
                if (canEndorse)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Como contacto, puedes validar sus habilidades.',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12,
                        color: palette.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (hasCv || _text('portfolio_url').isNotEmpty)
          _Section(
            title: 'Trabajo',
            child: Column(
              children: [
                if (hasCv)
                  _InfoRow(
                    PhosphorIconsRegular.filePdf,
                    'Ver currículum',
                    onTap: _openCv,
                  ),
                if (_text('portfolio_url').isNotEmpty)
                  _InfoRow(
                    PhosphorIconsRegular.link,
                    _text('portfolio_url'),
                    onTap: () => _openLink(_text('portfolio_url')),
                  ),
              ],
            ),
          ),
        if (contact.isNotEmpty)
          _Section(
            title: 'Contacto',
            child: Column(
              children: [for (final (i, t) in contact) _InfoRow(i, t)],
            ),
          )
        else if (!isMe && !limited)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.lockSimple,
                  size: 15,
                  color: palette.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Su correo y teléfono se muestran solo a sus contactos.',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12.5,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActions() {
    return switch (_status) {
      'accepted' => GradientButton(
        text: 'Enviar mensaje',
        trailingIcon: PhosphorIconsRegular.chatCircle,
        onPressed: _message,
      ),
      'pending_received' => GradientButton(
        text: 'Aceptar solicitud',
        isLoading: _busy,
        trailingIcon: PhosphorIconsRegular.handshake,
        onPressed: _accept,
      ),
      'pending_sent' => const OutlineActionButton(
        text: 'Solicitud enviada',
        icon: PhosphorIconsRegular.clock,
        onPressed: null,
      ),
      _ => GradientButton(
        text: 'Conectar',
        isLoading: _busy,
        trailingIcon: PhosphorIconsRegular.userPlus,
        onPressed: _connect,
      ),
    };
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: BrandCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoRow(this.icon, this.text, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final color = onTap == null ? palette.label : Brand.blue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 18, color: onTap == null ? palette.muted : color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 14,
                  fontWeight: onTap == null ? FontWeight.w500 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (onTap != null)
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final SkillDetail skill;
  final bool canEndorse;
  final VoidCallback onToggle;

  const _SkillRow({
    required this.skill,
    required this.canEndorse,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                if (skill.count > 0)
                  Text(
                    skill.count == 1
                        ? '1 contacto lo validó'
                        : '${skill.count} contactos lo validaron',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 12,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (canEndorse)
            TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                skill.endorsedByMe
                    ? PhosphorIconsFill.sealCheck
                    : PhosphorIconsRegular.sealCheck,
                size: 18,
              ),
              label: Text(skill.endorsedByMe ? 'Validado' : 'Validar'),
            ),
        ],
      ),
    );
  }
}
