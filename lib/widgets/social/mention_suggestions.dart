import 'package:flutter/material.dart';

import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

/// Lleva la cuenta de a quién se mencionó con @ en un texto.
class MentionTracker {
  final List<Map<String, String>> _picked = [];

  void add(String id, String name) {
    if (_picked.any((m) => m['id'] == id)) return;
    _picked.add({'id': id, 'name': name});
  }

  /// Ids de las menciones que siguen en el texto (si las borró, no cuentan).
  List<String> idsIn(String text) => [
    for (final m in _picked)
      if (text.contains('@${m['name']}')) m['id']!,
  ];

  void clear() => _picked.clear();
}

/// Mientras se escribe "@Ana…", muestra los contactos que coinciden; al
/// tocar uno se completa el nombre en el texto.
class MentionSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final MentionTracker tracker;

  const MentionSuggestions({
    super.key,
    required this.controller,
    required this.tracker,
  });

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  static List<({String id, String name, String photo})>? _contacts;

  String? _query;
  int _atIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _loadContacts();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _loadContacts() async {
    if (_contacts != null) return;
    try {
      final data = await ContactService.getAcceptedContacts();
      _contacts = [
        for (final c in data)
          (
            id: c['id']?.toString() ?? '',
            name: '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim(),
            photo: c['profile_image_base64']?.toString() ?? '',
          ),
      ];
      if (mounted) setState(() {});
    } catch (_) {
      _contacts = [];
    }
  }

  void _onChanged() {
    final value = widget.controller.value;
    final cursor = value.selection.baseOffset;
    if (cursor < 0) return _set(null, -1);
    final before = value.text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0 || (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1]))) {
      return _set(null, -1);
    }
    final query = before.substring(at + 1);
    if (query.contains('\n') || query.length > 30) return _set(null, -1);
    _set(query, at);
  }

  void _set(String? query, int at) {
    if (query == _query && at == _atIndex) return;
    setState(() {
      _query = query;
      _atIndex = at;
    });
  }

  void _pick(({String id, String name, String photo}) contact) {
    final value = widget.controller.value;
    final cursor = value.selection.baseOffset;
    final text = value.text;
    final insert = '@${contact.name} ';
    final updated = text.replaceRange(_atIndex, cursor, insert);
    widget.tracker.add(contact.id, contact.name);
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: _atIndex + insert.length),
    );
    _set(null, -1);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final contacts = _contacts;
    if (query == null || contacts == null) return const SizedBox.shrink();

    final q = query.toLowerCase();
    final matches =
        contacts
            .where((c) => c.name.isNotEmpty && c.name.toLowerCase().contains(q))
            .take(8)
            .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    final palette = AuthPalette.of(context);
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final contact in matches)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: UserAvatar(
                  name: contact.name,
                  photo: contact.photo,
                  radius: 12,
                ),
                label: Text(
                  contact.name,
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontWeight: FontWeight.w600,
                    color: palette.title,
                  ),
                ),
                onPressed: () => _pick(contact),
              ),
            ),
        ],
      ),
    );
  }
}
