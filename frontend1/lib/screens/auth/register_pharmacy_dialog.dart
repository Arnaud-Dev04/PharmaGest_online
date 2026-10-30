import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/services/platform_admin_service.dart';

class RegisterPharmacyDialog extends StatefulWidget {
  final void Function(String pharmacyCode, String username)? onRegistered;

  const RegisterPharmacyDialog({super.key, this.onRegistered});

  static Future<void> show(
    BuildContext context, {
    void Function(String pharmacyCode, String username)? onRegistered,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RegisterPharmacyDialog(onRegistered: onRegistered),
    );
  }

  @override
  State<RegisterPharmacyDialog> createState() => _RegisterPharmacyDialogState();
}

class _RegisterPharmacyDialogState extends State<RegisterPharmacyDialog> {
  final _service = PlatformAdminService();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Étape 1 : Officine
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController(text: 'BUJUMBURA MAIRIE');
  final _communeCtrl = TextEditingController(text: 'MUKAZA');
  final _quartierCtrl = TextEditingController(text: 'ROHERO');

  // Étape 2 : Responsable (Admin)
  final _adminUserCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _adminPassConfirmCtrl = TextEditingController();
  bool _obscurePassword = true;

  // Étape 3 : Fiscalité & OBR
  final _nifCtrl = TextEditingController();
  final _rcCtrl = TextEditingController();
  String _taxCenter = 'DPMC';
  String _tpType = '2'; // 1: Physique, 2: Morale
  String _legalForm = 'SUARL';
  String _vatTaxpayer = '1';
  String _ctTaxpayer = '0';

  // Étape 4 : Plan souhaité
  String _selectedPlan = 'basic';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _provinceCtrl.dispose();
    _communeCtrl.dispose();
    _quartierCtrl.dispose();
    _adminUserCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminPassConfirmCtrl.dispose();
    _nifCtrl.dispose();
    _rcCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_codeCtrl.text.isEmpty || _codeCtrl.text.startsWith('PHARM-')) {
      final slug = val.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      if (slug.isNotEmpty) {
        _codeCtrl.text = 'PHARM-${slug.length > 8 ? slug.substring(0, 8) : slug}';
      }
    }
  }

  bool _validateCurrentStep() {
    setState(() => _errorMessage = null);
    if (_currentStep == 0) {
      if (_nameCtrl.text.trim().length < 2) {
        setState(() => _errorMessage = 'Veuillez saisir le nom de la pharmacie');
        return false;
      }
      if (_phoneCtrl.text.trim().length < 4) {
        setState(() => _errorMessage = 'Veuillez renseigner un numéro de téléphone valide');
        return false;
      }
      if (_emailCtrl.text.trim().length < 5 || !_emailCtrl.text.contains('@')) {
        setState(() => _errorMessage = 'Veuillez renseigner une adresse email valide');
        return false;
      }
    } else if (_currentStep == 1) {
      if (_adminUserCtrl.text.trim().length < 3) {
        setState(() => _errorMessage = 'L\'identifiant admin doit comporter au moins 3 caractères');
        return false;
      }
      if (_adminPassCtrl.text.length < 6) {
        setState(() => _errorMessage = 'Le mot de passe doit comporter au moins 6 caractères');
        return false;
      }
      if (_adminPassCtrl.text != _adminPassConfirmCtrl.text) {
        setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
        return false;
      }
    } else if (_currentStep == 2) {
      if (_nifCtrl.text.trim().length < 4) {
        setState(() => _errorMessage = 'Le NIF (Numéro d\'Identité Fiscale) est requis pour l\'OBR');
        return false;
      }
    }
    return true;
  }

  Future<void> _submitRegistration() async {
    if (!_validateCurrentStep()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim().toUpperCase(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'country': 'Burundi',
        'city': 'Bujumbura',
        'admin_username': _adminUserCtrl.text.trim(),
        'admin_password': _adminPassCtrl.text,
        'admin_name': _adminNameCtrl.text.trim().isEmpty ? null : _adminNameCtrl.text.trim(),
        'nif': _nifCtrl.text.trim(),
        'rc_number': _rcCtrl.text.trim().isEmpty ? null : _rcCtrl.text.trim(),
        'tax_center': _taxCenter,
        'tp_type': _tpType,
        'tp_legal_form': _legalForm,
        'tp_activity_sector': 'Commerce de détail de produits pharmaceutiques',
        'tp_address_province': _provinceCtrl.text.trim(),
        'tp_address_commune': _communeCtrl.text.trim(),
        'tp_address_quartier': _quartierCtrl.text.trim(),
        'vat_taxpayer': _vatTaxpayer,
        'ct_taxpayer': _ctTaxpayer,
        'tl_taxpayer': '0',
        'plan': _selectedPlan,
      };

      final res = await _service.registerPharmacy(payload);
      if (!mounted) return;

      final pCode = res['pharmacy_code']?.toString() ?? _codeCtrl.text.trim();
      final pUname = res['admin_username']?.toString() ?? _adminUserCtrl.text.trim();

      Navigator.of(context).pop();
      _showSuccessDialog(pCode, pUname);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  void _showSuccessDialog(String pharmacyCode, String adminUsername) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
            ),
            const SizedBox(height: 20),
            const Text(
              'Demande d\'inscription envoyée !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Votre demande pour la pharmacie « ${_nameCtrl.text.trim()} » a été enregistrée avec succès.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _infoRow('Code Pharmacie', pharmacyCode, isCopyable: true),
                  const Divider(height: 16),
                  _infoRow('Identifiant Admin', adminUsername),
                  const Divider(height: 16),
                  _infoRow('Formule demandée', _selectedPlan.toUpperCase()),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Statut : En attente d\'approbation',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'L\'administrateur de la plateforme activera votre période d\'essai gratuite et vous remettra votre clé d\'activation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onRegistered?.call(pharmacyCode, adminUsername);
                },
                child: const Text('Compris, retourner à la connexion'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isCopyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Row(
          children: [
            SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (isCopyable) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copier',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code pharmacie copié !'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.app_registration_rounded, color: AppTheme.primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inscription d\'une nouvelle Pharmacie',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rejoignez le réseau PharmaGest — Période d\'essai gratuite incluse',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stepper Indicator
              _buildStepIndicator(),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Content Body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: switch (_currentStep) {
                      0 => _buildStep1Pharmacy(),
                      1 => _buildStep2Admin(),
                      2 => _buildStep3OBR(),
                      _ => _buildStep4Plan(),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Précédent'),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep < 3)
                        FilledButton.icon(
                          onPressed: () {
                            if (_validateCurrentStep()) {
                              setState(() => _currentStep++);
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text('Suivant'),
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: _isLoading ? null : _submitRegistration,
                          icon: _isLoading
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(_isLoading ? 'Inscription...' : 'Confirmer mon inscription'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['1. Officine', '2. Responsable', '3. Fiscalité OBR', '4. Formule'];
    return Row(
      children: List.generate(steps.length, (idx) {
        final isActive = idx == _currentStep;
        final isDone = idx < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryColor
                        : (isDone ? Colors.green.shade600 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      steps[idx],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (isActive || isDone) ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              if (idx < steps.length - 1) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }

  // -------------------------------------------------------------
  // Step 1 : Officine
  // -------------------------------------------------------------
  Widget _buildStep1Pharmacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations Générales de l\'Officine',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom de la Pharmacie *',
            hintText: 'Ex: Pharmacie du Peuple',
            prefixIcon: Icon(Icons.storefront_outlined),
            border: OutlineInputBorder(),
          ),
          onChanged: _onNameChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Code Pharmacie (identifiant unique) *',
            hintText: 'Ex: PHARM-PEUPLE',
            prefixIcon: Icon(Icons.tag_rounded),
            helperText: 'Sera utilisé par vos collaborateurs pour se connecter',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Téléphone Officine *',
                  hintText: '+257 ...',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Officine *',
                  hintText: 'contact@pharmacie.bi',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
            labelText: 'Adresse physique / Boulevard',
            hintText: 'Ex: Boulevard du 28 Novembre',
            prefixIcon: Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _provinceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _communeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Commune',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _quartierCtrl,
                decoration: const InputDecoration(
                  labelText: 'Quartier',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 2 : Admin / Responsable
  // -------------------------------------------------------------
  Widget _buildStep2Admin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Administrateur Initial (Pharmacien Titulaire)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          'Ce compte disposera de tous les droits de gestion et de configuration de votre pharmacie.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom et Prénom du Pharmacien Titulaire',
            hintText: 'Ex: Dr. Jean Dupont',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _adminUserCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom d\'utilisateur administrateur *',
            hintText: 'Ex: admin_jean',
            prefixIcon: Icon(Icons.account_circle_outlined),
            helperText: 'Identifiant de connexion personnel',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _adminPassCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe administrateur *',
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: 'Au moins 6 caractères',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _adminPassConfirmCtrl,
          obscureText: _obscurePassword,
          decoration: const InputDecoration(
            labelText: 'Confirmez le mot de passe *',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 3 : Fiscalité & OBR
  // -------------------------------------------------------------
  Widget _buildStep3OBR() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Identifiants Fiscaux & OBR Burundi 🇧🇮',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('EBMS V0.5', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Nécessaire pour la conformité avec la facturation électronique de l\'Office Burundais des Recettes.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nifCtrl,
                decoration: const InputDecoration(
                  labelText: 'NIF (Numéro d\'Identité Fiscale) *',
                  hintText: 'Ex: 4001234567',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _rcCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numéro Registre de Commerce (RC)',
                  hintText: 'Ex: 12345/2023',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _taxCenter,
                decoration: const InputDecoration(
                  labelText: 'Centre Fiscal Gestionnaire',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'DPMC', child: Text('DPMC - Moyennes Entreprises')),
                  DropdownMenuItem(value: 'DMC', child: Text('DMC - Grandes Entreprises')),
                  DropdownMenuItem(value: 'DPC', child: Text('DPC - Petites Entreprises')),
                ],
                onChanged: (val) => setState(() => _taxCenter = val ?? 'DPMC'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _legalForm,
                decoration: const InputDecoration(
                  labelText: 'Forme Juridique',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'SUARL', child: Text('SUARL')),
                  DropdownMenuItem(value: 'SPRL', child: Text('SPRL')),
                  DropdownMenuItem(value: 'SA', child: Text('SA')),
                  DropdownMenuItem(value: 'EI', child: Text('Entreprise Individuelle')),
                ],
                onChanged: (val) => setState(() => _legalForm = val ?? 'SUARL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tpType,
                decoration: const InputDecoration(
                  labelText: 'Type de Contribuable',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '2', child: Text('Personne Morale (Société)')),
                  DropdownMenuItem(value: '1', child: Text('Personne Physique (Individu)')),
                ],
                onChanged: (val) => setState(() => _tpType = val ?? '2'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _vatTaxpayer,
                decoration: const InputDecoration(
                  labelText: 'Assujetti à la TVA',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('Oui (Assujetti TVA 18%)')),
                  DropdownMenuItem(value: '0', child: Text('Non (Exonéré)')),
                ],
                onChanged: (val) => setState(() => _vatTaxpayer = val ?? '1'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 4 : Plan & Offre
  // -------------------------------------------------------------
  Widget _buildStep4Plan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisissez votre Formule d\'Abonnement',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🎁 Période d\'essai gratuite incluse ! Sans engagement. L\'administrateur validera votre compte.',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _planCard(
          planId: 'basic',
          title: 'Plan Petit (Basic)',
          subtitle: 'Pour les officines indépendantes et démarrages',
          features: [
            '1 Caisse / Comptoir de vente',
            'Jusqu\'à 3 utilisateurs',
            'Déstockage automatique FEFO (lots & péremptions)',
            'Facturation électronique OBR standard',
            'Gestion de caisse & Rapport Z',
          ],
        ),
        const SizedBox(height: 12),
        _planCard(
          planId: 'pro',
          title: 'Plan Moyen (Pro) — Populaire',
          subtitle: 'Pour les pharmacies établies à flux soutenu',
          isPopular: true,
          features: [
            'Multi-caisses réseau (jusqu\'à 5 caisses)',
            'Jusqu\'à 10 utilisateurs simultanés',
            'Prise en charge Assurances & Tiers-Payant',
            'Rapports financiers, marges & exports Excel',
            'Historique complet des mouvements de stock',
          ],
        ),
        const SizedBox(height: 12),
        _planCard(
          planId: 'enterprise',
          title: 'Plan Entreprise',
          subtitle: 'Pour les grandes pharmacies et réseaux',
          features: [
            'Caisses et utilisateurs illimités',
            'Multi-dépôts & réapprovisionnement réseau',
            'Programme de fidélité & crédits clients avancés',
            'Journal d\'audit immuable & alertes prédictives',
            'Support prioritaire 24/7 & haute disponibilité',
          ],
        ),
      ],
    );
  }

  Widget _planCard({
    required String planId,
    required String title,
    required String subtitle,
    required List<String> features,
    bool isPopular = false,
  }) {
    final isSelected = _selectedPlan == planId;
    return InkWell(
      onTap: () => setState(() => _selectedPlan = planId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : (isPopular ? Colors.orange.shade300 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppTheme.primaryColor : Colors.black87,
                    ),
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: const Text('Recommandé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1.5),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

