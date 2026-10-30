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
  List<Map<String, dynamic>> _pharmacies = [];
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
      // Load license keys and pharmacy list in parallel
      final results = await Future.wait([
        _service.getLicenseKeys(),
        _service.getPharmaciesSimple(),
      ]);
      if (mounted) {
        setState(() {
          _keys = results[0] as List<Map<String, dynamic>>;
          _pharmacies = results[1] as List<Map<String, dynamic>>;
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
    // Selected pharmacy (null = not assigned to a specific pharmacy)
    Map<String, dynamic>? selectedPharmacy;
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Generer des Cles de Licence'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── PHARMACIE CIBLE ──────────────────────────────────
                  const Text(
                    'Pharmacie destinataire *',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>?>(
                        value: selectedPharmacy,
                        isExpanded: true,
                        hint: const Text('Selectionner une pharmacie...'),
                        items: [
                          const DropdownMenuItem<Map<String, dynamic>?>(
                            value: null,
                            child: Text('-- Aucune (cle generique) --',
                                style: TextStyle(color: Colors.grey)),
                          ),
                          ..._pharmacies.map(
                            (p) => DropdownMenuItem<Map<String, dynamic>?>(
                              value: p,
                              child: Row(
                                children: [
                                  const Icon(Icons.storefront_outlined,
                                      size: 16, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${p['name']} (${p['code']})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p['plan']?.toString().toUpperCase() ??
                                          '',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.indigo,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setDlgState(() => selectedPharmacy = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── PLAN ─────────────────────────────────────────────
                  const Text('Formule d\'abonnement :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: plan,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'basic',
                              child: Text('Basic (Essentiel)')),
                          DropdownMenuItem(
                              value: 'pro', child: Text('Pro (Complet)')),
                          DropdownMenuItem(
                              value: 'enterprise',
                              child: Text('Enterprise (Multi-postes)')),
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
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── DUREE ────────────────────────────────────────────
                  const Text('Duree de validite :',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: durationDays,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 30, child: Text('1 Mois (30 jours)')),
                          DropdownMenuItem(
                              value: 90, child: Text('3 Mois (90 jours)')),
                          DropdownMenuItem(
                              value: 180, child: Text('6 Mois (180 jours)')),
                          DropdownMenuItem(
                              value: 365, child: Text('1 An (365 jours)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() => durationDays = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── MAX USERS + QUANTITE ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Max Utilisateurs :',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: maxUsers,
                                  isExpanded: true,
                                  items: [3, 5, 10, 20, 50]
                                      .map((u) => DropdownMenuItem(
                                          value: u,
                                          child: Text('$u util.')))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() => maxUsers = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nombre de cles :',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: quantity,
                                  isExpanded: true,
                                  items: [1, 2, 5, 10, 20]
                                      .map((q) => DropdownMenuItem(
                                          value: q, child: Text('$q cle(s)')))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() => quantity = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── NOTE ─────────────────────────────────────────────
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes additionnelles (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // ── RECAP ─────────────────────────────────────────────
                  if (selectedPharmacy != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        border: Border.all(color: Colors.green.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sera assignee a : ${selectedPharmacy!['name']} (${selectedPharmacy!['code']})',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              icon: const Icon(Icons.key),
              label: const Text('Generer'),
            ),
          ],
        ),
      ),
    );

    notesCtrl.dispose();

    if (result == true) {
      try {
        final generated = await _service.generateLicenseKeys(
          plan: plan,
          durationDays: durationDays,
          maxUsers: maxUsers,
          quantity: quantity,
          notes: notesCtrl.text.trim().isNotEmpty
              ? notesCtrl.text.trim()
              : selectedPharmacy != null
                  ? 'Pour: ${selectedPharmacy!['name']}'
                  : null,
          pharmacyId: selectedPharmacy?['id'] as int?,
        );
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${generated.length} cle(s) generee(s) avec succes${selectedPharmacy != null ? " pour ${selectedPharmacy!['name']}" : ""} !',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text('Erreur: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // Header row with stats
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: Row(
                children: [
                  _buildStatChip(
                    Icons.key,
                    '${_keys.length} cle(s) totales',
                    Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.check_circle_outline,
                    '${_keys.where((k) => k['is_active'] == true && k['used_at'] == null).length} disponible(s)',
                    Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    Icons.lock_outline,
                    '${_keys.where((k) => k['used_at'] != null).length} activee(s)',
                    Colors.blue,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
            ),
            // License keys list
            Expanded(
              child: _keys.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.vpn_key_off_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune cle de licence generee pour l\'instant.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Cliquez sur "Generer des Cles" pour commencer.',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _keys.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final k = _keys[idx];
                        final keyStr = k['key']?.toString() ?? '';
                        final isUsed = k['used_at'] != null;
                        final isActive = k['is_active'] == true;
                        final pharmacyName =
                            k['pharmacy_name']?.toString();
                        final notes = k['notes']?.toString();

                        Color badgeColor = Colors.green;
                        String statusText = 'Disponible';
                        IconData statusIcon = Icons.vpn_key;
                        if (isUsed) {
                          badgeColor = Colors.blue;
                          statusText = 'Activee';
                          statusIcon = Icons.check;
                        } else if (!isActive) {
                          badgeColor = Colors.grey;
                          statusText = 'Revoquee';
                          statusIcon = Icons.block;
                        }

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          badgeColor.withOpacity(0.15),
                                      child: Icon(statusIcon,
                                          color: badgeColor, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SelectableText(
                                        keyStr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          fontSize: 14,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      tooltip: 'Copier la cle',
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: keyStr));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Cle copiee dans le presse-papiers')),
                                        );
                                      },
                                    ),
                                    Chip(
                                      label: Text(statusText),
                                      backgroundColor:
                                          badgeColor.withOpacity(0.12),
                                      labelStyle: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    if (!isUsed && isActive)
                                      IconButton(
                                        icon: const Icon(Icons.cancel,
                                            color: Colors.red, size: 20),
                                        tooltip: 'Revoquer la cle',
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title:
                                                  const Text('Confirmation'),
                                              content: Text(
                                                  'Revoquer la cle $keyStr ?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, false),
                                                  child:
                                                      const Text('Annuler'),
                                                ),
                                                FilledButton(
                                                  style: FilledButton
                                                      .styleFrom(
                                                          backgroundColor:
                                                              Colors.red),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          ctx, true),
                                                  child:
                                                      const Text('Revoquer'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await _service.revokeLicenseKey(
                                                k['id'] as int);
                                            _load();
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _buildTag(
                                        Icons.workspace_premium_outlined,
                                        k['plan']
                                                ?.toString()
                                                .toUpperCase() ??
                                            '',
                                        Colors.purple),
                                    _buildTag(
                                        Icons.timer_outlined,
                                        '${k['duration_days']} jours',
                                        Colors.teal),
                                    _buildTag(
                                        Icons.people_outline,
                                        '${k['max_users']} util.',
                                        Colors.orange),
                                    if (pharmacyName != null)
                                      _buildTag(
                                          Icons.storefront_outlined,
                                          pharmacyName,
                                          Colors.blue),
                                    if (notes != null && notes.isNotEmpty)
                                      _buildTag(Icons.note_outlined, notes,
                                          Colors.grey),
                                  ],
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
        // FAB
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _showGenerateDialog,
            icon: const Icon(Icons.key),
            label: const Text('Generer des Cles'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}
