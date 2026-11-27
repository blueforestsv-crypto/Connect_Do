import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/settings/sessions_screen.dart';
import 'package:connect_do/services/privacy_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Quién me escribe, quién ve mis historias, en línea, sesiones y mis datos.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  PrivacySettings? _settings;
  bool _saving = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    PrivacyService.get()
        .then((value) {
          if (mounted) setState(() => _settings = value);
        })
        .catchError((Object e) {
          if (mounted) {
            setState(
              () => _error = e.toString().replaceFirst('Exception: ', ''),
            );
          }
        });
  }

  Future<void> _save({
    String? messagePrivacy,
    String? storyPrivacy,
    bool? showPresence,
  }) async {
    setState(() => _saving = true);
    try {
      final updated = await PrivacyService.update(
        messagePrivacy: messagePrivacy,
        storyPrivacy: storyPrivacy,
        showPresence: showPresence,
      );
      if (mounted) setState(() => _settings = updated);
    } catch (_) {
      if (mounted) showAuthMessage(context, 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await PrivacyService.exportAndShare();
    } catch (e) {
      if (mounted) {
        showAuthMessage(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final settings = _settings;

    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: palette.muted,
        ),
      ),
    );

    Widget options({
      required String value,
      required Map<String, (String, String)> choices,
      required ValueChanged<String> onChanged,
    }) => BrandCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in choices.entries)
            ListTile(
              leading: Icon(
                entry.key == value
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsRegular.circle,
                color: entry.key == value ? Brand.blue : palette.muted,
              ),
              onTap:
                  _saving || entry.key == value
                      ? null
                      : () => onChanged(entry.key),
              title: Text(
                entry.value.$1,
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontWeight: FontWeight.w600,
                  color: palette.title,
                ),
              ),
              subtitle:
                  entry.value.$2.isEmpty
                      ? null
                      : Text(
                        entry.value.$2,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Privacidad'),
      body:
          settings == null
              ? Center(
                child:
                    _error != null
                        ? Text(_error!)
                        : const CircularProgressIndicator(color: Brand.blue),
              )
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  title('Quién puede escribirme'),
                  options(
                    value: settings.messagePrivacy,
                    choices: const {
                      'contacts': (
                        'Solo mis contactos',
                        'Y quienes ya tienen una conversación contigo',
                      ),
                      'everyone': (
                        'Cualquier persona',
                        'Útil si buscas empleo o clientes',
                      ),
                    },
                    onChanged: (v) => _save(messagePrivacy: v),
                  ),
                  title('Quién ve mis historias'),
                  options(
                    value: settings.storyPrivacy,
                    choices: const {
                      'contacts': ('Solo mis contactos', ''),
                      'followers': (
                        'Contactos y seguidores',
                        'Quienes te siguen también las verán',
                      ),
                    },
                    onChanged: (v) => _save(storyPrivacy: v),
                  ),
                  title('Estado'),
                  BrandCard(
                    padding: EdgeInsets.zero,
                    child: SwitchListTile.adaptive(
                      value: settings.showPresence,
                      activeTrackColor: Brand.blue,
                      onChanged: _saving ? null : (v) => _save(showPresence: v),
                      title: Text(
                        'Mostrar "en línea" y "últ. vez"',
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontWeight: FontWeight.w600,
                          color: palette.title,
                        ),
                      ),
                      subtitle: Text(
                        'Si lo apagas, tus contactos no sabrán cuándo te conectas.',
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ),
                  title('Seguridad'),
                  BrandCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            PhosphorIconsRegular.devices,
                            color: Brand.blue,
                          ),
                          title: Text(
                            'Sesiones activas',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontWeight: FontWeight.w600,
                              color: palette.title,
                            ),
                          ),
                          subtitle: const Text('Dónde está abierta tu cuenta'),
                          trailing: const Icon(PhosphorIconsRegular.caretRight),
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SessionsScreen(),
                                ),
                              ),
                        ),
                        ListTile(
                          leading: const Icon(
                            PhosphorIconsRegular.downloadSimple,
                            color: Brand.blue,
                          ),
                          title: Text(
                            'Descargar mis datos',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontWeight: FontWeight.w600,
                              color: palette.title,
                            ),
                          ),
                          subtitle: const Text(
                            'Una copia de tu cuenta, publicaciones y mensajes',
                          ),
                          trailing:
                              _exporting
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Brand.blue,
                                    ),
                                  )
                                  : const Icon(PhosphorIconsRegular.caretRight),
                          onTap: _exporting ? null : _export,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
