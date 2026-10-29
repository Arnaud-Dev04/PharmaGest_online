import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend1/services/platform_admin_service.dart';

class PlatformLicensesTab extends StatefulWidget {
  const PlatformLicensesTab({super.key});

  @override
  State<PlatformLicensesTab> createState() => _PlatformLicensesTabState();
}

class _PlatformLicensesTabState extends State<PlatformLicensesTab> {
  final PlatformAdminService _service = PlatformAdminService();
  List<Map<String, dynamic>> _keys = [];
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
      final list = await _service.getLicenseKeys();
      if (mounted) {
        setState(() {
          _keys = list;
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

  Future<void> _showGenerateDialog() async {
    String plan = 'pro';
    int durationDays = 365;
    int maxUsers = 5;
    int quantity = 1;
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('GÃ©nÃ©rer des ClÃ©s de Licence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Formule d\'abonnement / Plan :'),
                DropdownButton<String>(
                  value: plan,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'basic', child: Text('Basic (Essentiel)')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro (Complet)')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise (Multi-postes & AvancÃ©)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDlgState(() {
                        plan = val;
                        if (val == 'basic') maxUsers = 3;
                        if (val == 'pro') maxUsers = 5;
                        if (val == 'enterprise') maxUsers = 20;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('DurÃ©e de validitÃ© :'),
                DropdownButton<int>(
                  value: durationDays,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('1 Mois (30 jours)')),
                    DropdownMenuItem(value: 90, child: Text('3 Mois (90 jours)')),
                    DropdownMenuItem(value: 180, child: Text('6 Mois (180 jours)')),
                    DropdownMenuItem(value: 365, child: Text('1 An (365 jours)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => durationDays = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Utilisateurs :'),
                          DropdownButton<int>(
                            value: maxUsers,
                            isExpanded: true,
                            items: [3, 5, 10, 20, 50]
                                .map((u) => DropdownMenuItem(value: u, child: Text('$u utilisateurs')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDlgState(() => maxUsers = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nombre de clÃ©s :'),
                          DropdownButton<int>(
                            value: quantity,
                            isExpanded: true,
                            items: [1, 2, 5, 10, 20]
                                .map((q) => DropdownMenuItem(value: q, child: Text('$q clÃ©(s)')))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDlgState(() => quantity = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Pharmacie destinataire (optionnel)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('GÃ©nÃ©rer'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        final generated = await _service.generateLicenseKeys(
          plan: plan,
          durationDays: durationDays,
          maxUsers: maxUsers,
          quantity: quantity,
          notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        );
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${generated.length} clÃ©(s) gÃ©nÃ©rÃ©e(s) avec succÃ¨s !'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
            ElevatedButton(onPressed: _load, child: const Text('RÃ©essayer')),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.key),
        label: const Text('GÃ©nÃ©rer des ClÃ©s'),
      ),
      body: _keys.isEmpty
          ? const Center(child: Text('Aucune clÃ© de licence gÃ©nÃ©rÃ©e pour l\'instant.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _keys.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final k = _keys[idx];
                final keyStr = k['key']?.toString() ?? '';
                final isUsed = k['used_at'] != null;
                final isActive = k['is_active'] == true;
                final pharmacyName = k['pharmacy_name']?.toString();

                Color badgeColor = Colors.green;
                String statusText = 'Disponible';
                if (isUsed) {
                  badgeColor = Colors.blue;
                  statusText = 'ActivÃ©e ($pharmacyName)';
                } else if (!isActive) {
                  badgeColor = Colors.grey;
                  statusText = 'RÃ©voquÃ©e';
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: badgeColor,
                      child: Icon(
                        isUsed ? Icons.check : (isActive ? Icons.vpn_key : Icons.block),
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        SelectableText(
                          keyStr,
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: 'Copier la clÃ©',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: keyStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ClÃ© copiÃ©e dans le presse-papiers')),
                            );
                          },
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Plan: ${k['plan']?.toString().toUpperCase()} â€¢ ${k['duration_days']} jours â€¢ Max ${k['max_users']} util. ${k['notes'] != null ? "â€¢ Note: ${k['notes']}" : ""}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(statusText),
                          backgroundColor: badgeColor.withOpacity(0.15),
                          labelStyle: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                        ),
                        if (!isUsed && isActive)
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'RÃ©voquer la clÃ©',
                            onPressed: () async {
                              await _service.revokeLicenseKey(k['id'] as int);
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

