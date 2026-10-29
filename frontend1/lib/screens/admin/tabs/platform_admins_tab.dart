import 'package:flutter/material.dart';
import 'package:frontend1/services/platform_admin_service.dart';

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
        title: const Text('Nouvel Administrateur Plateforme'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Identifiant / Username *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe initial *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: firstCtrl,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (userCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Créer'),
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
        title: Text('Modifier ${admin['username']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'Prénom')),
              const SizedBox(height: 8),
              TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Nom')),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe (optionnel)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
            Text('Erreur: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nouvel Administrateur'),
      ),
      body: _admins.isEmpty
          ? const Center(child: Text('Aucun administrateur plateforme configuré.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _admins.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final admin = _admins[idx];
                final isSuper = admin['is_super_platform_admin'] == true;
                final isActive = admin['is_active'] == true;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSuper ? Colors.amber[800] : Colors.blueGrey,
                      child: Icon(
                        isSuper ? Icons.security : Icons.admin_panel_settings,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      '${admin['username']} ${isSuper ? "(Super Admin)" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${admin['first_name'] ?? ''} ${admin['last_name'] ?? ''} â€¢ ${admin['email'] ?? 'Pas d\'email'} â€¢ ${admin['phone'] ?? 'Pas de tél.'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(isActive ? 'Actif' : 'Désactivé'),
                          backgroundColor: isActive ? Colors.green[100] : Colors.red[100],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Modifier',
                          onPressed: () => _showEditDialog(admin),
                        ),
                        if (!isSuper)
                          IconButton(
                            icon: Icon(
                              isActive ? Icons.block : Icons.check_circle,
                              size: 20,
                              color: isActive ? Colors.orange : Colors.green,
                            ),
                            tooltip: isActive ? 'Désactiver' : 'Activer',
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
    );
  }
}

