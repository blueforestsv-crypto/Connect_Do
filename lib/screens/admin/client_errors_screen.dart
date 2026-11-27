import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/core/api/api_config.dart';
import 'package:connect_do/screens/main_content/chats/chatlist_screen.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';

/// Errores que reportaron los teléfonos (solo administradores).
class ClientErrorsScreen extends StatefulWidget {
  const ClientErrorsScreen({super.key});

  @override
  State<ClientErrorsScreen> createState() => _ClientErrorsScreenState();
}

class _ClientErrorsScreenState extends State<ClientErrorsScreen> {
  List<Map<String, dynamic>>? _errors;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/client-errors?limit=100'),
        headers: {
          'Authorization': 'Bearer ${prefs.getString('access_token') ?? ''}',
        },
      );
      if (response.statusCode != 200) throw Exception('Sin acceso');
      final list = [
        for (final e in jsonDecode(utf8.decode(response.bodyBytes)) as List)
          Map<String, dynamic>.from(e as Map),
      ];
      if (mounted) setState(() => _errors = list);
    } catch (e) {
      if (mounted) {
        setState(() => _problem = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final errors = _errors;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Errores de la app'),
      body:
          errors == null
              ? Center(
                child:
                    _problem != null
                        ? Text(_problem!)
                        : const CircularProgressIndicator(color: Brand.blue),
              )
              : RefreshIndicator(
                color: Brand.blue,
                onRefresh: _load,
                child:
                    errors.isEmpty
                        ? const EmptyState(
                          icon: PhosphorIconsRegular.checkCircle,
                          title: 'Sin errores',
                          subtitle: 'Ningún teléfono reportó fallas (30 días).',
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: errors.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final e = errors[i];
                            final stack = e['stack']?.toString() ?? '';
                            return BrandCard(
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  e['message']?.toString() ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: Brand.displayFont,
                                    fontWeight: FontWeight.w600,
                                    color: palette.title,
                                  ),
                                ),
                                subtitle: Text(
                                  '${e['platform'] ?? '?'} · v${e['app_version'] ?? '?'} · '
                                  '${formatChatDate(e['created_at']?.toString())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.muted,
                                  ),
                                ),
                                children: [
                                  if (stack.isNotEmpty)
                                    SelectableText(
                                      stack.length > 3000
                                          ? stack.substring(0, 3000)
                                          : stack,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: '${e['message']}\n$stack',
                                        ),
                                      );
                                      showAuthMessage(context, 'Copiado');
                                    },
                                    icon: const Icon(PhosphorIconsRegular.copy),
                                    label: const Text('Copiar'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
    );
  }
}
