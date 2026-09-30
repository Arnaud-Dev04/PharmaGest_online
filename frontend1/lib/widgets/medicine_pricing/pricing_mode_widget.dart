import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:intl/intl.dart';

/// Widget de sélection du mode de prix et champs dynamiques
class PricingModeWidget extends StatelessWidget {
  final PricingMode selectedMode;
  final ValueChanged<PricingMode> onModeChanged;

  // Niveau de référence pour le mode Manuel
  final String referenceLevel;
  final ValueChanged<String> onReferenceLevelChanged;

  // Mode 1 fields
  final TextEditingController achatCartonController;
  final TextEditingController margePctController;

  // Mode 2 fields (also used by mode 1 & 3 for display)
  final TextEditingController venteCartonController;
  final TextEditingController venteBoiteController;
  final TextEditingController ventePlaquetteController;
  final TextEditingController venteComprimeController;

  // Calculated values for display
  final double gainNetComprime;
  final double margeCalculee;
  final double margeAbsolue;

  // Whether fields are read-only (auto-calculated)
  final bool venteFieldsReadOnly;

  // PA controllers for manual mode
  final TextEditingController achatBoiteController;
  final TextEditingController achatPlaquetteController;
  final TextEditingController achatComprimeController;

  PricingModeWidget({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    required this.referenceLevel,
    required this.onReferenceLevelChanged,
    required this.achatCartonController,
    required this.margePctController,
    required this.venteCartonController,
    required this.venteBoiteController,
    required this.ventePlaquetteController,
    required this.venteComprimeController,
    required this.gainNetComprime,
    required this.margeCalculee,
    required this.margeAbsolue,
    required this.venteFieldsReadOnly,
    required this.achatBoiteController,
    required this.achatPlaquetteController,
    required this.achatComprimeController,
  });

  String _fmtBIF(double v) {
    final f = NumberFormat('#,###.##', 'fr_FR');
    return '${f.format(v)} FBu';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.price_change, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Mode de fixation des prix',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Mode selector (SegmentedButton)
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<PricingMode>(
            segments: PricingMode.values.map((mode) {
              return ButtonSegment<PricingMode>(
                value: mode,
                label: Text(
                  mode.label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                icon: Icon(
                  mode == PricingMode.pctMarge
                      ? Icons.percent
                      : mode == PricingMode.manuel
                          ? Icons.edit
                          : Icons.inventory,
                  size: 16,
                ),
              );
            }).toList(),
            selected: {selectedMode},
            onSelectionChanged: (Set<PricingMode> newSelection) {
              onModeChanged(newSelection.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Prix d'achat carton (visible sauf en mode manuel avec ref != carton)
        if (selectedMode != PricingMode.manuel || referenceLevel == 'carton')
          TextFormField(
            controller: achatCartonController,
            decoration: const InputDecoration(
              labelText: 'Prix d\'achat du carton (FBu) *',
              hintText: 'Ex: 120000',
              prefixIcon: Icon(Icons.shopping_cart, size: 18),
              suffixText: 'FBu',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (selectedMode != PricingMode.manuel || referenceLevel == 'carton') {
                if (v == null || v.isEmpty) return 'Requis';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Doit être > 0';
              }
              return null;
            },
          ),
        if (selectedMode != PricingMode.manuel || referenceLevel == 'carton')
          const SizedBox(height: 16),

        // Mode-specific fields
        _buildModeFields(context, isDark),
      ],
    );
  }

  Widget _buildModeFields(BuildContext context, bool isDark) {
    switch (selectedMode) {
      case PricingMode.pctMarge:
        return _buildModePctMarge(context, isDark);
      case PricingMode.manuel:
        return _buildModeManuel(context, isDark);
      case PricingMode.cartonFixe:
        return _buildModeCartonFixe(context, isDark);
    }
  }

  Widget _buildModePctMarge(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marge % input
        TextFormField(
          controller: margePctController,
          decoration: const InputDecoration(
            labelText: 'Pourcentage de marge (%) *',
            hintText: 'Ex: 25',
            prefixIcon: Icon(Icons.percent, size: 18),
            suffixText: '%',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requis';
            final n = double.tryParse(v);
            if (n == null || n <= 0) return 'Doit être > 0';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Auto-calculated prices (read-only display)
        _buildCalculatedPricesCard(context, isDark),

        // Gain net par comprimé
        const SizedBox(height: 12),
        _buildInfoBadge(
          context,
          'Gain net par comprimé',
          _fmtBIF(gainNetComprime),
          Icons.trending_up,
          AppTheme.successColor,
          isDark,
        ),
      ],
    );
  }

  Widget _buildModeManuel(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_fix_high, size: 14, color: Colors.teal),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Choisissez le niveau de référence, saisissez PA et PV, les autres prix seront calculés automatiquement.',
                  style: TextStyle(fontSize: 11, color: Colors.teal),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Dropdown pour choisir le niveau de référence
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
          ),
          child: Row(
            children: [
              Icon(Icons.tune, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Niveau de référence :',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: referenceLevel,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'carton', child: Text('🏢 Carton')),
                      DropdownMenuItem(value: 'boite', child: Text('📦 Boîte')),
                      DropdownMenuItem(value: 'plaquette', child: Text('💊 Plaquette')),
                      DropdownMenuItem(value: 'unite', child: Text('💎 Unité')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        onReferenceLevelChanged(v);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Champs PA et PV du niveau sélectionné
        _buildReferenceLevelInputs(context),
        const SizedBox(height: 16),

        // Affichage des prix calculés pour les AUTRES niveaux
        _buildAutoCalculatedLevels(context, isDark),
      ],
    );
  }

  /// Construit les champs PA/PV pour le niveau de référence sélectionné
  Widget _buildReferenceLevelInputs(BuildContext context) {
    String label;
    String emoji;
    TextEditingController paCtrl;
    TextEditingController pvCtrl;

    switch (referenceLevel) {
      case 'carton':
        label = 'Carton';
        emoji = '🏢';
        paCtrl = achatCartonController;
        pvCtrl = venteCartonController;
        break;
      case 'boite':
        label = 'Boîte';
        emoji = '📦';
        paCtrl = achatBoiteController;
        pvCtrl = venteBoiteController;
        break;
      case 'plaquette':
        label = 'Plaquette';
        emoji = '💊';
        paCtrl = achatPlaquetteController;
        pvCtrl = ventePlaquetteController;
        break;
      case 'unite':
      default:
        label = 'Unité';
        emoji = '💎';
        paCtrl = achatComprimeController;
        pvCtrl = venteComprimeController;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$emoji  ', style: const TextStyle(fontSize: 16)),
              Text(
                'Prix pour 1 $label',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: paCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prix d\'Achat (PA)',
                    suffixText: 'FBu',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    prefixIcon: Icon(Icons.shopping_cart_outlined, size: 16),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: pvCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prix de Vente (PV)',
                    suffixText: 'FBu',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    prefixIcon: Icon(Icons.sell_outlined, size: 16),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (double.tryParse(v) == null) return 'Invalide';
                    return null;
                  },
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Affiche les niveaux calculés automatiquement (hors niveau de référence)
  Widget _buildAutoCalculatedLevels(BuildContext context, bool isDark) {
    final levels = [
      {'key': 'carton', 'label': 'Carton', 'emoji': '🏢',
       'pa': achatCartonController, 'pv': venteCartonController},
      {'key': 'boite', 'label': 'Boîte', 'emoji': '📦',
       'pa': achatBoiteController, 'pv': venteBoiteController},
      {'key': 'plaquette', 'label': 'Plaquette', 'emoji': '💊',
       'pa': achatPlaquetteController, 'pv': ventePlaquetteController},
      {'key': 'unite', 'label': 'Unité', 'emoji': '💎',
       'pa': achatComprimeController, 'pv': venteComprimeController},
    ];

    final otherLevels = levels.where((l) => l['key'] != referenceLevel).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkInput.withValues(alpha: 0.5)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prix calculés automatiquement',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppTheme.darkSidebarText
                      : AppTheme.lightSidebarText,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 8),
          ...otherLevels.map((level) {
            final paCtrl = level['pa'] as TextEditingController;
            final pvCtrl = level['pv'] as TextEditingController;
            final pa = double.tryParse(paCtrl.text) ?? 0;
            final pv = double.tryParse(pvCtrl.text) ?? 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      '${level['emoji']} ${level['label']}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'PA: ${_fmtBIF(pa)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'PV: ${_fmtBIF(pv)}',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModeCartonFixe(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prix vente carton (editable)
        TextFormField(
          controller: venteCartonController,
          decoration: const InputDecoration(
            labelText: 'Prix de vente du carton (BIF) *',
            hintText: 'Ex: 150000',
            prefixIcon: Icon(Icons.inventory, size: 18),
            suffixText: 'FBu',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requis';
            final n = double.tryParse(v);
            if (n == null || n <= 0) return 'Doit être > 0';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Auto-calculated prices
        _buildCalculatedPricesCard(context, isDark),

        // Marge auto-calculée
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoBadge(
                context,
                'Marge calculée',
                '${margeCalculee.toStringAsFixed(1)}%',
                Icons.percent,
                margeCalculee >= 0
                    ? AppTheme.successColor
                    : AppTheme.dangerColor,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoBadge(
                context,
                'Marge absolue',
                _fmtBIF(margeAbsolue),
                Icons.attach_money,
                margeAbsolue >= 0
                    ? AppTheme.successColor
                    : AppTheme.dangerColor,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalculatedPricesCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkInput.withValues(alpha: 0.5)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prix de vente calculés automatiquement',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppTheme.darkSidebarText
                      : AppTheme.lightSidebarText,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(context, '🏢 Carton',
              _fmtBIF(double.tryParse(venteCartonController.text) ?? 0)),
          _buildPriceRow(context, '📦 Boîte',
              _fmtBIF(double.tryParse(venteBoiteController.text) ?? 0)),
          _buildPriceRow(context, '💊 Plaquette',
              _fmtBIF(double.tryParse(ventePlaquetteController.text) ?? 0)),
          _buildPriceRow(context, '💎 Comprimé',
              _fmtBIF(double.tryParse(venteComprimeController.text) ?? 0)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppTheme.darkSidebarText
                            : AppTheme.lightSidebarText,
                        fontSize: 11,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
