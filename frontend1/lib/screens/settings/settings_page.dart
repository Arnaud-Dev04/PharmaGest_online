import 'package:flutter/material.dart';

import 'package:frontend1/core/theme.dart';

import 'package:frontend1/services/settings_service.dart';
import 'package:frontend1/services/obr_service.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/providers/auth_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  final AdminService _adminService = AdminService();
  final ObrService _obrService = ObrService();

  // General Settings State

  bool _isLoadingSettings = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _pharmacyNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nifCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _licenseDaysCtrl = TextEditingController();
  final _licenseDurationCtrl = TextEditingController();
  final _licenseMsgCtrl = TextEditingController();
  final _licenseExpiryDateCtrl = TextEditingController();

  // OBR Fiscal State
  bool _isLoadingObr = false;
  bool _isTestingObr = false;
  bool _isResyncingObr = false;
  bool _isSavingObr = false;
  bool _obrEnabled = false;
  String _obrEnvironment = 'sandbox';
  bool _obscureObrPassword = true;

  final _obrNifCtrl = TextEditingController();
  final _obrRcCtrl = TextEditingController();
  final _obrTaxCenterCtrl = TextEditingController(text: 'DMC');
  final _obrSystemIdCtrl = TextEditingController();
  final _obrUsernameCtrl = TextEditingController();
  final _obrPasswordCtrl = TextEditingController();

  // Spécifications OBR EBMS V0.5
  final _obrLegalFormCtrl = TextEditingController(text: 'SUARL');
  final _obrActivitySectorCtrl = TextEditingController(text: 'Commerce de détail de produits pharmaceutiques');
  final _obrProvinceCtrl = TextEditingController(text: 'BUJUMBURA MAIRIE');
  final _obrCommuneCtrl = TextEditingController(text: 'MUKAZA');
  final _obrQuartierCtrl = TextEditingController(text: 'ROHERO');
  final _obrAvenueCtrl = TextEditingController();
  final _obrRueCtrl = TextEditingController();
  final _obrNumberCtrl = TextEditingController();
  String _obrTpType = '2'; // '1'=personne physique, '2'=personne morale
  bool _obrVatTaxpayer = true;
  bool _obrCtTaxpayer = false;
  bool _obrTlTaxpayer = false;

  Map<String, dynamic>? _obrStatusData;
  String? _obrTestResult;
  bool? _obrTestSuccess;

  // License Status
  Map<String, dynamic>? _licenseStatus;

  // Reset State
  bool _resetSales = false;
  bool _resetStock = false;
  bool _resetUsers = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLicenseStatus();
    _loadObrStatus();
  }

  @override
  void dispose() {
    _pharmacyNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _nifCtrl.dispose();
    _logoUrlCtrl.dispose();
    _currencyCtrl.dispose();
    _licenseDaysCtrl.dispose();
    _licenseDurationCtrl.dispose();
    _licenseMsgCtrl.dispose();
    _licenseExpiryDateCtrl.dispose();
    _obrNifCtrl.dispose();
    _obrRcCtrl.dispose();
    _obrTaxCenterCtrl.dispose();
    _obrSystemIdCtrl.dispose();
    _obrUsernameCtrl.dispose();
    _obrPasswordCtrl.dispose();
    _obrLegalFormCtrl.dispose();
    _obrActivitySectorCtrl.dispose();
    _obrProvinceCtrl.dispose();
    _obrCommuneCtrl.dispose();
    _obrQuartierCtrl.dispose();
    _obrAvenueCtrl.dispose();
    _obrRueCtrl.dispose();
    _obrNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final s = await _settingsService.getSettings();
      setState(() {
        _pharmacyNameCtrl.text = s.pharmacyName;
        _addressCtrl.text = s.pharmacyAddress;
        _phoneCtrl.text = s.pharmacyPhone;
        _nifCtrl.text = s.pharmacyNif;
        _logoUrlCtrl.text = s.logoUrl;
        _currencyCtrl.text = s.currency;
        _licenseDaysCtrl.text = s.licenseWarningDays.toString();
        _licenseDurationCtrl.text = s.licenseWarningDuration.toString();
        _licenseMsgCtrl.text = s.licenseWarningMessage;
        _isLoadingSettings = false;
      });
    } catch (e) {
      debugPrint('Erreur loadSettings: $e');
      setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final data = {
        'pharmacy_name': _pharmacyNameCtrl.text,
        'pharmacy_address': _addressCtrl.text,
        'pharmacy_phone': _phoneCtrl.text,
        'pharmacy_nif': _nifCtrl.text,
        'logo_url': _logoUrlCtrl.text,
        'currency': _currencyCtrl.text,
      };
      await _settingsService.updateSettings(data);
      if (mounted) {
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lp.translate('settingsUpdated')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lp.translate('errorUpdating')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAdminSettings() async {
    // Pas de validation du form général ici
    try {
      final data = {
        'license_warning_bdays': int.tryParse(_licenseDaysCtrl.text) ?? 60,
        'license_warning_duration':
            int.tryParse(_licenseDurationCtrl.text) ?? 30,
        'license_warning_message': _licenseMsgCtrl.text,
      };
      await _settingsService.updateSettings(data);
      if (mounted) {
        // Force refresh license status if needed
        // Provider.of<LicenseProvider>(context, listen: false).checkLicense();
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lp.translate('settingsUpdated')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lp.translate('errorUpdating')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadLicenseStatus() async {
    try {
      final status = await _adminService.getLicenseStatus();
      if (mounted) {
        setState(() {
          _licenseStatus = status;
          // Extract expiration date if available
          final expiryDate = status['expiration_date'];
          if (expiryDate != null) {
            _licenseExpiryDateCtrl.text = expiryDate.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur loadLicenseStatus: $e');
    }
  }

  String _licenseFeatureSummary(LanguageProvider language) {
    final features = _licenseStatus?['available_features'];
    if (features is! List || features.isEmpty) return '—';
    return features.map((feature) {
      switch (feature) {
        case 'customer_management':
          return language.translate('customerManagement');
        case 'customer_loyalty':
          return language.translate('customerLoyalty');
        case 'cloud_sync':
          return language.translate('cloudSync');
        case 'sales_discounts':
          return language.translate('salesDiscounts');
        case 'insurance_sales':
          return language.translate('insuranceSales');
        case 'sales_reports':
          return language.translate('salesReports');
        case 'report_exports':
          return language.translate('reportExports');
        case 'financial_reports':
          return language.translate('financialReports');
        case 'stock_movements':
          return language.translate('stockMovements');
        case 'inventory_reconciliation':
          return language.translate('inventoryReconciliation');
        case 'audit_logs':
          return language.translate('auditLogs');
        case 'extended_sales_history':
          return language.translate('extendedSalesHistory');
        default:
          return feature.toString();
      }
    }).join(', ');
  }

  Future<void> _updateLicenseExpiry() async {
    // Validate date format
    if (_licenseExpiryDateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer une date d\'expiration'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _adminService.updateLicense(
        expirationDate: _licenseExpiryDateCtrl.text,
        warningDays: int.tryParse(_licenseDaysCtrl.text),
        warningMessage: _licenseMsgCtrl.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Licence mise à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload license status
        await _loadLicenseStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetData(bool sales, bool products, bool users) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    if (!await _confirm(
      lp.translate('deleteIrreversibleConfirm'),
      lp.translate('deleteDataConfirm'),
    )) {
      return;
    }
    try {
      await _adminService.resetData(
        sales: sales,
        products: products,
        users: users,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lp.translate('dataResetSuccess')),
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

  Future<bool> _confirm(String title, String content) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(lp.translate('no')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(
                  lp.translate('yes'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final isSuperAdmin =
        Provider.of<AuthProvider>(context).user?.role == 'super_admin';
    final tabCount = isSuperAdmin ? 3 : 2;

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          // TabBar
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: [
                Tab(
                  icon: const Icon(Icons.business),
                  text: lp.translate('general'),
                ),
                const Tab(
                  icon: Icon(Icons.receipt_long),
                  text: 'Fiscalité OBR (EBMS)',
                ),
                if (isSuperAdmin)
                  Tab(
                    icon: const Icon(Icons.security),
                    text: lp.translate('administration'),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              children: [
                // 1. General
                _isLoadingSettings
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lp.translate('pharmacyIdentity'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _input(
                                lp.translate('pharmacyName'),
                                _pharmacyNameCtrl,
                              ),
                              _input(lp.translate('address'), _addressCtrl),
                              _input(lp.translate('phone'), _phoneCtrl),
                              _input('NIF', _nifCtrl),
                              _input(lp.translate('logoPath'), _logoUrlCtrl, required: false),
                              const SizedBox(height: 24),
                              Text(
                                lp.translate('salesConfig'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _input(lp.translate('currency'), _currencyCtrl),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saveSettings,
                                  icon: const Icon(Icons.save),
                                  label: Text(lp.translate('save')),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                // 2. Fiscalité OBR (EBMS)
                _buildObrFiscalTab(lp),

                // 3. Admin (Zone Danger)
                if (isSuperAdmin)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // === STATUT DE LA LICENCE ===
                        const Text(
                          'Statut de la Licence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Display current license status
                        if (_licenseStatus != null) ...[
                          Card(
                            color: _licenseStatus!['is_expired'] == true
                                ? Colors.red[50]
                                : (_licenseStatus!['days_remaining'] != null &&
                                      _licenseStatus!['days_remaining'] < 30)
                                ? Colors.orange[50]
                                : Colors.green[50],
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _licenseStatus!['is_expired'] == true
                                            ? Icons.error
                                            : Icons.check_circle,
                                        color:
                                            _licenseStatus!['is_expired'] ==
                                                true
                                            ? Colors.red
                                            : Colors.green,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _licenseStatus!['is_expired'] ==
                                                      true
                                                  ? 'Licence Expirée'
                                                  : 'Licence Active',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color:
                                                    _licenseStatus!['is_expired'] ==
                                                        true
                                                    ? Colors.red
                                                    : Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Jours restants: ${_licenseStatus!['days_remaining'] ?? 0}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${lp.translate('platformPlan')}: ${(_licenseStatus!['plan'] ?? '—').toString().toUpperCase()}',
                                  ),
                                  Text(
                                    '${lp.translate('platformUsers')}: ${_licenseStatus!['active_users'] ?? 0} / ${(_licenseStatus!['max_users'] ?? 0) >= 1000 ? lp.translate('unlimited') : _licenseStatus!['max_users'] ?? 0}',
                                  ),
                                  Text(
                                    '${lp.translate('planFeatures')}: ${_licenseFeatureSummary(lp)}',
                                  ),
                                  if (_licenseStatus!['message'] != null) ...[
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Text(
                                      _licenseStatus!['message'],
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // === RENOUVELLEMENT DE LA LICENCE ===
                        const Text(
                          'Renouvellement de la Licence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _input(
                          'Date d\'expiration (YYYY-MM-DD)',
                          _licenseExpiryDateCtrl,
                        ),

                        const SizedBox(height: 8),
                        Text(
                          'Format: 2027-12-31 (Année-Mois-Jour)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _updateLicenseExpiry,
                            icon: const Icon(Icons.update),
                            label: const Text('Renouveler la Licence'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(),
                        ),

                        // === CONFIGURATION LICENCE ===
                        const Text(
                          'Configuration Licence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _input(
                          'Jours avant alerte',
                          _licenseDaysCtrl,
                          numeric: true,
                        ),
                        _input(
                          'Durée alerte (sec)',
                          _licenseDurationCtrl,
                          numeric: true,
                        ),
                        _input('Message alerte', _licenseMsgCtrl, maxLines: 2),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _saveAdminSettings,
                          child: const Text('Enregistrer Config'),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(),
                        ),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(
                                    lp.translate('dangerZone'),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(lp.translate('irreversibleActions')),
                              const SizedBox(height: 16),
                              const SizedBox(height: 16),
                              Text(lp.translate('selectDataToDelete')),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                title: Text(lp.translate('clearSalesHistory')),
                                value: _resetSales,
                                onChanged: (v) =>
                                    setState(() => _resetSales = v ?? false),
                                activeColor: Colors.red,
                              ),
                              CheckboxListTile(
                                title: Text(lp.translate('clearStock')),
                                value: _resetStock,
                                onChanged: (v) =>
                                    setState(() => _resetStock = v ?? false),
                                activeColor: Colors.red,
                              ),
                              CheckboxListTile(
                                title: Text(lp.translate('clearUsers')),
                                value: _resetUsers,
                                onChanged: (v) =>
                                    setState(() => _resetUsers = v ?? false),
                                activeColor: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (_resetSales ||
                                          _resetStock ||
                                          _resetUsers)
                                      ? () => _resetData(
                                          _resetSales,
                                          _resetStock,
                                          _resetUsers,
                                        )
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(Icons.delete_forever),
                                  label: Text(
                                    lp.translate('confirmDeleteButton'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController ctrl, {
    bool numeric = false,
    int maxLines = 1,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        validator: (v) => (required && (v == null || v.isEmpty)) ? 'Requis' : null,
      ),
    );
  }

  Future<void> _loadObrStatus() async {
    setState(() => _isLoadingObr = true);
    try {
      final status = await _obrService.getStatus();
      setState(() {
        _obrStatusData = status;
        _obrEnabled = status['obr_enabled'] == true;
        _obrEnvironment = (status['environment'] as String?) ?? 'sandbox';
        _obrNifCtrl.text = (status['nif'] as String?) ?? '';
        _obrRcCtrl.text = (status['rc_number'] as String?) ?? '';
        _obrTaxCenterCtrl.text = (status['tax_center'] as String?) ?? 'DMC';
        _obrSystemIdCtrl.text = (status['obr_system_id'] as String?) ?? '';
        _obrUsernameCtrl.text = (status['obr_api_username'] as String?) ?? '';
        _obrLegalFormCtrl.text = (status['tp_legal_form'] as String?) ?? 'SUARL';
        _obrActivitySectorCtrl.text = (status['tp_activity_sector'] as String?) ?? 'Commerce de détail de produits pharmaceutiques';
        _obrProvinceCtrl.text = (status['tp_address_province'] as String?) ?? 'BUJUMBURA MAIRIE';
        _obrCommuneCtrl.text = (status['tp_address_commune'] as String?) ?? 'MUKAZA';
        _obrQuartierCtrl.text = (status['tp_address_quartier'] as String?) ?? 'ROHERO';
        _obrAvenueCtrl.text = (status['tp_address_avenue'] as String?) ?? '';
        _obrRueCtrl.text = (status['tp_address_rue'] as String?) ?? '';
        _obrNumberCtrl.text = (status['tp_address_number'] as String?) ?? '';
        _obrTpType = (status['tp_type'] as String?) ?? '2';
        _obrVatTaxpayer = status['vat_taxpayer'] == '1';
        _obrCtTaxpayer = status['ct_taxpayer'] == '1';
        _obrTlTaxpayer = status['tl_taxpayer'] == '1';
        _isLoadingObr = false;
      });
    } catch (e) {
      debugPrint('Erreur loadObrStatus: ');
      setState(() => _isLoadingObr = false);
    }
  }

  Future<void> _saveObrConfig() async {
    setState(() => _isSavingObr = true);
    try {
      final payload = {
        'obr_enabled': _obrEnabled,
        'environment': _obrEnvironment,
        'nif': _obrNifCtrl.text.trim(),
        'rc_number': _obrRcCtrl.text.trim(),
        'tax_center': _obrTaxCenterCtrl.text.trim(),
        'obr_system_id': _obrSystemIdCtrl.text.trim(),
        'obr_api_username': _obrUsernameCtrl.text.trim(),
        'tp_type': _obrTpType,
        'tp_legal_form': _obrLegalFormCtrl.text.trim(),
        'tp_activity_sector': _obrActivitySectorCtrl.text.trim(),
        'tp_address_province': _obrProvinceCtrl.text.trim(),
        'tp_address_commune': _obrCommuneCtrl.text.trim(),
        'tp_address_quartier': _obrQuartierCtrl.text.trim(),
        'tp_address_avenue': _obrAvenueCtrl.text.trim(),
        'tp_address_rue': _obrRueCtrl.text.trim(),
        'tp_address_number': _obrNumberCtrl.text.trim(),
        'vat_taxpayer': _obrVatTaxpayer ? '1' : '0',
        'ct_taxpayer': _obrCtTaxpayer ? '1' : '0',
        'tl_taxpayer': _obrTlTaxpayer ? '1' : '0',
      };
      if (_obrPasswordCtrl.text.isNotEmpty) {
        payload['obr_api_password'] = _obrPasswordCtrl.text.trim();
      }
      await _obrService.updateConfig(payload);
      _nifCtrl.text = _obrNifCtrl.text.trim();
      await _loadObrStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres fiscaux OBR enregistrés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement OBR: '),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingObr = false);
    }
  }

  Future<void> _testObrConnection() async {
    setState(() {
      _isTestingObr = true;
      _obrTestResult = null;
      _obrTestSuccess = null;
    });
    try {
      await _saveObrConfig();
      final result = await _obrService.testConnection();
      setState(() {
        _obrTestSuccess = result['success'] == true;
        _obrTestResult = result['message'] as String? ?? 'Réponse reçue.';
        _isTestingObr = false;
      });
    } catch (e) {
      setState(() {
        _obrTestSuccess = false;
        _obrTestResult = 'Échec de test de connexion: ';
        _isTestingObr = false;
      });
    }
  }

  Future<void> _resyncPendingInvoices() async {
    setState(() => _isResyncingObr = true);
    try {
      final res = await _obrService.resyncPendingInvoices();
      await _loadObrStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synchronisation OBR: ${res["synced"] ?? 0} facture(s) transmise(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur retransmission OBR: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResyncingObr = false);
    }
  }

  Widget _buildObrFiscalTab(LanguageProvider lp) {
    if (_isLoadingObr) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalSales = _obrStatusData?['total_sales'] ?? 0;
    final syncedInvoices = _obrStatusData?['synced_invoices'] ?? 0;
    final pendingInvoices = _obrStatusData?['pending_invoices'] ?? 0;
    final errorInvoices = _obrStatusData?['error_invoices'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête officiel
          Card(
            elevation: 1,
            color: const Color(0xFFF0FDF4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFBBF7D0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Facturation Électronique EBMS — OBR Burundi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Conformité fiscale certifiée avec signature électronique SHA-256, QR Code officiel et transmission temps réel ou différée.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Activation & Mode
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Régime Fiscal & Environnement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Activer le module fiscal OBR (EBMS)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Scelle les factures et tickets avec signature électronique et QR Code de conformité.',
                    ),
                    value: _obrEnabled,
                    activeColor: AppTheme.successColor,
                    onChanged: (val) {
                      setState(() => _obrEnabled = val);
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Environnement serveur OBR',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Sandbox pour tester sans incidence fiscale, ou Production pour les déclarations réelles.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: _obrEnvironment,
                          items: const [
                            DropdownMenuItem(
                              value: 'sandbox',
                              child: Text('🧪 Test (Sandbox - ebms-test)'),
                            ),
                            DropdownMenuItem(
                              value: 'production',
                              child: Text('🏛️ Réel (Production - ebms.obr)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _obrEnvironment = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Compteurs en direct
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Compteurs de Facturation Fiscale',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isResyncingObr ? null : _resyncPendingInvoices,
                        icon: _isResyncingObr
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sync, size: 16),
                        label: Text(_isResyncingObr ? 'Transmission...' : 'Retransmettre les factures'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      return isNarrow
                          ? Column(
                              children: [
                                _statBox('Total Ventes', '$totalSales', Colors.blue, Icons.receipt),
                                const SizedBox(height: 10),
                                _statBox('Transmises OBR', '$syncedInvoices', Colors.green, Icons.cloud_done),
                                const SizedBox(height: 10),
                                _statBox('En attente (Signé local)', '$pendingInvoices', Colors.orange, Icons.schedule),
                                const SizedBox(height: 10),
                                _statBox('En anomalie', '$errorInvoices', Colors.red, Icons.error_outline),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _statBox('Total Ventes', '$totalSales', Colors.blue, Icons.receipt)),
                                const SizedBox(width: 12),
                                Expanded(child: _statBox('Transmises OBR', '$syncedInvoices', Colors.green, Icons.cloud_done)),
                                const SizedBox(width: 12),
                                Expanded(child: _statBox('En attente', '$pendingInvoices', Colors.orange, Icons.schedule)),
                                const SizedBox(width: 12),
                                Expanded(child: _statBox('En anomalie', '$errorInvoices', Colors.red, Icons.error_outline)),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Diagnostic du test de connexion
          if (_obrTestResult != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _obrTestSuccess == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _obrTestSuccess == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _obrTestSuccess == true ? Icons.check_circle : Icons.error,
                    color: _obrTestSuccess == true ? Colors.green[700] : Colors.red[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _obrTestResult!,
                      style: TextStyle(
                        color: _obrTestSuccess == true ? Colors.green[900] : Colors.red[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Formulaire d'identification fiscale
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Identifiants Fiscaux & Connexion API OBR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _input('NIF (Numéro d\'Identification Fiscale de l\'officine)', _obrNifCtrl),
                  _input('N° Registre de Commerce (RC)', _obrRcCtrl, required: false),
                  _input('Centre Fiscal d\'attachement (ex: DMC, DPMC)', _obrTaxCenterCtrl),
                  _input('Identifiant Système OBR (system_id)', _obrSystemIdCtrl, required: false),
                  _input('Nom d\'utilisateur API OBR (username)', _obrUsernameCtrl, required: false),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      controller: _obrPasswordCtrl,
                      obscureText: _obscureObrPassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe API OBR (password)',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureObrPassword ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() => _obscureObrPassword = !_obscureObrPassword);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Section Statut & Forme Juridique V0.5
                  const Text(
                    'Statut Légal & Régimes Fiscaux (EBMS V0.5)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Type de Contribuable',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _obrTpType,
                              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: '2', child: Text('Personne Morale (Société/Officine)')),
                                DropdownMenuItem(value: '1', child: Text('Personne Physique (Individuel)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _obrTpType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _input('Forme Juridique (ex: SUARL, SA, SPRL)', _obrLegalFormCtrl),
                      ),
                    ],
                  ),
                  _input('Secteur d\'Activité Officiel', _obrActivitySectorCtrl),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Assujetti TVA (18%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: _obrVatTaxpayer,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.successColor,
                          onChanged: (val) => setState(() => _obrVatTaxpayer = val ?? true),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Assujetti Taxe Conso (TC)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: _obrCtTaxpayer,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.successColor,
                          onChanged: (val) => setState(() => _obrCtTaxpayer = val ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Assujetti Taxe Loc. (TL)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: _obrTlTaxpayer,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppTheme.successColor,
                          onChanged: (val) => setState(() => _obrTlTaxpayer = val ?? false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Section Adresse Fiscale Obligatoire OBR
                  const Text(
                    'Localisation Fiscale Officielle (Obligatoire EBMS)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _input('Province Fiscale', _obrProvinceCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Commune Fiscale', _obrCommuneCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Quartier Fiscal', _obrQuartierCtrl)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _input('Avenue', _obrAvenueCtrl, required: false)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('Rue', _obrRueCtrl, required: false)),
                      const SizedBox(width: 12),
                      Expanded(child: _input('N° Parcelle / Porte', _obrNumberCtrl, required: false)),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isSavingObr ? null : _saveObrConfig,
                        icon: _isSavingObr
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSavingObr ? 'Enregistrement...' : 'Enregistrer les paramètres fiscaux'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _isTestingObr ? null : _testObrConnection,
                        icon: _isTestingObr
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check),
                        label: Text(_isTestingObr ? 'Test en cours...' : 'Tester la connexion OBR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}

