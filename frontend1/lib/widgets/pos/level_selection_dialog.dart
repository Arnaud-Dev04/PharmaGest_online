import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/pos_product.dart';
import 'package:intl/intl.dart';

/// Dialog de sélection du niveau de conditionnement et quantité pour le POS.
class LevelSelectionDialog extends StatefulWidget {
  final PosProduct product;
  const LevelSelectionDialog({super.key, required this.product});

  @override
  State<LevelSelectionDialog> createState() => _LevelSelectionDialogState();
}

class _LevelSelectionDialogState extends State<LevelSelectionDialog> {
  String _level = 'unite';
  int _quantity = 1;
  final _fmt = NumberFormat('#,###', 'fr_FR');

  double get _unitPrice => widget.product.priceAtLevel(_level);
  double get _total => _unitPrice * _quantity;
  int get _baseUnits => widget.product.toBaseUnits(_quantity, _level);

  String _fmtFBu(double v) => '${_fmt.format(v.round())} FBu';

  String _levelLabel(String level) {
    switch (level) {
      case 'carton': return '🏢 Carton';
      case 'boite': return '📦 Boîte';
      case 'plaquette': return '💊 Plaquette';
      default: return '💎 Unité';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.shopping_cart, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.product.name, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          if (widget.product.dci != null || widget.product.dosageForm != null || widget.product.formeGalenique != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(
                [widget.product.formeGalenique, widget.product.dci, widget.product.dosageForm]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Level selector
          const Align(alignment: Alignment.centerLeft,
            child: Text('Niveau de conditionnement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: ['unite', 'plaquette', 'boite', 'carton'].map((l) {
            final selected = _level == l;
            final price = widget.product.priceAtLevel(l);
            return ChoiceChip(
              label: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_levelLabel(l), style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                Text(_fmtFBu(price), style: TextStyle(fontSize: 10, color: selected ? Colors.white : Colors.grey[600])),
              ]),
              selected: selected,
              selectedColor: Colors.teal,
              onSelected: (_) => setState(() => _level = l),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            );
          }).toList()),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Quantity selector
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.teal,
            ),
            Container(
              width: 60, alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: () => setState(() => _quantity++),
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.teal,
            ),
          ]),

          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              _summaryRow('Prix unitaire', _fmtFBu(_unitPrice)),
              _summaryRow('Quantité', '$_quantity × ${_levelLabel(_level)}'),
              const Divider(height: 16),
              _summaryRow('Sous-total', _fmtFBu(_total), bold: true, color: Colors.teal),
              const SizedBox(height: 4),
              Text('= $_baseUnits comprimés déduits du stock',
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop({
            'level': _level,
            'quantity': _quantity,
            'unit_price': _unitPrice,
            'total_price': _total,
            'base_units': _baseUnits,
          }),
          icon: const Icon(Icons.add_shopping_cart, size: 18),
          label: const Text('Ajouter au panier'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
      ]),
    );
  }
}
