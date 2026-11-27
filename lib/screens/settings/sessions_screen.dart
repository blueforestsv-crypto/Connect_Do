import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/services/privacy_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Dónde está abierta mi cuenta; cerrar sesiones en otros dispositivos.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<ActiveSession>? _sessions;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await PrivacyService.sessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
      if (mounted) setState(() => _sessions = []);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        showAuthMessage(context, done, type: AuthMessageType.success);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        showAuthMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final sessions = _sessions;
    final others = sessions?.where((s) => !s.isCurrent).length ?? 0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Sesiones activas'),
      body:
          sessions == null
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final s in sessions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BrandCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: Icon(
                              s.deviceName.contains('web')
                                  ? PhosphorIconsRegular.globe
                                  : PhosphorIconsRegular.deviceMobile,
                              color: s.isCurrent ? Brand.blue : palette.muted,
                            ),
                            title: Text(
                              s.deviceName,
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontWeight: FontWeight.w700,
                                color: palette.title,
                              ),
                            ),
                            subtitle: Text(
                              s.isCurrent
                                  ? 'Este dispositivo'
                                  : 'Último uso: ${formatChatDate((s.lastUsedAt ?? s.createdAt)?.toIso8601String())}',
                              style: TextStyle(
                                fontFamily: Brand.displayFont,
                                fontSize: 12.5,
                                color: s.isCurrent ? Brand.blue : palette.muted,
                              ),
                            ),
                            trailing:
                                s.isCurrent
                                    ? null
                                    : IconButton(
                                      tooltip: 'Cerrar esta sesión',
                                      onPressed:
                                          _busy
                                              ? null
                                              : () => _run(
                                                () =>
                                                    PrivacyService.revoke(s.id),
                                                'Sesión cerrada',
                                              ),
                                      icon: const Icon(
                                        PhosphorIconsRegular.signOut,
                                        color: Brand.danger,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    if (others > 0) ...[
                      const SizedBox(height: 8),
                      OutlineActionButton(
                        text: 'Cerrar todas las demás',
                        icon: PhosphorIconsRegular.signOut,
                        onPressed:
                            _busy
                                ? null
                                : () => _run(
                                  PrivacyService.revokeOthers,
                                  'Listo: solo queda este dispositivo',
                                ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Al cerrar una sesión, ese dispositivo deberá iniciar '
                      'sesión otra vez (en menos de 30 minutos).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 12.5,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
