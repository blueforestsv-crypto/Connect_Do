import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/models/contact_request_model.dart';
import 'package:connect_do/services/contact_service.dart';
import 'package:connect_do/utils/responsive_helper.dart';

class ContactsScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool showAppBar;

  const ContactsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.showAppBar = true,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;

  String _currentUserId = '';
  String _searchQuery = '';

  List<ContactRequestModel> _contacts = [];
  List<ContactRequestModel> _receivedRequests = [];
  List<ContactRequestModel> _sentRequests = [];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    _loadContactsData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadContactsData() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('usuario_actual');

    if (userJson == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      return;
    }

    final userData = jsonDecode(userJson);
    final email = userData['email'] ?? 'local_user';

    final requests = await ContactService.getRequests();

    final contacts =
        requests.where((request) {
          final isMine =
              request.requesterId == email || request.receiverId == email;

          return isMine && request.status == 'accepted';
        }).toList();

    final received =
        requests.where((request) {
          return request.receiverId == email && request.status == 'pending';
        }).toList();

    final sent =
        requests.where((request) {
          return request.requesterId == email && request.status == 'pending';
        }).toList();

    if (!mounted) return;

    setState(() {
      _currentUserId = email;
      _contacts = contacts;
      _receivedRequests = received;
      _sentRequests = sent;
      isLoading = false;
    });
  }

  Future<void> _acceptRequest(ContactRequestModel request) async {
    await ContactService.acceptRequest(request.id);
    await _loadContactsData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud aceptada'),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  Future<void> _rejectRequest(ContactRequestModel request) async {
    await ContactService.rejectRequest(request.id);
    await _loadContactsData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitud rechazada'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  List<ContactRequestModel> get _filteredContacts {
    if (_searchQuery.isEmpty) {
      return _contacts;
    }

    return _contacts.where((request) {
      final isRequester = request.requesterId == _currentUserId;

      final name = isRequester ? request.receiverName : request.requesterName;

      return name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<ContactRequestModel> get _filteredReceivedRequests {
    if (_searchQuery.isEmpty) {
      return _receivedRequests;
    }

    return _receivedRequests.where((request) {
      return request.requesterName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<ContactRequestModel> get _filteredSentRequests {
    if (_searchQuery.isEmpty) {
      return _sentRequests;
    }

    return _sentRequests.where((request) {
      return request.receiverName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,

      appBar:
          widget.showAppBar
              ? AppBar(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text(
                  'Mi red',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,

      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF22C55E)),
              )
              : DefaultTabController(
                length: 3,
                initialIndex: widget.initialTabIndex,
                child: Column(
                  children: [
                    _buildSearchBar(isDarkMode),

                    Container(
                      color: bgColor,
                      child: TabBar(
                        indicatorColor: const Color(0xFF2563EB),
                        labelColor:
                            isDarkMode ? Colors.white : const Color(0xFF2563EB),
                        unselectedLabelColor:
                            isDarkMode
                                ? Colors.grey.shade400
                                : const Color(0xFF22C55E),
                        tabs: [
                          Tab(text: 'Contactos (${_filteredContacts.length})'),
                          Tab(
                            text:
                                'Recibidas (${_filteredReceivedRequests.length})',
                          ),
                          Tab(
                            text: 'Enviadas (${_filteredSentRequests.length})',
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildContactsList(textColor, isDarkMode),
                          _buildReceivedRequests(textColor, isDarkMode),
                          _buildSentRequests(textColor, isDarkMode),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    final inputColor =
        isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final hintColor = isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: inputColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textColor),
          cursorColor: const Color(0xFF22C55E),
          decoration: InputDecoration(
            hintText: 'Buscar contactos...',
            hintStyle: TextStyle(color: hintColor),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color:
                            isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                      ),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactsList(Color textColor, bool isDarkMode) {
    final contacts = _filteredContacts;

    if (contacts.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos contactos',
          subtitle: 'Prueba con otro nombre.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.people_alt_outlined,
        title: 'Aún no tienes contactos',
        subtitle: 'Cuando aceptes solicitudes aparecerán aquí.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final request = contacts[index];

          final isRequester = request.requesterId == _currentUserId;

          final name =
              isRequester ? request.receiverName : request.requesterName;

          final photo =
              isRequester ? request.receiverPhoto : request.requesterPhoto;

          return _buildUserTile(
            name: name,
            photo: photo,
            subtitle: 'Contacto',
            trailing: const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildReceivedRequests(Color textColor, bool isDarkMode) {
    final receivedRequests = _filteredReceivedRequests;

    if (receivedRequests.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos solicitudes',
          subtitle: 'Prueba con otro nombre.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'No tienes solicitudes',
        subtitle: 'Las solicitudes que recibas aparecerán aquí.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: receivedRequests.length,
        itemBuilder: (context, index) {
          final request = receivedRequests[index];

          return _buildRequestTile(
            request: request,
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildSentRequests(Color textColor, bool isDarkMode) {
    final sentRequests = _filteredSentRequests;

    if (sentRequests.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off,
          title: 'No encontramos solicitudes',
          subtitle: 'Prueba con otro nombre.',
          isDarkMode: isDarkMode,
        );
      }

      return _buildEmptyState(
        icon: Icons.outgoing_mail,
        title: 'No has enviado solicitudes',
        subtitle: 'Cuando contactes a alguien aparecerá aquí.',
        isDarkMode: isDarkMode,
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ResponsiveHelper.appBottomNavSpace(context),
        ),
        itemCount: sentRequests.length,
        itemBuilder: (context, index) {
          final request = sentRequests[index];

          return _buildUserTile(
            name: request.receiverName,
            photo: request.receiverPhoto,
            subtitle: 'Solicitud pendiente',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Pendiente',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            textColor: textColor,
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  Widget _buildRequestTile({
    required ContactRequestModel request,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildAvatar(request.requesterPhoto),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.requesterName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  'Quiere agregarte como contacto',
                  style: TextStyle(
                    color:
                        isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectRequest(request),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptRequest(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile({
    required String name,
    required String photo,
    required String subtitle,
    required Widget trailing,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: _buildAvatar(photo),
        title: Text(
          name,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildAvatar(String photo) {
    if (photo.isEmpty) {
      return const CircleAvatar(
        radius: 25,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(Icons.person, color: Colors.grey),
      );
    }

    if (photo.startsWith('/')) {
      return CircleAvatar(radius: 25, backgroundImage: FileImage(File(photo)));
    }

    return CircleAvatar(
      radius: 25,
      backgroundImage: NetworkImage(photo),
      onBackgroundImageError: (_, __) {},
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return RefreshIndicator(
      color: const Color(0xFF22C55E),
      onRefresh: _loadContactsData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: ResponsiveHelper.appBottomNavSpace(context),
        ),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),

          Icon(
            icon,
            size: 65,
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 35),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
