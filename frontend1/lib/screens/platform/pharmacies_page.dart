import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/pharmacy.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/services/platform_admin_service.dart';
import 'package:frontend1/widgets/dashboard/stats_card.dart';

class PharmaciesPage extends StatefulWidget {
  const PharmaciesPage({super.key});

  @override
  State<PharmaciesPage> createState() => _PharmaciesPageState();
}

class _PharmaciesPageState extends State<PharmaciesPage> {
  final PlatformAdminService _service = PlatformAdminService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  List<Pharmacy> _pharmacies = [];
  int _currentPage = 1;
  int _totalPharmacies = 0;
  int _totalPages = 0;
  static const int _pageSize = 25;
  PlatformMetrics? _metrics;
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'all'; // 'all', 'active', 'pending'

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final generation = ++_loadGeneration;
    final requestedPage = page ?? _currentPage;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final loadMetrics = _metrics == null;
      final futures = <Future<Object>>[
        _service.getPharmacies(
          page: requestedPage,
          pageSize: _pageSize,
          search: _searchController.text,
        ),
        if (loadMetrics) _service.getMetrics(),
      ];
      final results = await Future.wait<Object>(futures);
      if (!mounted) return;
      if (generation != _loadGeneration) return;
      final pharmacyPage = results[0] as PharmacyPage;
      setState(() {
        _pharmacies = pharmacyPage.items;
        _currentPage = pharmacyPage.page;
        _totalPharmacies = pharmacyPage.total;
        _totalPages = pharmacyPage.totalPages;
        if (loadMetrics) _metrics = results[1] as PlatformMetrics;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStatus(Pharmacy pharmacy, bool value) async {
    try {
      await _service.setPharmacyStatus(pharmacy.id, value);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de modifier le statut de la pharmacie'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPharmacyDetailsDialog(Pharmacy p) {
    final exp = p.licenseExpiresAt;
    int? daysLeft;
    if (exp != null) {
      daysLeft = exp.difference(DateTime.now()).inDays;
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
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Code : ${p.code}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(p.isActive ? 'Active' : 'Inactive'),
              backgroundColor: p.isActive ? Colors.green[50] : Colors.red[50],
              labelStyle: TextStyle(
                color: p.isActive ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Informations Générales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Divider(),
                _detailRow('Adresse', p.address ?? '—'),
                _detailRow(
                  'Ville / Pays',
                  '${p.city ?? "—"}, ${p.country ?? "—"}',
                ),
                _detailRow('Téléphone', p.phone ?? '—'),
                _detailRow('Email', p.email ?? '—'),
                const SizedBox(height: 14),

                const Text(
                  'Fiscalité & OBR Burundi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Divider(),
                _detailRow('NIF', p.nif ?? 'Non renseigné', isBoldValue: true),
                _detailRow(
                  'Registre de Commerce (RC)',
                  p.rcNumber ?? 'Non renseigné',
                ),
                _detailRow('Centre Fiscal', p.taxCenter ?? 'Non renseigné'),
                _detailRow(
                  'Intégration OBR',
                  p.obrEnabled ? 'Activée' : 'Désactivée',
                  valColor: p.obrEnabled ? AppTheme.successColor : Colors.grey,
                ),
                _detailRow('Environnement OBR', p.obrEnvironment.toUpperCase()),
                const SizedBox(height: 14),

                const Text(
                  'Abonnement & Licence',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Divider(),
                _detailRow(
                  'Formule / Plan',
                  p.plan.toUpperCase(),
                  isBoldValue: true,
                ),
                _detailRow('Limite Utilisateurs', '${p.maxUsers} utilisateurs'),
                _detailRow(
                  'Expiration Licence',
                  exp != null
                      ? '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')} (${daysLeft != null ? (daysLeft < 0 ? "Expirée" : "$daysLeft j restants") : ""})'
                      : 'Aucune licence définie',
                  valColor: daysLeft != null
                      ? (daysLeft < 0
                            ? AppTheme.dangerColor
                            : (daysLeft <= 30
                                  ? Colors.orange
                                  : AppTheme.successColor))
                      : Colors.grey,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showObrConfigDialog(p);
            },
            icon: const Icon(Icons.receipt_long_outlined, size: 16),
            label: const Text('Configurer OBR'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showPharmacyForm(pharmacy: p);
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isBoldValue = false,
    Color? valColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                color: valColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApproveDialog(Pharmacy p) async {
    int trialDays = 14;
    String selectedPlan = p.plan;
    bool isProcessing = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Approuver : ${p.name}', style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activez cette pharmacie et attribuez-lui une clé d\'activation pour sa période d\'essai.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _detailRow('Code Pharmacie', p.code),
                      const SizedBox(height: 6),
                      _detailRow('NIF (Fiscal)', p.nif ?? 'Non renseigné'),
                      const SizedBox(height: 6),
                      _detailRow('Contact', '${p.phone ?? ''} ${p.email != null ? '• ${p.email}' : ''}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: trialDays,
                  decoration: const InputDecoration(
                    labelText: 'Durée de la période d\'essai',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 jours d\'essai')),
                    DropdownMenuItem(value: 14, child: Text('14 jours d\'essai (Standard)')),
                    DropdownMenuItem(value: 30, child: Text('30 jours d\'essai (1 mois)')),
                    DropdownMenuItem(value: 60, child: Text('60 jours d\'essai (2 mois)')),
                    DropdownMenuItem(value: 90, child: Text('90 jours d\'essai (3 mois)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => trialDays = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  decoration: const InputDecoration(
                    labelText: 'Formule / Plan d\'abonnement',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'basic', child: Text('Petit (Basic - max 3 users)')),
                    DropdownMenuItem(value: 'pro', child: Text('Moyen (Pro - max 10 users)')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Entreprise (Illimité)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedPlan = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: isProcessing
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Rejeter l\'inscription ?'),
                          content: Text('Voulez-vous rejeter la demande pour ${p.name} ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Rejeter'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _service.rejectPharmacy(p.id);
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        await _load();
                      }
                    },
              child: const Text('Rejeter la demande'),
            ),
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setDialogState(() => isProcessing = true);
                      try {
                        final res = await _service.approvePharmacy(
                          p.id,
                          trialDays: trialDays,
                          plan: selectedPlan,
                        );
                        if (!dialogCtx.mounted) return;
                        Navigator.pop(dialogCtx);
                        await _load();
                        if (!mounted) return;
                        _showActivationKeySuccessDialog(
                          pharmacyName: p.name,
                          pharmacyCode: p.code,
                          licenseKey: res['license_key']?.toString() ?? '',
                          expiresAt: res['license_expires_at']?.toString(),
                          plan: selectedPlan,
                        );
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
              icon: isProcessing
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(isProcessing ? 'Activation...' : 'Approuver & Générer Clé'),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivationKeySuccessDialog({
    required String pharmacyName,
    required String pharmacyCode,
    required String licenseKey,
    String? expiresAt,
    String? plan,
    String? adminUsername,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.key_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Clé d\'Activation Générée !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La pharmacie « $pharmacyName » est maintenant active avec une période d\'essai.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLÉ D\'ACTIVATION DE LICENCE :',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.brown),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            licenseKey,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copier la clé',
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryColor),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: licenseKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Clé de licence copiée !'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _detailRow('Code Pharmacie', pharmacyCode),
                    if (adminUsername != null) ...[
                      const SizedBox(height: 6),
                      _detailRow('Identifiant Admin', adminUsername),
                    ],
                    if (plan != null) ...[
                      const SizedBox(height: 6),
                      _detailRow('Formule', plan.toUpperCase()),
                    ],
                    if (expiresAt != null) ...[
                      const SizedBox(height: 6),
                      _detailRow('Fin de période d\'essai', expiresAt.split('T').first),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPharmacyForm({Pharmacy? pharmacy}) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: pharmacy?.name ?? '');
    final code = TextEditingController(text: pharmacy?.code ?? '');
    final address = TextEditingController(text: pharmacy?.address ?? '');
    final city = TextEditingController(text: pharmacy?.city ?? '');
    final country = TextEditingController(text: pharmacy?.country ?? '');
    final phone = TextEditingController(text: pharmacy?.phone ?? '');
    final email = TextEditingController(text: pharmacy?.email ?? '');
    final nifCtrl = TextEditingController(text: pharmacy?.nif ?? '');
    final username = TextEditingController();
    final password = TextEditingController();
    var plan = pharmacy?.plan ?? 'basic';
    var maxUsers = pharmacy?.maxUsers ?? 3;
    if (plan == 'basic' && maxUsers > 3) maxUsers = 3;
    if (plan == 'pro' && maxUsers > 10) maxUsers = 10;
    if (plan == 'enterprise' && maxUsers > 1000) maxUsers = 1000;
    var isSaving = false;
    var grantTrial = true;
    var trialDays = 14;
    final rcCtrl = TextEditingController(text: pharmacy?.rcNumber ?? '');

    List<int> optionsForPlan(String selectedPlan, int selectedMaxUsers) {
      final options = switch (selectedPlan) {
        'basic' => [1, 2, 3],
        'pro' => List<int>.generate(10, (index) => index + 1),
        _ => [3, 5, 10, 25, 50, 1000],
      };
      if (!options.contains(selectedMaxUsers)) options.add(selectedMaxUsers);
      options.sort();
      return options;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            pharmacy == null
                ? 'Nouvelle Pharmacie'
                : 'Modifier la Pharmacie : ${pharmacy.name}',
          ),
          content: SizedBox(
            width: 540,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _formField(name, 'Nom de la pharmacie *', required: true),
                    if (pharmacy == null)
                      _formField(
                        code,
                        'Code pharmacie (unique) *',
                        required: true,
                        helper: 'Ex: PHARM_CENTRAL (lettres, chiffres, tirets)',
                      ),
                    _formField(nifCtrl, 'NIF (Numéro d\'Identité Fiscale)'),
                    _formField(address, 'Adresse physique'),
                    Row(
                      children: [
                        Expanded(child: _formField(city, 'Ville')),
                        const SizedBox(width: 12),
                        Expanded(child: _formField(country, 'Pays')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _formField(phone, 'Téléphone')),
                        const SizedBox(width: 12),
                        Expanded(child: _formField(email, 'Email')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: plan,
                      decoration: const InputDecoration(
                        labelText: 'Formule / Plan',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'basic',
                          child: Text('Basic (Essentiel - max 3)'),
                        ),
                        DropdownMenuItem(
                          value: 'pro',
                          child: Text('Pro (Complet - max 10)'),
                        ),
                        DropdownMenuItem(
                          value: 'enterprise',
                          child: Text('Enterprise (Illimité)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            plan = value;
                            final maxAllowed = switch (plan) {
                              'basic' => 3,
                              'pro' => 10,
                              _ => 1000,
                            };
                            if (maxUsers > maxAllowed) maxUsers = maxAllowed;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: maxUsers,
                      decoration: const InputDecoration(
                        labelText: 'Nombre max d\'utilisateurs autorisés',
                        border: OutlineInputBorder(),
                      ),
                      items: optionsForPlan(plan, maxUsers)
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == 1000
                                    ? 'Illimité (1000)'
                                    : '$value utilisateurs',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => maxUsers = value);
                        }
                      },
                    ),
                    if (pharmacy == null) ...[
                      const Divider(height: 28),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Attribuer une période d\'essai gratuite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: const Text('Génère automatiquement une clé d\'activation', style: TextStyle(fontSize: 11)),
                              value: grantTrial,
                              onChanged: (v) => setDialogState(() => grantTrial = v ?? true),
                            ),
                            if (grantTrial) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: trialDays,
                                decoration: const InputDecoration(
                                  labelText: 'Durée d\'essai (jours)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 7, child: Text('7 jours')),
                                  DropdownMenuItem(value: 14, child: Text('14 jours (Standard)')),
                                  DropdownMenuItem(value: 30, child: Text('30 jours (1 mois)')),
                                  DropdownMenuItem(value: 60, child: Text('60 jours (2 mois)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => trialDays = val);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Premier Administrateur de la Pharmacie',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _formField(
                        username,
                        'Nom d\'utilisateur admin *',
                        required: true,
                      ),
                      _formField(
                        password,
                        'Mot de passe initial *',
                        required: true,
                        obscure: true,
                        helper:
                            'Min 8 caractères; changement requis à la première connexion',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        if (pharmacy == null) {
                          final res = await _service.onboardPharmacy({
                            'name': name.text.trim(),
                            'code': code.text.trim(),
                            'nif': _nullable(nifCtrl.text),
                            'address': _nullable(address.text),
                            'city': _nullable(city.text),
                            'country': _nullable(country.text),
                            'phone': _nullable(phone.text),
                            'email': _nullable(email.text),
                            'plan': plan,
                            'max_users': maxUsers,
                            'grant_trial': grantTrial,
                            'trial_days': trialDays,
                            'admin_username': username.text.trim(),
                            'admin_password': password.text,
                          });
                          if (res['license_key'] != null) {
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            await _load();
                            if (mounted) {
                              _showActivationKeySuccessDialog(
                                pharmacyName: name.text.trim(),
                                pharmacyCode: code.text.trim(),
                                licenseKey: res['license_key']?.toString() ?? '',
                                plan: plan,
                                adminUsername: username.text.trim(),
                              );
                            }
                            return;
                          }
                        } else {
                          await _service.updatePharmacy(pharmacy.id, {
                            'name': name.text.trim(),
                            'nif': _nullable(nifCtrl.text),
                            'address': _nullable(address.text),
                            'city': _nullable(city.text),
                            'country': _nullable(country.text),
                            'phone': _nullable(phone.text),
                            'email': _nullable(email.text),
                            'plan': plan,
                            'max_users': maxUsers,
                          });
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Pharmacie enregistrée avec succès'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Erreur: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      name,
      code,
      address,
      city,
      country,
      phone,
      email,
      nifCtrl,
      username,
      password,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _showObrConfigDialog(Pharmacy pharmacy) async {
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isLoadingConfig = true;

    final nifCtrl = TextEditingController();
    final rcCtrl = TextEditingController();
    final taxCenterCtrl = TextEditingController();
    final systemIdCtrl = TextEditingController();
    final apiUserCtrl = TextEditingController();
    final apiPassCtrl = TextEditingController();
    final activitySectorCtrl = TextEditingController();
    final provinceCtrl = TextEditingController();
    final communeCtrl = TextEditingController();
    final quartierCtrl = TextEditingController();
    final avenueCtrl = TextEditingController();
    final rueCtrl = TextEditingController();
    final numberCtrl = TextEditingController();

    bool obrEnabled = false;
    String obrEnv = 'sandbox';
    String tpType = '2';
    String tpLegalForm = 'SUARL';
    String vatTaxpayer = '1';
    String ctTaxpayer = '0';
    String tlTaxpayer = '0';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDlgState) {
          if (isLoadingConfig) {
            _service
                .getPharmacyObrConfig(pharmacy.id)
                .then((data) {
                  setDlgState(() {
                    nifCtrl.text = data['nif']?.toString() ?? '';
                    rcCtrl.text = data['rc_number']?.toString() ?? '';
                    taxCenterCtrl.text = data['tax_center']?.toString() ?? '';
                    systemIdCtrl.text = data['obr_system_id']?.toString() ?? '';
                    apiUserCtrl.text =
                        data['obr_api_username']?.toString() ?? '';
                    activitySectorCtrl.text =
                        data['tp_activity_sector']?.toString() ??
                        'Commerce de détail de produits pharmaceutiques';
                    provinceCtrl.text =
                        data['tp_address_province']?.toString() ??
                        'BUJUMBURA MAIRIE';
                    communeCtrl.text =
                        data['tp_address_commune']?.toString() ?? 'MUKAZA';
                    quartierCtrl.text =
                        data['tp_address_quartier']?.toString() ?? 'ROHERO';
                    avenueCtrl.text =
                        data['tp_address_avenue']?.toString() ?? '';
                    rueCtrl.text = data['tp_address_rue']?.toString() ?? '';
                    numberCtrl.text =
                        data['tp_address_number']?.toString() ?? '';
                    obrEnabled = data['obr_enabled'] == true;
                    obrEnv = data['obr_environment']?.toString() ?? 'sandbox';
                    tpType = data['tp_type']?.toString() ?? '2';
                    tpLegalForm = data['tp_legal_form']?.toString() ?? 'SUARL';
                    vatTaxpayer = data['vat_taxpayer']?.toString() ?? '1';
                    ctTaxpayer = data['ct_taxpayer']?.toString() ?? '0';
                    tlTaxpayer = data['tl_taxpayer']?.toString() ?? '0';
                    isLoadingConfig = false;
                  });
                })
                .catchError((err) {
                  setDlgState(() => isLoadingConfig = false);
                });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('Configuration OBR — ${pharmacy.name}'),
              content: const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Configuration Fiscale OBR — ${pharmacy.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 640,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        title: const Text(
                          'Activer l\'intégration OBR (EBMS Burundi)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Signature électronique des factures auprès de l\'Office Burundais des Recettes',
                        ),
                        value: obrEnabled,
                        onChanged: (val) => setDlgState(() => obrEnabled = val),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      const Text(
                        '1. Identifiants Fiscaux',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _formField(
                              nifCtrl,
                              'NIF *',
                              required: obrEnabled,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _formField(
                              rcCtrl,
                              'Registre de Commerce (RC)',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _formField(taxCenterCtrl, 'Centre Fiscal'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: obrEnv,
                              decoration: const InputDecoration(
                                labelText: 'Environnement OBR',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'sandbox',
                                  child: Text('Sandbox (Test)'),
                                ),
                                DropdownMenuItem(
                                  value: 'production',
                                  child: Text('Production (Réel)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setDlgState(() => obrEnv = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        '2. Identifiants Système & API',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _formField(
                        systemIdCtrl,
                        'Identifiant Système OBR (System ID)',
                        helper: 'Délivré par l\'OBR lors de l\'homologation',
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _formField(
                              apiUserCtrl,
                              'Nom d\'utilisateur API',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _formField(
                              apiPassCtrl,
                              'Nouveau mot de passe API (optionnel)',
                              obscure: true,
                              helper: 'Laisser vide pour ne pas modifier',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        '3. Forme Juridique & Assujettissements',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: vatTaxpayer,
                              decoration: const InputDecoration(
                                labelText: 'Assujetti à la TVA',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '1',
                                  child: Text('Oui (Assujetti)'),
                                ),
                                DropdownMenuItem(
                                  value: '0',
                                  child: Text('Non (Exonéré)'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setDlgState(() => vatTaxpayer = v ?? '1'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tpType,
                              decoration: const InputDecoration(
                                labelText: 'Type de Personne',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: '2',
                                  child: Text('Personne Morale'),
                                ),
                                DropdownMenuItem(
                                  value: '1',
                                  child: Text('Personne Physique'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setDlgState(() => tpType = v ?? '2'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDlgState(() => isSaving = true);
                        try {
                          final payload = <String, dynamic>{
                            'obr_enabled': obrEnabled,
                            'obr_environment': obrEnv,
                            'nif': _nullable(nifCtrl.text),
                            'rc_number': _nullable(rcCtrl.text),
                            'tax_center': _nullable(taxCenterCtrl.text),
                            'obr_system_id': _nullable(systemIdCtrl.text),
                            'obr_api_username': _nullable(apiUserCtrl.text),
                            'tp_type': tpType,
                            'tp_legal_form': tpLegalForm,
                            'tp_activity_sector': _nullable(
                              activitySectorCtrl.text,
                            ),
                            'tp_address_province': _nullable(provinceCtrl.text),
                            'tp_address_commune': _nullable(communeCtrl.text),
                            'tp_address_quartier': _nullable(quartierCtrl.text),
                            'tp_address_avenue': _nullable(avenueCtrl.text),
                            'tp_address_rue': _nullable(rueCtrl.text),
                            'tp_address_number': _nullable(numberCtrl.text),
                            'vat_taxpayer': vatTaxpayer,
                            'ct_taxpayer': ctTaxpayer,
                            'tl_taxpayer': tlTaxpayer,
                          };
                          if (apiPassCtrl.text.trim().isNotEmpty) {
                            payload['obr_api_password'] = apiPassCtrl.text
                                .trim();
                          }
                          await _service.updatePharmacyObrConfig(
                            pharmacy.id,
                            payload,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          await _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Configuration OBR mise à jour avec succès',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          setDlgState(() => isSaving = false);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(isSaving ? 'Enregistrement...' : 'Enregistrer OBR'),
              ),
            ],
          );
        },
      ),
    );

    for (final c in [
      nifCtrl,
      rcCtrl,
      taxCenterCtrl,
      systemIdCtrl,
      apiUserCtrl,
      apiPassCtrl,
      activitySectorCtrl,
      provinceCtrl,
      communeCtrl,
      quartierCtrl,
      avenueCtrl,
      rueCtrl,
      numberCtrl,
    ]) {
      c.dispose();
    }
  }

  Widget _formField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool obscure = false,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Ce champ est requis'
                  : null
            : null,
      ),
    );
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final isPlatformAdmin = context.select<AuthProvider, bool>(
      (auth) => auth.user?.role == 'platform_admin',
    );
    if (!isPlatformAdmin) {
      return const Center(
        child: Text('Accès réservé aux administrateurs de la plateforme.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestion des Pharmacies',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supervision, onboarding et configuration fiscale OBR des pharmacies',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualiser',
                    onPressed: _isLoading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _showPharmacyForm(),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Nouvelle Pharmacie'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Modern Dashboard StatsCard KPI Grid
              if (_metrics != null) _buildMetrics(isCompact),
              const SizedBox(height: 16),

              // Segmented Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _statusFilter == 'all',
                      label: Text('Toutes (${_totalPharmacies})'),
                      onSelected: (_) => setState(() => _statusFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _statusFilter == 'active',
                      label: Text('Actives (${_metrics?.activePharmacyCount ?? 0})'),
                      onSelected: (_) => setState(() => _statusFilter = 'active'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _statusFilter == 'pending',
                      avatar: (_metrics?.pendingPharmacyCount ?? 0) > 0
                          ? const Icon(Icons.circle, size: 10, color: Colors.orange)
                          : null,
                      label: Text('En attente (${_metrics?.pendingPharmacyCount ?? 0})'),
                      selectedColor: Colors.orange.shade100,
                      onSelected: (_) => setState(() => _statusFilter = 'pending'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () => _load(page: 1),
                  );
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher par nom, code, NIF ou ville...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              Expanded(child: _buildPharmacyTable(isCompact)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetrics(bool compact) {
    final metrics = _metrics!;
    return Row(
      children: [
        Expanded(
          child: StatsCard(
            icon: Icons.storefront_outlined,
            label: 'Total Pharmacies',
            value: '${metrics.pharmacyCount}',
            iconBgColor: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsCard(
            icon: Icons.check_circle_outline,
            label: 'Pharmacies Actives',
            value: '${metrics.activePharmacyCount}',
            iconBgColor: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatsCard(
            icon: Icons.pending_actions_rounded,
            label: 'En attente d\'approbation',
            value: '${metrics.pendingPharmacyCount}',
            iconBgColor: metrics.pendingPharmacyCount > 0 ? Colors.orange : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPharmacyTable(bool compact) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Erreur: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_pharmacies.isEmpty) {
      return const Center(child: Text('Aucune pharmacie trouvée.'));
    }

    final displayedPharmacies = _pharmacies.where((p) {
      if (_statusFilter == 'active') return p.isActive && !p.isPendingApproval;
      if (_statusFilter == 'pending') return p.isPendingApproval;
      return true;
    }).toList();

    final table = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 18,
            columns: const [
              DataColumn(
                label: Text(
                  'Nom',
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
                  'NIF (Fiscal)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Ville / Pays',
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
                  'Max Users',
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
                  'OBR',
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
            rows: displayedPharmacies.map((p) {
              final isObrActive = p.obrEnabled;

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      p.nif != null && p.nif!.isNotEmpty ? p.nif! : '—',
                      style: TextStyle(
                        fontFamily: p.nif != null ? 'monospace' : null,
                        fontWeight: p.nif != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: p.nif != null
                            ? Colors.blueGrey[800]
                            : Colors.grey,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${p.city ?? "—"}${p.country != null ? ", ${p.country}" : ""}',
                    ),
                  ),
                  DataCell(
                    Chip(
                      label: Text(
                        p.plan.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: p.plan == 'pro'
                              ? Colors.indigo[800]
                              : (p.plan == 'enterprise'
                                    ? Colors.purple[800]
                                    : Colors.blueGrey[800]),
                        ),
                      ),
                      backgroundColor: p.plan == 'pro'
                          ? Colors.indigo[50]
                          : (p.plan == 'enterprise'
                                ? Colors.purple[50]
                                : Colors.blueGrey[50]),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  DataCell(Text('${p.maxUsers}')),
                  DataCell(
                    Switch.adaptive(
                      value: p.isActive,
                      onChanged: (val) => _toggleStatus(p, val),
                    ),
                  ),
                  DataCell(
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        foregroundColor: isObrActive
                            ? AppTheme.successColor
                            : Colors.blueGrey,
                        side: BorderSide(
                          color: isObrActive
                              ? AppTheme.successColor
                              : Colors.grey,
                        ),
                      ),
                      icon: Icon(
                        isObrActive
                            ? Icons.check_circle_outline
                            : Icons.settings_outlined,
                        size: 16,
                      ),
                      label: Text(isObrActive ? 'OBR Actif' : 'Config OBR'),
                      onPressed: () => _showObrConfigDialog(p),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.isPendingApproval) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 15),
                            label: const Text('Approuver', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showApproveDialog(p),
                          ),
                          const SizedBox(width: 6),
                        ],
                        IconButton(
                          tooltip: 'Détails complets',
                          icon: const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                          onPressed: () => _showPharmacyDetailsDialog(p),
                        ),
                        IconButton(
                          tooltip: 'Modifier',
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showPharmacyForm(pharmacy: p),
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
    );

    return Column(
      children: [
        Expanded(child: table),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Page précédente',
                  onPressed: _isLoading || _currentPage <= 1
                      ? null
                      : () => _load(page: _currentPage - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page $_currentPage sur $_totalPages ($_totalPharmacies pharmacies)',
                ),
                IconButton(
                  tooltip: 'Page suivante',
                  onPressed: _isLoading || _currentPage >= _totalPages
                      ? null
                      : () => _load(page: _currentPage + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
