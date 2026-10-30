import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/pharmacy.dart';
import 'package:frontend1/services/platform_admin_service.dart';
import 'package:frontend1/widgets/dashboard/stats_card.dart';

class PlatformLicencesPage extends StatefulWidget {
  const PlatformLicencesPage({super.key});

  @override
  State<PlatformLicencesPage> createState() => _PlatformLicencesPageState();
}

class _PlatformLicencesPageState extends State<PlatformLicencesPage> {
  final PlatformAdminService _service = PlatformAdminService();

  List<Pharmacy> _pharmacies = [];
  List<Map<String, dynamic>> _keys = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all'; // all, available, used, revoked

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
      final results = await Future.wait([
        _service.getPharmacies(page: 1, pageSize: 100),
        _service.getLicenseKeys(),
      ]);
      if (mounted) {
        final page = results[0] as PharmacyPage;
        setState(() {
          _pharmacies = page.items;
          _keys = results[1] as List<Map<String, dynamic>>;
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

  Future<void> _showGenerateDialog({Pharmacy? preselectedPharmacy}) async {
    String plan = preselectedPharmacy?.plan ?? 'pro';
    int durationDays = 365;
    int maxUsers = preselectedPharmacy?.maxUsers ?? 5;
    int quantity = 1;
    Pharmacy? selectedPharmacy = preselectedPharmacy;
    final notesCtrl = TextEditingController(
      text: preselectedPharmacy != null
          ? 'Pour : ${preselectedPharmacy.name}'
          : '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.vpn_key_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Générer des Clés d\'Abonnement'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Pharmacie Destinataire :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Pharmacy?>(
                        value: selectedPharmacy,
                        isExpanded: true,
                        hint: const Text(
                          '-- Clé Générique (Sans pharmacie spécifique) --',
                        ),
                        items: [
                          const DropdownMenuItem<Pharmacy?>(
                            value: null,
                            child: Text(
                              '-- Clé Générique (Activable par toute pharmacie) --',
                              style: TextStyle(color: Colors.blueGrey),
                            ),
                          ),
                          ..._pharmacies.map(
                            (p) => DropdownMenuItem<Pharmacy?>(
                              value: p,
                              child: Text(
                                '${p.name} (${p.code}) — Plan ${p.plan.toUpperCase()}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setDlgState(() {
                            selectedPharmacy = val;
                            if (val != null) {
                              plan = val.plan;
                              maxUsers = val.maxUsers;
                              notesCtrl.text = 'Pour : ${val.name}';
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    '2. Formule d\'Abonnement :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: plan,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'basic',
                            child: Text('Basic (Essentiel - max 3 util.)'),
                          ),
                          DropdownMenuItem(
                            value: 'pro',
                            child: Text('Pro (Complet - max 10 util.)'),
                          ),
                          DropdownMenuItem(
                            value: 'enterprise',
                            child: Text('Enterprise (Illimité)'),
                          ),
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
                  const SizedBox(height: 16),

                  const Text(
                    '3. Durée de Validité :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: durationDays,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 30,
                            child: Text('1 Mois (30 jours)'),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child: Text('3 Mois (90 jours)'),
                          ),
                          DropdownMenuItem(
                            value: 180,
                            child: Text('6 Mois (180 jours)'),
                          ),
                          DropdownMenuItem(
                            value: 365,
                            child: Text('1 An (365 jours)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            setDlgState(() => durationDays = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Max Utilisateurs :',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: maxUsers,
                                  isExpanded: true,
                                  items: [3, 5, 10, 20, 50, 100]
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u,
                                          child: Text('$u util.'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setDlgState(() => maxUsers = val);
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
                            const Text(
                              'Nombre de clés :',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.4),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: quantity,
                                  isExpanded: true,
                                  items: [1, 2, 5, 10, 20]
                                      .map(
                                        (q) => DropdownMenuItem(
                                          value: q,
                                          child: Text('$q clé(s)'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setDlgState(() => quantity = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Mémo interne (optionnel)',
                      border: OutlineInputBorder(),
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
              icon: const Icon(Icons.key),
              label: const Text('Générer la Clé'),
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
          notes: notesCtrl.text.trim().isNotEmpty
              ? notesCtrl.text.trim()
              : null,
          pharmacyId: selectedPharmacy?.id,
        );
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${generated.length} clé(s) générée(s) avec succès${selectedPharmacy != null ? " pour ${selectedPharmacy!.name}" : ""} !',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    }
  }

  void _showKeyDetailsDialog(Map<String, dynamic> k) {
    final keyStr = k['key']?.toString() ?? '';
    final isUsed = k['used_at'] != null;
    final isActive = k['is_active'] == true;
    final pharmacyName = k['pharmacy_name']?.toString();
    final notes = k['notes']?.toString();

    String statusText = 'Disponible';
    Color badgeColor = AppTheme.successColor;
    if (isUsed) {
      statusText = 'Activée ($pharmacyName)';
      badgeColor = AppTheme.primaryColor;
    } else if (!isActive) {
      statusText = 'Révoquée';
      badgeColor = Colors.grey;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUsed
                    ? Icons.check_circle_outline
                    : (isActive ? Icons.vpn_key_outlined : Icons.block),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Détails de la Clé de Licence',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Chip(
              label: Text(statusText),
              backgroundColor: badgeColor.withOpacity(0.12),
              labelStyle: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        keyStr,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copier la clé',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: keyStr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Clé copiée dans le presse-papiers'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildRow(
                'Formule / Plan',
                k['plan']?.toString().toUpperCase() ?? '—',
              ),
              _buildRow('Durée de Validité', '${k['duration_days']} jours'),
              _buildRow(
                'Limite Utilisateurs',
                '${k['max_users']} utilisateurs',
              ),
              _buildRow(
                'Pharmacie Assignée',
                pharmacyName ??
                    (notes != null && notes.isNotEmpty
                        ? notes
                        : 'Non assignée (Clé Générique)'),
              ),
              _buildRow('Statut', statusText, color: badgeColor),
              _buildRow(
                'Date de Création',
                k['created_at']?.toString().substring(0, 10) ?? '—',
              ),
              _buildRow(
                'Date d\'Activation',
                k['used_at']?.toString().substring(0, 10) ??
                    'Non encore activée',
              ),
              if (notes != null && notes.isNotEmpty)
                _buildRow('Notes Internes', notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showGenerateDialog();
            },
            icon: const Icon(Icons.key, size: 16),
            label: const Text('Générer Autre Clé'),
          ),
        ],
      ),
    );
  }

  void _showPharmacyLicenseDetails(Pharmacy p) {
    final exp = p.licenseExpiresAt;
    int? daysLeft;
    if (exp != null) {
      daysLeft = exp.difference(DateTime.now()).inDays;
    }

    Color badgeColor = Colors.grey;
    String status = 'Non définie';
    if (exp != null) {
      if (daysLeft! < 0) {
        badgeColor = AppTheme.dangerColor;
        status = 'Expirée';
      } else if (daysLeft <= 30) {
        badgeColor = Colors.orange;
        status = 'Expire bientôt ($daysLeft jours)';
      } else {
        badgeColor = AppTheme.successColor;
        status = 'Valide ($daysLeft jours)';
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Licence — ${p.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(status),
              backgroundColor: badgeColor.withOpacity(0.12),
              labelStyle: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRow('Code Pharmacie', p.code),
              _buildRow('Formule Actuelle', p.plan.toUpperCase()),
              _buildRow('Utilisateurs Autorisés', '${p.maxUsers} utilisateurs'),
              _buildRow('NIF Fiscal', p.nif ?? 'Non renseigné'),
              _buildRow(
                'Date d\'Expiration',
                exp != null
                    ? '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}'
                    : 'Aucune date définie',
              ),
              _buildRow(
                'Temps Restant',
                daysLeft != null
                    ? (daysLeft < 0
                          ? 'Expirée depuis ${-daysLeft} j'
                          : '$daysLeft jours')
                    : '—',
                color: badgeColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showGenerateDialog(preselectedPharmacy: p);
            },
            icon: const Icon(Icons.vpn_key_outlined, size: 16),
            label: const Text('Générer une Clé pour cette Pharmacie'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern segmented toggle tabs (identical to PeriodToggle design in Dashboard)
  Widget _buildSegmentedFilter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = [
      {'id': 'all', 'label': 'Toutes', 'icon': Icons.list_alt_rounded},
      {
        'id': 'available',
        'label': 'Disponibles',
        'icon': Icons.check_circle_outline_rounded,
      },
      {'id': 'used', 'label': 'Activées', 'icon': Icons.verified_rounded},
      {'id': 'revoked', 'label': 'Révoquées', 'icon': Icons.block_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = _statusFilter == opt['id'];
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = opt['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppTheme.darkSidebarHover : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : (isDark
                              ? AppTheme.darkSidebarText
                              : Colors.grey[600]),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    opt['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? (isDark
                                ? AppTheme.darkForeground
                                : AppTheme.lightForeground)
                          : (isDark
                                ? AppTheme.darkSidebarText
                                : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.dangerColor,
            ),
            const SizedBox(height: 12),
            Text(
              'Erreur: $_error',
              style: const TextStyle(color: AppTheme.dangerColor),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final filteredKeys = _keys.where((k) {
      final isUsed = k['used_at'] != null;
      final isActive = k['is_active'] == true;
      if (_statusFilter == 'available') return isActive && !isUsed;
      if (_statusFilter == 'used') return isUsed;
      if (_statusFilter == 'revoked') return !isActive && !isUsed;
      return true;
    }).toList();

    final availableCount = _keys
        .where((k) => k['is_active'] == true && k['used_at'] == null)
        .length;
    final usedCount = _keys.where((k) => k['used_at'] != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion des Licences d\'Abonnement',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Émission des clés d\'activation SaaS et suivi de la validité des abonnements',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showGenerateDialog(),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Générer des Clés'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Top Modern StatsCard KPI Grid (exact Dashboard look)
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  icon: Icons.vpn_key_outlined,
                  label: 'Total Clés Générées',
                  value: '${_keys.length}',
                  iconBgColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatsCard(
                  icon: Icons.check_circle_outline,
                  label: 'Clés Disponibles',
                  value: '$availableCount',
                  iconBgColor: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatsCard(
                  icon: Icons.verified_user_outlined,
                  label: 'Clés Activées',
                  value: '$usedCount',
                  iconBgColor: Colors.indigo,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StatsCard(
                  icon: Icons.storefront_outlined,
                  label: 'Total Pharmacies',
                  value: '${_pharmacies.length}',
                  iconBgColor: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // =========================================================================
          // 1ÈRE PARTIE : TABLEAU DE GESTION & HISTORIQUE DES CLÉS (EN PREMIER !)
          // =========================================================================
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.vpn_key_outlined,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Historique des Clés de Licence (${_keys.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // Segmented toggle filter (Dashboard period toggle design)
                      _buildSegmentedFilter(context),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (filteredKeys.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Aucune clé trouvée avec ce filtre.'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 18,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Clé d\'Activation',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Plan',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Durée',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Max Users',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Pharmacie Assignée',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Statut',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: filteredKeys.map((k) {
                            final keyStr = k['key']?.toString() ?? '';
                            final isUsed = k['used_at'] != null;
                            final isActive = k['is_active'] == true;
                            final pharmacyName = k['pharmacy_name']?.toString();
                            final notes = k['notes']?.toString();

                            Color badgeColor = AppTheme.successColor;
                            String statusText = 'Disponible';
                            if (isUsed) {
                              badgeColor = AppTheme.primaryColor;
                              statusText = 'Activée ($pharmacyName)';
                            } else if (!isActive) {
                              badgeColor = Colors.grey;
                              statusText = 'Révoquée';
                            }

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SelectableText(
                                        keyStr,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 16,
                                        ),
                                        tooltip: 'Copier la clé',
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: keyStr),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Clé copiée !'),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      k['plan']?.toString().toUpperCase() ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                DataCell(Text('${k['duration_days']} jours')),
                                DataCell(Text('${k['max_users']} util.')),
                                DataCell(
                                  Text(
                                    pharmacyName ??
                                        (notes != null && notes.isNotEmpty
                                            ? notes
                                            : '— Générique'),
                                    style: TextStyle(
                                      fontWeight: pharmacyName != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: pharmacyName != null
                                          ? Colors.indigo
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    backgroundColor: badgeColor.withOpacity(
                                      0.12,
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                // Colonne Actions complète : Détails + Générer Clé + Révoquer
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: AppTheme.primaryColor,
                                        ),
                                        tooltip: 'Détails complets de la clé',
                                        onPressed: () =>
                                            _showKeyDetailsDialog(k),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.vpn_key_outlined,
                                          size: 18,
                                          color: Colors.teal,
                                        ),
                                        tooltip: 'Générer une nouvelle clé',
                                        onPressed: () => _showGenerateDialog(),
                                      ),
                                      if (!isUsed && isActive)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.block_outlined,
                                            color: AppTheme.dangerColor,
                                            size: 18,
                                          ),
                                          tooltip: 'Révoquer cette clé',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                title: const Text(
                                                  'Confirmation',
                                                ),
                                                content: Text(
                                                  'Voulez-vous révoquer la clé $keyStr ?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Annuler',
                                                    ),
                                                  ),
                                                  FilledButton(
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              AppTheme
                                                                  .dangerColor,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          ctx,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Révoquer',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await _service.revokeLicenseKey(
                                                k['id'] as int,
                                              );
                                              _load();
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // =========================================================================
          // 2ÈME PARTIE : VUE D'ENSEMBLE DES PHARMACIES & STATUT DES LICENCES
          // =========================================================================
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Colors.purple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Statut des Licences par Pharmacie (${_pharmacies.length})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Pharmacie',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Code',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Formule',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Date Expiration',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Temps Restant',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Statut',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _pharmacies.map((p) {
                          final now = DateTime.now();
                          final exp = p.licenseExpiresAt;
                          int? daysLeft;
                          bool isExpired = false;
                          bool isWarning = false;

                          if (exp != null) {
                            daysLeft = exp.difference(now).inDays;
                            isExpired = daysLeft < 0;
                            isWarning = daysLeft >= 0 && daysLeft <= 30;
                          }

                          Color badgeColor = Colors.grey;
                          String statusText = 'Non définie';
                          if (exp != null) {
                            if (isExpired) {
                              badgeColor = AppTheme.dangerColor;
                              statusText = 'Expirée';
                            } else if (isWarning) {
                              badgeColor = Colors.orange;
                              statusText = 'Expire bientôt';
                            } else {
                              badgeColor = AppTheme.successColor;
                              statusText = 'Actif';
                            }
                          }

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(Text(p.code)),
                              DataCell(
                                Chip(
                                  label: Text(
                                    p.plan.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              DataCell(
                                Text(
                                  exp != null
                                      ? '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}'
                                      : '—',
                                ),
                              ),
                              DataCell(
                                Text(
                                  daysLeft != null
                                      ? (daysLeft < 0
                                            ? 'Expirée depuis ${-daysLeft} j'
                                            : '$daysLeft jours')
                                      : '—',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                              DataCell(
                                Chip(
                                  label: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  backgroundColor: badgeColor.withOpacity(0.12),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              // Colonne Actions avec Détails + Générer Clé
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      tooltip: 'Détails de la licence',
                                      onPressed: () =>
                                          _showPharmacyLicenseDetails(p),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                      ),
                                      icon: const Icon(Icons.key, size: 14),
                                      label: const Text('Générer Clé'),
                                      onPressed: () => _showGenerateDialog(
                                        preselectedPharmacy: p,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
