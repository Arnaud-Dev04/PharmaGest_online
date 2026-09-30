import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/services/settings_service.dart'; // AdminService is here

import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/license_provider.dart';
import 'package:frontend1/widgets/audit/deletion_logs_dialog.dart';

class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isChangingPwd = false;

  // License Data
  String _expiryDate = '';
  bool _isValid = false;
  int _daysRemaining = 0;

  final TextEditingController _dateCtrl = TextEditingController();

  // Change Password
  final TextEditingController _newPwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();
  bool _showNewPwd = false;
  bool _showConfirmPwd = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPwd = _newPwdCtrl.text.trim();
    final confirmPwd = _confirmPwdCtrl.text.trim();

    if (newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un nouveau mot de passe'), backgroundColor: Colors.red),
      );
      return;
    }
    if (newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères'), backgroundColor: Colors.red),
      );
      return;
    }
    if (newPwd != confirmPwd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isChangingPwd = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;
      final response = await _adminService.changePassword(
        newPassword: newPwd,
        token: token ?? '',
      );
      if (mounted) {
        _newPwdCtrl.clear();
        _confirmPwdCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Mot de passe mis à jour'),
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
    } finally {
      if (mounted) setState(() => _isChangingPwd = false);
    }
  }

  Future<void> _checkAuthAndLoad() async {
    // Check Role
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user?.role != 'super_admin') {
      // Redirect or Show Error
      // Since we are in init, wait for build
      await Future.delayed(Duration.zero);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).translate('accessDeniedSuperAdmin'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _loadLicense();
  }

  Future<void> _loadLicense() async {
    setState(() => _isLoading = true);
    try {
      final data = await _adminService.getLicenseStatus();
      setState(() {
        _expiryDate = data['expiration_date'] ?? '';
        _isValid = data['is_valid'] ?? false;
        _daysRemaining = data['days_remaining'] ?? 0;
        _dateCtrl.text = _expiryDate;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lp.translate('errorLoadingLicense')}: $e')),
        );
      }
    }
  }

  Future<void> _updateLicense() async {
    setState(() => _isUpdating = true);
    try {
      await _adminService.updateLicense(expirationDate: _dateCtrl.text);
      if (mounted) {
        // Reload license status to get updated data
        await _loadLicense();
      }
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lp.translate('licenseUpdated')),
            backgroundColor: Colors.green,
          ),
        );
        Provider.of<LicenseProvider>(context, listen: false).checkLicense();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lp.translate('updateError')}: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate.isNotEmpty
          ? DateTime.tryParse(_expiryDate) ?? now
          : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      // Format YYYY-MM-DD
      final formatted =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _dateCtrl.text = formatted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Column(
      children: [
        // Simple Header inside the layout
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.shield, size: 32, color: AppTheme.primaryColor),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lp.translate('superAdmin'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    lp.translate('softwareLicenseManagement'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // ── Carte Licence ──
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Box
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange[800]),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lp.translate('currentLicenseStatus'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${lp.translate('expiresOn')}: $_expiryDate",
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _isValid
                                              ? "${lp.translate('valid')} ($_daysRemaining ${lp.translate('daysRemaining')})"
                                              : lp.translate('expired'),
                                          style: TextStyle(
                                            color: _isValid
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Form
                              Text(
                                lp.translate('newExpirationDate'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickDate,
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _dateCtrl,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _isUpdating ? null : _updateLicense,
                                  icon: const Icon(Icons.save),
                                  label: _isUpdating
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Text(lp.translate('updateLicense')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Carte Traçabilité & Journal des Suppressions ──
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Journal des Suppressions',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Consultez la traçabilité complète : qui a supprimé un médicament, un lot ou annulé une facture.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => DeletionLogsDialog.show(context),
                                  icon: const Icon(Icons.history),
                                  label: const Text('Consulter les Suppressions'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Carte Changement de Mot de Passe ──
                  const SizedBox(height: 24),
                  Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 24),
                            const SizedBox(width: 12),
                            Text('Changer mon mot de passe',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          Text('En tant que Super Admin, vous pouvez changer votre mot de passe sans saisir l\'ancien.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          const SizedBox(height: 24),

                          // Nouveau mot de passe
                          const Text('Nouveau mot de passe', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _newPwdCtrl,
                            obscureText: !_showNewPwd,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock),
                              border: const OutlineInputBorder(),
                              hintText: 'Minimum 6 caractères',
                              suffixIcon: IconButton(
                                icon: Icon(_showNewPwd ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _showNewPwd = !_showNewPwd),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Confirmation
                          const Text('Confirmer le mot de passe', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _confirmPwdCtrl,
                            obscureText: !_showConfirmPwd,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              hintText: 'Répéter le mot de passe',
                              suffixIcon: IconButton(
                                icon: Icon(_showConfirmPwd ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _showConfirmPwd = !_showConfirmPwd),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isChangingPwd ? null : _changePassword,
                              icon: const Icon(Icons.key),
                              label: _isChangingPwd
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Mettre à jour le mot de passe'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),         // ferme Center(password card)
            ],           // ferme Column(children: [...])
          ),             // ferme Column
        ),               // ferme SingleChildScrollView
      ),                 // ferme Expanded
      ],                 // ferme outer Column children
    );                   // ferme outer Column
  }
}
