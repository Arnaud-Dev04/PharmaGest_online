import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';

/// Widget affichant la section conditionnement avec calculs temps réel
class ConditioningSection extends StatelessWidget {
  final TextEditingController nbCartonsController;
  final TextEditingController boitesParCartonController;
  final TextEditingController plaquettesParBoiteController;
  final TextEditingController comprimesParPlaquetteController;
  final int totalBoites;
  final int totalPlaquettes;
  final int totalComprimes;

  const ConditioningSection({
    super.key,
    required this.nbCartonsController,
    required this.boitesParCartonController,
    required this.plaquettesParBoiteController,
    required this.comprimesParPlaquetteController,
    required this.totalBoites,
    required this.totalPlaquettes,
    required this.totalComprimes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.inventory_2, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Conditionnement',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4 input fields in 2 rows
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: nbCartonsController,
                decoration: const InputDecoration(
                  labelText: 'Nb cartons reçus *',
                  hintText: 'Ex: 10',
                  prefixIcon: Icon(Icons.widgets, size: 18),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '> 0';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: boitesParCartonController,
                decoration: const InputDecoration(
                  labelText: 'Boîtes / carton *',
                  hintText: 'Ex: 20',
                  prefixIcon: Icon(Icons.inbox, size: 18),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '> 0';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: plaquettesParBoiteController,
                decoration: const InputDecoration(
                  labelText: 'Plaquettes / boîte *',
                  hintText: 'Ex: 3',
                  prefixIcon: Icon(Icons.view_column, size: 18),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '> 0';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: comprimesParPlaquetteController,
                decoration: const InputDecoration(
                  labelText: 'Comprimés / plaquette *',
                  hintText: 'Ex: 8',
                  prefixIcon: Icon(Icons.medication, size: 18),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '> 0';
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Totals display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTotalBadge(
                context,
                'Total boîtes',
                totalBoites.toString(),
                Icons.inbox,
                isDark,
              ),
              _buildTotalBadge(
                context,
                'Total plaquettes',
                totalPlaquettes.toString(),
                Icons.view_column,
                isDark,
              ),
              _buildTotalBadge(
                context,
                'Total comprimés',
                totalComprimes.toString(),
                Icons.medication,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalBadge(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppTheme.darkSidebarText
                    : AppTheme.lightSidebarText,
              ),
        ),
      ],
    );
  }
}
