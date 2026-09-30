import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/services/stock_service.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/error_helper.dart';

/// Dialog de formulaire pour ajouter/modifier un médicament
/// Reproduit exactement MedicineModal.jsx avec 15 champs
class MedicineFormDialog extends StatefulWidget {
  final Medicine? medicine; // null = ajout, non-null = édition

  const MedicineFormDialog({super.key, this.medicine});

  @override
  State<MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final StockService _stockService = StockService();

  // Controllers pour tous les champs
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cartonTypeController;
  late final TextEditingController _boxesPerCartonController;
  late final TextEditingController _dosageFormController;
  late final TextEditingController _packagingController;
  late final TextEditingController _blistersPerBoxController;
  late final TextEditingController _unitsPerBlisterController;
  late final TextEditingController _priceBuyController;
  late final TextEditingController _priceSellController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minStockAlertController;
  late final TextEditingController _expiryAlertThresholdController;
  late final TextEditingController _expiryDateController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Initialiser les controllers
    final medicine = widget.medicine;

    _nameController = TextEditingController(text: medicine?.name ?? '');
    _descriptionController = TextEditingController(
      text: medicine?.description ?? '',
    );
    _cartonTypeController = TextEditingController(
      text: medicine?.cartonType ?? 'Carton',
    );
    _boxesPerCartonController = TextEditingController(
      text: medicine?.boxesPerCarton.toString() ?? '1',
    );
    _dosageFormController = TextEditingController(
      text: medicine?.dosageForm ?? '',
    );
    _packagingController = TextEditingController(
      text: medicine?.packaging ?? '',
    );
    _blistersPerBoxController = TextEditingController(
      text: medicine?.blistersPerBox.toString() ?? '1',
    );
    _unitsPerBlisterController = TextEditingController(
      text: medicine?.unitsPerBlister.toString() ?? '1',
    );
    _priceBuyController = TextEditingController(
      text: medicine?.priceBuy.toStringAsFixed(2) ?? '',
    );
    _priceSellController = TextEditingController(
      text: medicine?.priceSell.toStringAsFixed(2) ?? '',
    );

    // Quantité : afficher en CARTONS (convertir depuis unités)
    if (medicine != null) {
      final totalUnitsPerCarton =
          (medicine.boxesPerCarton *
          medicine.blistersPerBox *
          medicine.unitsPerBlister);
      final displayQuantity = totalUnitsPerCarton > 0
          ? (medicine.quantity / totalUnitsPerCarton).floor()
          : medicine.quantity;
      _quantityController = TextEditingController(
        text: displayQuantity.toString(),
      );
    } else {
      _quantityController = TextEditingController(text: '');
    }

    _minStockAlertController = TextEditingController(
      text: medicine?.minStockAlert.toString() ?? '10',
    );
    _expiryAlertThresholdController = TextEditingController(
      text: medicine?.expiryAlertThreshold.toString() ?? '30',
    );
    _expiryDateController = TextEditingController(
      text: medicine?.expiryDate != null
          ? DateFormat('yyyy-MM-dd').format(medicine!.expiryDate!)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cartonTypeController.dispose();
    _boxesPerCartonController.dispose();
    _dosageFormController.dispose();
    _packagingController.dispose();
    _blistersPerBoxController.dispose();
    _unitsPerBlisterController.dispose();
    _priceBuyController.dispose();
    _priceSellController.dispose();
    _quantityController.dispose();
    _minStockAlertController.dispose();
    _expiryAlertThresholdController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Calculer la quantité totale en UNITÉS
      final boxesPerCarton = int.tryParse(_boxesPerCartonController.text) ?? 1;
      final blistersPerBox = int.tryParse(_blistersPerBoxController.text) ?? 1;
      final unitsPerBlister =
          int.tryParse(_unitsPerBlisterController.text) ?? 1;
      final quantityInCartons = int.tryParse(_quantityController.text) ?? 0;

      final totalQuantity =
          quantityInCartons * boxesPerCarton * blistersPerBox * unitsPerBlister;

      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'carton_type': _cartonTypeController.text.trim().isNotEmpty
            ? _cartonTypeController.text.trim()
            : 'Carton',
        'boxes_per_carton': boxesPerCarton,
        'dosage_form': _dosageFormController.text.trim().isNotEmpty
            ? _dosageFormController.text.trim()
            : null,
        'packaging': _packagingController.text.trim().isNotEmpty
            ? _packagingController.text.trim()
            : null,
        'blisters_per_box': blistersPerBox,
        'units_per_blister': unitsPerBlister,
        'price_buy': double.parse(_priceBuyController.text),
        'price_sell': double.parse(_priceSellController.text),
        'quantity': totalQuantity,
        'min_stock_alert': int.parse(_minStockAlertController.text),
        'expiry_alert_threshold': int.parse(
          _expiryAlertThresholdController.text,
        ),
        'expiry_date': _expiryDateController.text.trim().isNotEmpty
            ? _expiryDateController.text.trim()
            : null,
      };

      if (widget.medicine != null) {
        await _stockService.updateMedicine(widget.medicine!.id, data);
      } else {
        await _stockService.createMedicine(data);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true pour indiquer le succès
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(isDark),

            // Body (scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameField(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 16),
                      _buildCartonFields(),
                      const SizedBox(height: 16),
                      _buildPackagingFields(),
                      const SizedBox(height: 16),
                      _buildPriceFields(),
                      const SizedBox(height: 16),
                      _buildQuantityFields(),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Dates'),
                      _buildExpiryDateField(),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.medicine != null
                  ? 'Modifier le médicament'
                  : 'Ajouter un médicament',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Nom *',
        hintText: 'Paracétamol 500mg',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nom requis';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Description du médicament...',
      ),
      maxLines: 3,
    );
  }

  Widget _buildCartonFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _cartonTypeController,
            decoration: const InputDecoration(
              labelText: 'Nom du Carton',
              hintText: 'Carton',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _boxesPerCartonController,
            decoration: const InputDecoration(
              labelText: 'Boîtes par Carton',
              hintText: 'Ex: 50',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildPackagingFields() {
    return Column(
      children: [
        // Row 1  : Forme + Conditionnement
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _dosageFormController,
                decoration: const InputDecoration(
                  labelText: 'Forme',
                  hintText: 'Ex: Comprimé',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _packagingController,
                decoration: const InputDecoration(
                  labelText: 'Conditionnement',
                  hintText: 'Ex: Boîte',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Row 2 : Plaquettes + Unités
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _blistersPerBoxController,
                decoration: const InputDecoration(
                  labelText: 'Contenu Boîte (Plaq.)',
                  hintText: 'Ex: 10',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _unitsPerBlisterController,
                decoration: const InputDecoration(
                  labelText: 'Contenu Plaq. (Unités)',
                  hintText: 'Ex: 6',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _priceBuyController,
            decoration: const InputDecoration(
              labelText: 'Prix d\'achat (Boîte) *',
              hintText: '0.00',
              prefixText: 'F',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Prix requis';
              }
              if (double.tryParse(value) == null) {
                return 'Nombre invalide';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _priceSellController,
            decoration: const InputDecoration(
              labelText: 'Prix de vente (Boîte) *',
              hintText: '0.00',
              prefixText: 'F',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Prix requis';
              }
              if (double.tryParse(value) == null) {
                return 'Nombre invalide';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Qté Initiale (Cartons) *',
                  hintText: 'Ex: 5',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Quantité requise';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Nombre invalide';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _minStockAlertController,
                decoration: const InputDecoration(
                  labelText: 'Seuil d\'alerte (Unités)',
                  hintText: '10',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Saisir le nombre de CARTONS (ou Boîtes si pas de carton). Le total sera converti.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.lightBlueAccent : AppTheme.primaryColor,
            ),
      ),
    );
  }

  Widget _buildExpiryDateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[850] : Colors.blue.shade50;
    final borderColor = isDark
        ? Colors.blueGrey.withOpacity(0.35)
        : AppTheme.primaryColor.withOpacity(0.35);

    final initialDate = _expiryDateController.text.isNotEmpty
        ? DateFormat('yyyy-MM-dd').parse(_expiryDateController.text)
        : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dates',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _expiryDateController,
                  decoration: InputDecoration(
                    labelText: 'Date d\'expiration',
                    hintText: 'yyyy-MM-dd',
                    suffixIcon: const Icon(Icons.calendar_today),
                    filled: true,
                    fillColor: isDark ? Colors.grey[900] : Colors.white,
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 3650),
                      ), // 10 ans
                    );
                    if (date != null) {
                      _expiryDateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(date);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _expiryAlertThresholdController,
                  decoration: InputDecoration(
                    labelText: 'Alerte Expiration (Jours)',
                    hintText: '30',
                    filled: true,
                    fillColor: isDark ? Colors.grey[900] : Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cette date sera utilisée pour suivre les expirations et générer des alertes.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.medicine != null ? 'Mettre à jour' : 'Créer'),
          ),
        ],
      ),
    );
  }
}
