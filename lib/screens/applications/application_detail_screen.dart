import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/widgets/common/app_sheet.dart';
import 'package:connect_do/models/application_model.dart';
import 'package:connect_do/screens/applications/application_ui.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/services/application_service.dart';
import 'package:connect_do/services/profile_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Una postulación recibida, con las acciones de quien publicó.
/// Modifica [application.status] en el mismo objeto que recibe.
class ApplicationDetailScreen extends StatefulWidget {
  final ApplicationModel application;

  const ApplicationDetailScreen({super.key, required this.application});

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  ApplicationModel get _app => widget.application;

  String? _busy; // acción en curso

  @override
  void initState() {
    super.initState();
    // Abrirla cuenta como "vista": el estudiante recibe aviso.
    if (_app.status == 'new') _setStatus('reviewed', silent: true);
  }

  Future<void> _setStatus(String status, {bool silent = false}) async {
    if (_busy != null) return;
    final previous = _app.status;
    setState(() {
      _busy = status;
      _app.status = status;
    });

    try {
      await ApplicationService.updateStatus(_app.id, status);
      if (!mounted || silent) return;
      showAuthMessage(context, switch (status) {
        'interview' => 'Le avisamos que quieres entrevistarle',
        'selected' => '¡Seleccionado! Ya recibió la noticia',
        'rejected' => 'Postulación cerrada',
        _ => 'Estado actualizado',
      }, type: AuthMessageType.success);
    } catch (error) {
      if (!mounted) return;
      setState(() => _app.status = previous);
      if (!silent) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _openCv() async {
    setState(() => _busy = 'cv');
    try {
      await ProfileService.openCv(_app.studentId);
    } catch (error) {
      if (mounted) {
        showAuthMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _contact() async {
    final controller = TextEditingController(
      text:
          'Hola ${_app.studentName.split(' ').first}, vimos tu postulación a '
          '«${_app.publicationTitle}» y nos gustaría conversar contigo.',
    );

    final message = await showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Brand.radiusLg),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mensaje para ${_app.studentName}',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Le llegará a su chat y la postulación pasará a '
                  '"Contactado".',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: authFieldDecoration(palette),
                  child: TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14.5,
                      color: palette.title,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu mensaje',
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  text: 'Enviar mensaje',
                  trailingIcon: PhosphorIconsRegular.paperPlaneTilt,
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) Navigator.pop(sheetContext, text);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (message == null) return;

    setState(() => _busy = 'contact');
    try {
      await ApplicationService.contactStudent(_app.id, message);
      if (!mounted) return;
      setState(() => _app.status = 'contacted');
      showAuthMessage(
        context,
        'Mensaje enviado',
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
      if (mounted) setState(() => _busy = null);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => IndividualChatScreen(
              chatId: _app.studentId,
              chatName: _app.studentName,
              chatAvatar: _app.studentPhoto,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final snap = _app.snapshot;
    final closed = !ApplicationStatus.isOpen(_app.status);
    final contacted = _app.status != 'new' && _app.status != 'reviewed';

    final facts = <(IconData, String)>[
      if (_app.university != null)
        (PhosphorIconsRegular.graduationCap, _app.university!),
      if (_app.career != null) (PhosphorIconsRegular.books, _app.career!),
      if ((snap['academic_cycle']?.toString() ?? '').isNotEmpty)
        (PhosphorIconsRegular.calendarBlank, 'Ciclo ${snap['academic_cycle']}'),
    ];
    final bio = snap['bio']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Postulación'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          ResponsiveHelper.bottomSafe(context) + 24,
        ),
        children: [
          BrandCard(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: _app.studentId),
                  ),
                ),
            child: Column(
              children: [
                UserAvatar(
                  name: _app.studentName,
                  photo: _app.studentPhoto,
                  radius: 36,
                ),
                const SizedBox(height: 10),
                Text(
                  _app.studentName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: palette.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ver perfil completo',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Brand.blue,
                  ),
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final (icon, text) in facts)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(icon, size: 17, color: palette.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 14,
                                color: palette.label,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _app.publicationTitle,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                        ),
                      ),
                    ),
                    ApplicationStatusPill(status: _app.status),
                  ],
                ),
                const SizedBox(height: 14),
                ApplicationProgress(status: _app.status),
                if (_app.coverMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'MENSAJE',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _app.coverMessage!,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14,
                      height: 1.45,
                      color: palette.label,
                    ),
                  ),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'SOBRE MÍ',
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bio,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 14,
                      height: 1.45,
                      color: palette.label,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_app.hasCv)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlineActionButton(
                text: _busy == 'cv' ? 'Abriendo…' : 'Ver currículum',
                icon: PhosphorIconsRegular.filePdf,
                onPressed: _busy == null ? _openCv : null,
              ),
            ),
          contacted
              ? OutlineActionButton(
                text: 'Abrir chat',
                icon: PhosphorIconsRegular.chatCircle,
                onPressed: _openChat,
              )
              : GradientButton(
                text: 'Enviar mensaje',
                isLoading: _busy == 'contact',
                trailingIcon: PhosphorIconsRegular.chatCircle,
                onPressed: _busy == null ? _contact : null,
              ),
          if (!closed) ...[
            const SizedBox(height: 20),
            Text(
              'DECIDIR',
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_app.status != 'interview') ...[
                  Expanded(
                    child: _DecisionButton(
                      label: 'Entrevista',
                      icon: PhosphorIconsRegular.calendarCheck,
                      color: const Color(0xFF8B5CF6),
                      loading: _busy == 'interview',
                      onTap: () => _setStatus('interview'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _DecisionButton(
                    label: 'Seleccionar',
                    icon: PhosphorIconsRegular.sealCheck,
                    color: Brand.success,
                    loading: _busy == 'selected',
                    onTap: () => _setStatus('selected'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DecisionButton(
                    label: 'Descartar',
                    icon: PhosphorIconsRegular.x,
                    color: Brand.danger,
                    loading: _busy == 'rejected',
                    onTap: () => _setStatus('rejected'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(Brand.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Brand.radiusMd),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              loading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                  : Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
