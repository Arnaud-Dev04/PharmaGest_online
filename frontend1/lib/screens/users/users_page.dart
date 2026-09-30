import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/services/user_service.dart';
import 'package:frontend1/screens/users/user_stats_page.dart';
import 'package:frontend1/widgets/users/user_form_dialog.dart';

import 'package:provider/provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/core/error_helper.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final UserService _userService = UserService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<User> _allUsers = [];
  List<User> _filteredUsers = []; // Pour l'affichage
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _userService.getUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
        _filterUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHelper.extractErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _filterUsers() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final matchesSearch = u.username.toLowerCase().contains(query);
        final matchesStatus = _statusFilter == 'all'
            ? true
            : _statusFilter == 'active'
            ? u.isActive
            : !u.isActive;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _setStatusFilter(String filter) {
    setState(() => _statusFilter = filter);
    _filterUsers();
  }

  Future<void> _toggleStatus(User user, LanguageProvider lp) async {
    final action = user.isActive
        ? lp.translate('deactivate')
        : lp.translate('activate');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${lp.translate('confirm')} $action'),
        content: Text(
          '${lp.translate('confirmAction')} $action ${user.username} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(lp.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(lp.translate('yes')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _userService.toggleStatus(user.id);
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(User user, LanguageProvider lp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lp.translate('confirmDelete')),
        content: Text(
          '${lp.translate('deleteConfirmation')} ${user.username} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lp.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(lp.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _userService.deleteUser(user.id);
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showUserDialog(LanguageProvider lp, {User? user}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserFormDialog(user: user),
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user != null
                  ? lp.translate('userUpdated')
                  : lp.translate('userCreated'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.translate('usersManagement'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_filteredUsers.length} ${languageProvider.translate('users')}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showUserDialog(languageProvider),
              icon: const Icon(Icons.person_add),
              label: Text(languageProvider.translate('newUser')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Filters
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Search
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: languageProvider.translate('searchByName'),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const VerticalDivider(),
                // Status Chips
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(languageProvider.translate('all')),
                      selected: _statusFilter == 'all',
                      onSelected: (_) => _setStatusFilter('all'),
                    ),
                    ChoiceChip(
                      label: Text(languageProvider.translate('active')),
                      selected: _statusFilter == 'active',
                      onSelected: (_) => _setStatusFilter('active'),
                      selectedColor: Colors.green.withValues(alpha: 0.2),
                      side: _statusFilter == 'active'
                          ? const BorderSide(color: Colors.green)
                          : null,
                    ),
                    ChoiceChip(
                      label: Text(languageProvider.translate('inactive')),
                      selected: _statusFilter == 'inactive',
                      onSelected: (_) => _setStatusFilter('inactive'),
                      selectedColor: Colors.red.withValues(alpha: 0.2),
                      side: _statusFilter == 'inactive'
                          ? const BorderSide(color: Colors.red)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: Card(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text('Erreur: $_error'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Desktop View
                      if (constraints.maxWidth > 800) {
                        return DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          minWidth: 800,
                          columns: [
                            DataColumn2(
                              label: Text(languageProvider.translate('user')),
                            ),
                            DataColumn2(
                              label: Text(languageProvider.translate('role')),
                            ),
                            DataColumn2(
                              label: Text(languageProvider.translate('status')),
                            ),
                            DataColumn2(
                              label: Text(
                                languageProvider.translate('createdOn'),
                              ),
                            ),
                            DataColumn2(
                              label: Text(
                                languageProvider.translate('actions'),
                              ),
                              fixedWidth: 150,
                              numeric: true,
                            ),
                          ],
                          rows: _filteredUsers
                              .map(
                                (user) => DataRow(
                                  cells: [
                                    // Utilisateur
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppTheme
                                                .primaryColor
                                                .withValues(alpha: 0.1),
                                            child: Text(
                                              user.username.isNotEmpty
                                                  ? user.username[0]
                                                        .toUpperCase()
                                                  : 'U',
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                user.username,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'ID: ${user.id}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rôle
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (user.role == 'admin'
                                                      ? Colors.purple
                                                      : Colors.blue)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          user.role == 'admin'
                                              ? languageProvider.translate(
                                                  'admin',
                                                )
                                              : languageProvider.translate(
                                                  'pharmacist',
                                                ),
                                          style: TextStyle(
                                            color: user.role == 'admin'
                                                ? Colors.purple
                                                : Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Statut
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (user.isActive
                                                      ? Colors.green
                                                      : Colors.red)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          user.isActive ? 'Actif' : 'Inactif',
                                          style: TextStyle(
                                            color: user.isActive
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Date
                                    DataCell(
                                      Text(
                                        user.createdAt != null
                                            ? DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(user.createdAt!)
                                            : '-',
                                      ),
                                    ),
                                    // Actions
                                    DataCell(
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.orange,
                                            ), // Edit Button
                                            tooltip: languageProvider.translate(
                                              'edit',
                                            ),
                                            onPressed: () => _showUserDialog(
                                              languageProvider,
                                              user: user,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.bar_chart,
                                              color: Colors.blue,
                                            ),
                                            tooltip: languageProvider.translate(
                                              'stats',
                                            ),
                                            onPressed: () {
                                              if (context.mounted) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        UserStatsPage(
                                                          userId: user.id,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.power_settings_new,
                                            ),
                                            color: user.isActive
                                                ? Colors.green
                                                : Colors.grey,
                                            tooltip: user.isActive
                                                ? languageProvider.translate(
                                                    'deactivate',
                                                  )
                                                : languageProvider.translate(
                                                    'activate',
                                                  ),
                                            onPressed: () => _toggleStatus(
                                              user,
                                              languageProvider,
                                            ),
                                          ),
                                          if (user.role != 'admin')
                                            IconButton(
                                              icon: const Icon(Icons.delete),
                                              color: Colors.red,
                                              tooltip: languageProvider
                                                  .translate('delete'),
                                              onPressed: () => _deleteUser(
                                                user,
                                                languageProvider,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        );
                      }

                      // Mobile/Tablet View (List)
                      return ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  user.username.isNotEmpty
                                      ? user.username[0].toUpperCase()
                                      : 'U',
                                ),
                              ),
                              title: Text(
                                user.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (user.role == 'admin'
                                                      ? Colors.purple
                                                      : Colors.blue)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          user.role == 'admin'
                                              ? languageProvider.translate(
                                                  'admin',
                                                )
                                              : languageProvider.translate(
                                                  'pharmacist',
                                                ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: user.role == 'admin'
                                                ? Colors.purple
                                                : Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (user.isActive
                                                      ? Colors.green
                                                      : Colors.red)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          user.isActive
                                              ? languageProvider.translate(
                                                  'active',
                                                )
                                              : languageProvider.translate(
                                                  'inactive',
                                                ),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: user.isActive
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          languageProvider.translate('edit'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'stats',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.bar_chart,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          languageProvider.translate('stats'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.power_settings_new,
                                          color: user.isActive
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          user.isActive
                                              ? languageProvider.translate(
                                                  'deactivate',
                                                )
                                              : languageProvider.translate(
                                                  'activate',
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (user.role != 'admin')
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            languageProvider.translate(
                                              'delete',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showUserDialog(
                                      languageProvider,
                                      user: user,
                                    );
                                  }
                                  if (value == 'stats') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            UserStatsPage(userId: user.id),
                                      ),
                                    );
                                  }
                                  if (value == 'toggle') {
                                    _toggleStatus(user, languageProvider);
                                  }
                                  if (value == 'delete') {
                                    _deleteUser(user, languageProvider);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
