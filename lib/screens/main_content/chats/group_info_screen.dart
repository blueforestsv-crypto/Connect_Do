import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/screens/main_content/chats/chat_media_screen.dart';
import 'package:connect_do/screens/main_content/chats/individual_chat_screen.dart';
import 'package:connect_do/screens/people/user_profile_screen.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/services/group_service.dart';
import 'package:connect_do/services/user_service.dart';
import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';
import 'package:connect_do/widgets/common/brand_bits.dart';
import 'package:connect_do/widgets/feed/user_avatar.dart';

String _contactName(Map<String, dynamic> c) =>
    '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();

/// Elegir varios contactos (para crear un grupo o agregar miembros).
class _ContactChooser extends StatefulWidget {
  final Set<String> exclude;
  final ValueChanged<Set<String>> onChanged;

  const _ContactChooser({required this.exclude, required this.onChanged});

  @override
  State<_ContactChooser> createState() => _ContactChooserState();
}

class _ContactChooserState extends State<_ContactChooser> {
  List<Map<String, dynamic>>? _contacts;
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    ContactService.getAcceptedContacts()
        .then((list) {
          if (mounted) setState(() => _contacts = list);
        })
        .catchError((_) {
          if (mounted) setState(() => _contacts = []);
        });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final contacts =
        (_contacts ?? [])
            .where((c) => !widget.exclude.contains(c['id'].toString()))
            .where(
              (c) =>
                  _contactName(c).toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              hintText: 'Buscar contacto…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child:
              _contacts == null
                  ? const Center(
                    child: CircularProgressIndicator(color: Brand.blue),
                  )
                  : contacts.isEmpty
                  ? Center(
                    child: Text(
                      'No hay contactos para agregar.',
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        color: palette.muted,
                      ),
                    ),
                  )
                  : ListView(
                    children: [
                      for (final c in contacts)
                        CheckboxListTile(
                          value: _selected.contains(c['id'].toString()),
                          activeColor: Brand.blue,
                          secondary: UserAvatar(
                            name: _contactName(c),
                            photo: c['profile_image_base64']?.toString() ?? '',
                          ),
                          title: Text(
                            _contactName(c),
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontWeight: FontWeight.w600,
                              color: palette.title,
                            ),
                          ),
                          onChanged: (checked) {
                            setState(() {
                              final id = c['id'].toString();
                              checked == true
                                  ? _selected.add(id)
                                  : _selected.remove(id);
                            });
                            widget.onChanged({..._selected});
                          },
                        ),
                    ],
                  ),
        ),
      ],
    );
  }
}

/// Crear un grupo: nombre y contactos.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  Set<String> _members = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      final group = await GroupService.create(
        _name.text.trim(),
        _members.toList(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => IndividualChatScreen(
                chatId: group.id,
                chatName: group.name,
                chatAvatar: group.photoUrl,
                isGroup: true,
              ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAuthMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final ready = _name.text.trim().isNotEmpty && _members.isNotEmpty;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Nuevo grupo'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: AuthTextField(
              controller: _name,
              label: 'Nombre del grupo',
              hint: 'Ej.: Tesis 2026',
              icon: PhosphorIconsRegular.usersThree,
              maxLength: 80,
              enabled: !_saving,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _members.isEmpty
                    ? 'Elige a tus contactos'
                    : '${_members.length} seleccionado${_members.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontFamily: Brand.displayFont,
                  fontWeight: FontWeight.w600,
                  color: palette.muted,
                ),
              ),
            ),
          ),
          Expanded(
            child: _ContactChooser(
              exclude: const {},
              onChanged: (ids) => setState(() => _members = ids),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                text: 'Crear grupo',
                isLoading: _saving,
                onPressed: ready ? _create : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miembros, nombre y salir del grupo.
class GroupInfoScreen extends StatefulWidget {
  final String groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  ChatGroup? _group;
  String _myId = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _myId = (await UserService.getUser())['id']?.toString() ?? '';
    try {
      final group = await GroupService.get(widget.groupId);
      if (mounted) setState(() => _group = group);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
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

  Future<void> _rename() async {
    final controller = TextEditingController(text: _group!.name);
    final name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Nombre del grupo'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
    if (name == null || name.isEmpty || name == _group!.name) return;
    await _run(() async {
      final group = await GroupService.rename(widget.groupId, name);
      if (mounted) setState(() => _group = group);
    });
  }

  Future<void> _addMembers() async {
    Set<String> chosen = {};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AuthPalette.of(sheetContext);
        return Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Brand.radiusLg),
          ),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: _ContactChooser(
                    exclude: {for (final m in _group!.members) m.id},
                    onChanged: (ids) => chosen = ids,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GradientButton(
                      text: 'Agregar',
                      onPressed: () => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true || chosen.isEmpty) return;
    await _run(() async {
      final group = await GroupService.addMembers(
        widget.groupId,
        chosen.toList(),
      );
      if (mounted) setState(() => _group = group);
    });
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  action,
                  style: const TextStyle(color: Brand.danger),
                ),
              ),
            ],
          ),
    );
    return ok == true;
  }

  Future<void> _remove(GroupPerson member) async {
    if (!await _confirm(
      '¿Sacar a ${member.name}?',
      'Ya no verá los mensajes nuevos del grupo.',
      'Sacar',
    )) {
      return;
    }
    await _run(() async {
      await GroupService.removeMember(widget.groupId, member.id);
      await _load();
    });
  }

  Future<void> _leave() async {
    if (!await _confirm(
      '¿Salir del grupo?',
      'Dejarás de recibir sus mensajes.',
      'Salir',
    )) {
      return;
    }
    await _run(() async {
      await GroupService.removeMember(widget.groupId, _myId);
      if (!mounted) return;
      // Cierra la info y el chat del grupo.
      Navigator.of(context)
        ..pop()
        ..pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final group = _group;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: brandAppBar(context, 'Información del grupo'),
      body:
          group == null
              ? const Center(
                child: CircularProgressIndicator(color: Brand.blue),
              )
              : AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    Center(
                      child: UserAvatar(
                        name: group.name,
                        photo: group.photoUrl,
                        radius: 42,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: palette.title,
                            ),
                          ),
                        ),
                        if (group.iAmAdmin)
                          IconButton(
                            tooltip: 'Cambiar nombre',
                            onPressed: _rename,
                            icon: const Icon(
                              PhosphorIconsRegular.pencilSimple,
                              color: Brand.blue,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${group.members.length} miembros',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Brand.blue.withValues(alpha: 0.12),
                        child: const Icon(
                          PhosphorIconsRegular.folderSimple,
                          color: Brand.blue,
                        ),
                      ),
                      title: Text(
                        'Archivos, enlaces y documentos',
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontWeight: FontWeight.w700,
                          color: palette.title,
                        ),
                      ),
                      trailing: const Icon(PhosphorIconsRegular.caretRight),
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ChatMediaScreen(
                                    chatId: group.id,
                                    isGroup: true,
                                    title: group.name,
                                    myId: _myId,
                                  ),
                            ),
                          ),
                    ),
                    if (group.iAmAdmin)
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Brand.blue,
                          child: Icon(
                            PhosphorIconsRegular.userPlus,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'Agregar miembros',
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontWeight: FontWeight.w700,
                            color: palette.title,
                          ),
                        ),
                        onTap: _addMembers,
                      ),
                    for (final member in group.members)
                      ListTile(
                        leading: UserAvatar(
                          name: member.name,
                          photo: member.photo,
                        ),
                        title: Text(
                          member.id == _myId ? 'Tú' : member.name,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontWeight: FontWeight.w600,
                            color: palette.title,
                          ),
                        ),
                        subtitle:
                            member.isAdmin
                                ? const Text(
                                  'Administrador',
                                  style: TextStyle(color: Brand.blue),
                                )
                                : null,
                        trailing:
                            group.iAmAdmin && member.id != _myId
                                ? IconButton(
                                  tooltip: 'Sacar del grupo',
                                  onPressed: () => _remove(member),
                                  icon: const Icon(
                                    PhosphorIconsRegular.userMinus,
                                    color: Brand.danger,
                                  ),
                                )
                                : null,
                        onTap:
                            member.id == _myId
                                ? null
                                : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => UserProfileScreen(
                                          userId: member.id,
                                        ),
                                  ),
                                ),
                      ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(
                        PhosphorIconsRegular.signOut,
                        color: Brand.danger,
                      ),
                      title: const Text(
                        'Salir del grupo',
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontWeight: FontWeight.w700,
                          color: Brand.danger,
                        ),
                      ),
                      onTap: _leave,
                    ),
                  ],
                ),
              ),
    );
  }
}
