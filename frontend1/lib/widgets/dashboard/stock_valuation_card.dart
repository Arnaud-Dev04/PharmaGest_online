import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/services/prix_calculator.dart';

/// Carte analytique pour Administrateurs : Valeur marchande du stock & rentabilité
class StockValuationCard extends StatelessWidget {
  final double purchaseValue;
  final double sellValue;
  final double totalRevenue;

  const StockValuationCard({
    super.key,
    required this.purchaseValue,
    required this.sellValue,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final potentialProfit = (sellValue - purchaseValue).clamp(0.0, double.infinity).toDouble();
    final marginRate = purchaseValue > 0 ? (potentialProfit / purchaseValue) * 100 : 0.0;
    final totalVal = sellValue > 0 ? sellValue : 1.0;
    final costRatio = (purchaseValue / totalVal).clamp(0.0, 1.0);
    final profitRatio = (potentialProfit / totalVal).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breakdown en 3 colonnes
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Capital immobilisé (Achat)',
                amount: PrixCalculator.fmtFBu(purchaseValue),
                color: const Color(0xFF3B82F6), // Blue
                icon: Icons.account_balance_wallet_outlined,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Valeur marchande (Vente)',
                amount: PrixCalculator.fmtFBu(sellValue),
                color: AppTheme.primaryColor, // Teal
                icon: Icons.storefront_outlined,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Marge brute estimée',
                amount: '+${PrixCalculator.fmtFBu(potentialProfit)}',
                badgeText: '+${marginRate.toStringAsFixed(1)}%',
                color: AppTheme.successColor, // Green
                icon: Icons.trending_up,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Jauge visuelle de rentabilité
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Répartition de la valeur stock',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              'Marge moyenne : ${marginRate.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Segmented bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (costRatio * 100).toInt().clamp(1, 100),
                  child: Container(color: const Color(0xFF3B82F6)),
                ),
                Expanded(
                  flex: (profitRatio * 100).toInt().clamp(1, 100),
                  child: Container(color: AppTheme.successColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Légende de la jauge
        Row(
          children: [
            _buildLegendItem('Coût d\'achat (${(costRatio * 100).toStringAsFixed(0)}%)', const Color(0xFF3B82F6)),
            const SizedBox(width: 16),
            _buildLegendItem('Bénéfice potentiel (${(profitRatio * 100).toStringAsFixed(0)}%)', AppTheme.successColor),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String amount,
    String? badgeText,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

