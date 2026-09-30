import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/sale.dart';
import 'package:frontend1/models/app_settings.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/cart_provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/services/pos_service.dart';
import 'package:frontend1/services/settings_service.dart';
import 'package:frontend1/services/invoice_pdf_service.dart';
import 'package:frontend1/services/invoice_auto_service.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/error_helper.dart';

class PaymentModal extends StatefulWidget {
  final double totalAmount;
  final VoidCallback onSuccess;

  const PaymentModal({
    super.key,
    required this.totalAmount,
    required this.onSuccess,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final PosService _posService = PosService();
  final SettingsService _settingsService = SettingsService();

  String _paymentMethod = 'cash'; // 'cash' ou 'insurance'
  bool _isProcessing = false;

  // Champs Assurance
  final _insuranceProviderController = TextEditingController();
  final _insuranceCardIdController = TextEditingController();
  final _coveragePercentController = TextEditingController(text: '80');

  // Champs Client (optionnel)
  final _clientPrenomCtrl = TextEditingController();
  final _clientNomCtrl = TextEditingController();

  @override
  void dispose() {
    _insuranceProviderController.dispose();
    _insuranceCardIdController.dispose();
    _coveragePercentController.dispose();
    _clientPrenomCtrl.dispose();
    _clientNomCtrl.dispose();
    super.dispose();
  }

  /// Affiche un dialogue de confirmation avant de lancer le paiement
  Future<void> _confirmAndPay() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Validation Assurance
    if (_paymentMethod == 'insurance_card') {
      if (_insuranceProviderController.text.isEmpty ||
          _insuranceCardIdController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir les infos assurance')),
        );
        return;
      }
    }

    // Construire le résumé de la vente
    final paymentLabel = _paymentMethod == 'insurance_card'
        ? 'Assurance'
        : 'Espèces';
    final itemCount = cartProvider.items.length;
    final unitCount = cartProvider.itemCount;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.payment_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Confirmer le paiement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.totalAmount.toStringAsFixed(0)} FBu',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemCount produit${itemCount > 1 ? 's' : ''} · $unitCount unité${unitCount > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.credit_card, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Paiement: $paymentLabel',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
            if (cartProvider.customerName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Client: ${cartProvider.customerName}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Une facture sera générée et la vente sera enregistrée dans l\'historique.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Confirmer & Payer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // L'utilisateur a confirmé → lancer le traitement
    await _processPayment();
  }

  Future<void> _processPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    setState(() => _isProcessing = true);

    try {
      // STEP 1: Get FEFO allocations for each cart item
      final checkoutItems = <Map<String, dynamic>>[];

      for (final item in cartProvider.items) {
        // Call /pos/cart/add to get FEFO batch allocations
        final allocation = await _posService.cartAdd(
          item.medicine.id,
          item.quantity,
          level: item.level,
        );

        final allocations = allocation['allocations'] as List? ?? [];

        // Vérification critique: les allocations ne doivent pas être vides
        if (allocations.isEmpty) {
          throw Exception(
            'Stock insuffisant ou aucun lot disponible pour "${item.medicine.name}". '
            'Vérifiez le stock et les dates d\'expiration.',
          );
        }

        checkoutItems.add({
          'medicine_id': item.medicine.id,
          'allocations': allocations,
          'quantity': item.quantity,
          'level': item.level,
          'base_units': allocation['base_units'],
          'unit_price': item.effectiveUnitPrice,
          'discount_percent': item.discountPercent,  // Remise appliquée sur cet article
        });
      }

      // STEP 2: Call /pos/checkout with all allocations
      final typedClientName = [
        _clientPrenomCtrl.text.trim(),
        _clientNomCtrl.text.trim(),
      ].where((part) => part.isNotEmpty).join(' ');
      final customerName = typedClientName.isNotEmpty
          ? typedClientName
          : cartProvider.customerName.trim();

      final checkoutData = {
        'items': checkoutItems,
        'payment_method': _paymentMethod == 'insurance_card' ? 'insurance' : _paymentMethod,
        'customer_id': cartProvider.customerId,
        // Nom client optionnel (pour la facture)
        'customer_name': customerName.isNotEmpty
            ? customerName
            : null,
        // Insurance
        'insurance_provider': _paymentMethod == 'insurance_card'
            ? _insuranceProviderController.text
            : null,
        'insurance_card_id': _paymentMethod == 'insurance_card'
            ? _insuranceCardIdController.text
            : null,
        'coverage_percent': _paymentMethod == 'insurance_card'
            ? double.tryParse(_coveragePercentController.text) ?? 0
            : 0,
      };

      final response = await _posService.checkout(checkoutData);

      if (mounted) {
        // Parser la réponse en objet Sale
        final sale = Sale.fromJson(response);

        // Capturer les valeurs dépendantes du context AVANT les appels async
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        final sellerName = authProvider.user?.username ?? 'N/A';
        final navigator = Navigator.of(context);

        // Récupérer les paramètres de la pharmacie
        AppSettings settings;
        try {
          settings = await _settingsService.getSettings();
        } catch (_) {
          settings = AppSettings();
        }

        // ✅ FACTURATION AUTOMATIQUE :
        // Génération PDF + sauvegarde locale (autoOpen:false pour éviter
        // d'ouvrir le PDF système avant l'overlay de succès)
        final invoiceResult = await InvoiceAutoService.generateAndSave(
          sale: sale,
          settings: settings,
          sellerName: sellerName,
          autoOpen: false, // On gère l'ouverture depuis l'overlay
        );

        widget.onSuccess(); // Vider panier
        navigator.pop(); // Fermer modal paiement

        // ✅ Afficher l'overlay facture avec statut de sauvegarde
        _showInvoiceOverlay(sale, settings, sellerName, invoiceResult);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${ErrorHelper.extractErrorMessage(e)}'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Affiche un overlay plein écran avec les détails de la facture et le statut PDF
  void _showInvoiceOverlay(
    Sale sale,
    AppSettings settings,
    String sellerName,
    InvoiceAutoResult invoiceResult,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => _InvoiceOverlayDialog(
        sale: sale,
        settings: settings,
        sellerName: sellerName,
        invoiceResult: invoiceResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.translate('checkout'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Montant Total
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Montant à payer',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.totalAmount.toStringAsFixed(0)} FBu',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nom Client (optionnel)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Client (optionnel)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _clientPrenomCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Prénom',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _clientNomCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Méthode de Paiement
            Text(
              languageProvider.translate('paymentMethod'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPaymentOption('cash', 'Espèces', Icons.payments),
                const SizedBox(width: 12),
                _buildPaymentOption(
                  'insurance_card',
                  'Assurance',
                  Icons.card_membership,
                ),
              ],
            ),

            // Formulaire Assurance
            if (_paymentMethod == 'insurance_card') ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _insuranceProviderController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'assurance / Mutuelle',
                        isDense: true,
                        hintText: 'Ex: MUGEFCI, AXA...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _insuranceCardIdController,
                      decoration: const InputDecoration(
                        labelText: 'N° Carte / Matricule',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _coveragePercentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Taux couvert (%)',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Builder(
                            builder: (context) {
                              final percent =
                                  double.tryParse(
                                    _coveragePercentController.text,
                                  ) ??
                                  0;
                              final partAssurance =
                                  (widget.totalAmount * percent) / 100;
                              final partPatient =
                                  widget.totalAmount - partAssurance;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Assurance: ${partAssurance.toStringAsFixed(0)} FBu',
                                    style: const TextStyle(
                                      color: AppTheme.successColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Patient: ${partPatient.toStringAsFixed(0)} FBu',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(languageProvider.translate('cancel')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmAndPay,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(languageProvider.translate('pay')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// OVERLAY FACTURE — Affiché 5 secondes après un paiement réussi
// ═══════════════════════════════════════════════════════════════════

class _InvoiceOverlayDialog extends StatefulWidget {
  final Sale sale;
  final AppSettings settings;
  final String sellerName;
  final InvoiceAutoResult invoiceResult;

  const _InvoiceOverlayDialog({
    required this.sale,
    required this.settings,
    required this.sellerName,
    required this.invoiceResult,
  });

  @override
  State<_InvoiceOverlayDialog> createState() => _InvoiceOverlayDialogState();
}

class _InvoiceOverlayDialogState extends State<_InvoiceOverlayDialog>
    with SingleTickerProviderStateMixin {
  int _countdown = 5;
  Timer? _timer;
  late AnimationController _checkAnimController;
  late Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnim = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.elasticOut,
    );
    _checkAnimController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkAnimController.dispose();
    super.dispose();
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Espèces';
      case 'insurance':
      case 'insurance_card':
        return 'Assurance';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header vert succès ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF00E676)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _checkAnim,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Vente enregistrée !',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Facture ${sale.code}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Corps ───
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Montant total
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sale.totalAmount.toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info row
                    Row(
                      children: [
                        _infoChip(Icons.credit_card, _paymentLabel(sale.paymentMethod)),
                        const SizedBox(width: 8),
                        if (sale.customerName != null && sale.customerName!.isNotEmpty)
                          _infoChip(Icons.person, sale.customerName!),
                        // Badge remise si applicable
                        Builder(builder: (_) {
                          final hasDiscount = sale.items.any((i) => i.discountPercent > 0);
                          if (!hasDiscount) return const SizedBox.shrink();
                          final pct = sale.items.firstWhere((i) => i.discountPercent > 0).discountPercent;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red[300]!),
                              ),
                              child: Text(
                                'Remise -${pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Liste des articles
                    Text(
                      'Articles',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text('Produit',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                ),
                                Expanded(
                                  child: Text('Qté', textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('Total', textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                ),
                              ],
                            ),
                          ),
                          // Items
                          ...sale.items.map((item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(item.medicineName,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Expanded(
                                  child: Text('x${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text('${item.totalPrice.toStringAsFixed(0)} FBu',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Footer ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                children: [
                  // ── Statut sauvegarde PDF ──
                  _buildSaveStatus(),
                  const SizedBox(height: 10),

                  // ── Compte à rebours ──
                  Text(
                    'Fermeture automatique dans $_countdown sec...',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 10),

                  // ── Boutons d'action ──
                  Row(
                    children: [
                      // Fermer
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: const Text('Fermer'),
                      ),
                      const SizedBox(width: 8),

                      // Aperçu PDF (ouvre dans le visualiseur système)
                      if (widget.invoiceResult.savedPath != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _timer?.cancel();
                              InvoiceAutoService.reopenSaved(
                                widget.invoiceResult.savedPath!,
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFE53935)),
                            label: const Text(
                              'Voir PDF',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE53935),
                              side: const BorderSide(color: Color(0xFFE53935)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        )
                      else
                        // Si pas de chemin (erreur sauvegarde), proposer aperçu depuis bytes
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.invoiceResult.pdfBytes != null
                                ? () {
                                    _timer?.cancel();
                                    InvoicePdfService.printInvoice(
                                      sale: widget.sale,
                                      settings: widget.settings,
                                      sellerName: widget.sellerName,
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('Voir PDF', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      const SizedBox(width: 8),

                      // Imprimer
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _timer?.cancel();
                            Navigator.of(context).pop();
                            InvoiceAutoService.printInvoice(
                              sale: widget.sale,
                              settings: widget.settings,
                              sellerName: widget.sellerName,
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Imprimer', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  /// Affiche le statut de sauvegarde automatique du PDF
  Widget _buildSaveStatus() {
    final result = widget.invoiceResult;

    if (result.savedPath != null) {
      // Succès : afficher le chemin de sauvegarde
      final shortPath = result.savedPath!.length > 55
          ? '...${result.savedPath!.substring(result.savedPath!.length - 55)}'
          : result.savedPath!;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF81C784)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PDF sauvegardé automatiquement',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  Text(
                    shortPath,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF4CAF50)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (result.error != null) {
      // Erreur génération PDF
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFB74D)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, size: 14, color: Color(0xFFF57C00)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'PDF non sauvegardé automatiquement (générez-le manuellement)',
                style: TextStyle(fontSize: 10, color: Color(0xFFF57C00)),
              ),
            ),
          ],
        ),
      );
    } else {
      // pdfBytes ok mais pas de chemin (Web ou autre plateforme)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF90CAF9)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Color(0xFF1565C0)),
            SizedBox(width: 6),
            Text(
              'Facture prête — cliquez sur "Voir PDF" ou "Imprimer"',
              style: TextStyle(fontSize: 10, color: Color(0xFF1565C0)),
            ),
          ],
        ),
      );
    }
  }
}
