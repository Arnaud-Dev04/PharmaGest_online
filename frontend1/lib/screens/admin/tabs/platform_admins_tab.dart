import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/services/platform_admin_service.dart';
import 'package:frontend1/widgets/dashboard/stats_card.dart';

class PlatformAdminsTab extends StatefulWidget {
  const PlatformAdminsTab({super.key});

  @override
  State<PlatformAdminsTab> createState() => _PlatformAdminsTabState();
}

class _PlatformAdminsTabState extends State<PlatformAdminsTab> {
  final PlatformAdminService _service = PlatformAdminService();
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getPlatformAdmins();
      if (mounted) {
        setState(() {
          _admins = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Nouvel Administrateur Plateforme'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant / Nom d\'utilisateur *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe initial *',
                    helperText: '8 caracteres minimum',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prenom',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lastCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telephone',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.check),
            label: const Text('Creer le Compte'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _service.createPlatformAdmin({
          'username': userCtrl.text.trim(),
          'password': passCtrl.text.trim(),
          if (firstCtrl.text.trim().isNotEmpty) 'first_name': firstCtrl.text.trim(),
          if (lastCtrl.text.trim().isNotEmpty) 'last_name': lastCtrl.text.trim(),
          if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
          if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
        });
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Administrateur cree avec succes'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.dangerColor),
          );
        }
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> admin) async {
    final firstCtrl = TextEditingController(text: admin['first_name'] ?? '');
    final lastCtrl = TextEditingController(text: admin['last_name'] ?? '');
    final emailCtrl = TextEditingController(text: admin['email'] ?? '');
    final phoneCtrl = TextEditingController(text: admin['phone'] ?? '');
    final passCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Modifier : ${admin['username']}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: firstCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prenom',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: lastCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telephone',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe (optionnel)',
                    helperText: 'Laisser vide pour ne pas modifier',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final data = <String, dynamic>{
          'first_name': firstCtrl.text.trim(),
          'last_name': lastCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
        };
        if (passCtrl.text.trim().isNotEmpty) {
          data['password'] = passCtrl.text.trim();
        }
        await _service.updatePlatformAdmin(admin['id'] as int, data);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modifications enregistrees avec succes'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.dangerColor),
          );
        }
      }
    }
  }

  void _showAdminDetailsDialog(Map<String, dynamic> admin) {
    final isSuper = admin['is_super_platform_admin'] == true;
    final isActive = admin['is_active'] == true;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSuper ? Colors.amber[800] : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(isSuper ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    admin['username']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    isSuper ? 'Super Administrateur Plateforme' : 'Administrateur Plateforme',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Identifiant', admin['username']?.toString() ?? '—'),
              _buildDetailRow('Prenom', admin['first_name']?.toString() ?? '—'),
              _buildDetailRow('Nom', admin['last_name']?.toString() ?? '—'),
              _buildDetailRow('Email', admin['email']?.toString() ?? '—'),
              _buildDetailRow('Telephone', admin['phone']?.toString() ?? '—'),
              _buildDetailRow('Role', isSuper ? 'Super Admin' : 'Admin Plateforme'),
              _buildDetailRow('Statut', isActive ? 'Actif' : 'Desactive',
                  color: isActive ? AppTheme.successColor : AppTheme.dangerColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerColor),
            const SizedBox(height: 12),
            Text('Erreur: $_error', style: const TextStyle(color: AppTheme.dangerColor)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    final activeCount = _admins.where((a) => a['is_active'] == true).length;
    final superCount = _admins.where((a) => a['is_super_platform_admin'] == true).length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouvel Administrateur'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top KPI StatsCards (Dashboard look)
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Total Administrateurs',
                  value: '${_admins.length}',
                  iconBgColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatsCard(
                  icon: Icons.shield_outlined,
                  label: 'Super Admins',
                  value: '$superCount',
                  iconBgColor: Colors.amber[800]!,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatsCard(
                  icon: Icons.check_circle_outline,
                  label: 'Comptes Actifs',
                  value: '$activeCount',
                  iconBgColor: AppTheme.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Admins list
          Expanded(
            child: _admins.isEmpty
                ? const Center(child: Text('Aucun administrateur plateforme configure.'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _admins.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final admin = _admins[idx];
                      final isSuper = admin['is_super_platform_admin'] == true;
                      final isActive = admin['is_active'] == true;
                      final fullName =
                          '${admin['first_name'] ?? ''} ${admin['last_name'] ?? ''}'.trim();

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isSuper ? Colors.amber[800] : AppTheme.primaryColor,
                            child: Icon(
                              isSuper ? Icons.security : Icons.admin_panel_settings_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '${admin['username']} ${isSuper ? "(Super Admin)" : ""}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${fullName.isNotEmpty ? fullName : "Administrateur"} • ${admin['email'] ?? "Pas d'email"} • ${admin['phone'] ?? "Pas de tel."}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  isActive ? 'Actif' : 'Desactive',
                                  style: TextStyle(
                                    color: isActive ? Colors.green[800] : Colors.red[800],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: isActive ? Colors.green[50] : Colors.red[50],
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 20, color: AppTheme.primaryColor),
                                tooltip: 'Details',
                                onPressed: () => _showAdminDetailsDialog(admin),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Modifier',
                                onPressed: () => _showEditDialog(admin),
                              ),
                              if (!isSuper)
                                IconButton(
                                  icon: Icon(
                                    isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                    size: 20,
                                    color: isActive ? Colors.orange : AppTheme.successColor,
                                  ),
                                  tooltip: isActive ? 'Desactiver' : 'Activer',
                                  onPressed: () async {
                                    await _service.updatePlatformAdmin(
                                      admin['id'] as int,
                                      {'is_active': !isActive},
                                    );
                                    _load();
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
