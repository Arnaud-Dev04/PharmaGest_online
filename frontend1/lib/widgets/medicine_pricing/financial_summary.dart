import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:intl/intl.dart';

/// Widget affichant le résumé financier avec couleurs conditionnelles
class FinancialSummary extends StatelessWidget {
  final double valeurAchatTotale;
  final double valeurVenteTotale;
  final double beneficeEstime;

  const FinancialSummary({
    super.key,
    required this.valeurAchatTotale,
    required this.valeurVenteTotale,
    required this.beneficeEstime,
  });

  String _formatBIF(double value) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return '${formatter.format(value.round())} BIF';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isProfit = beneficeEstime >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(Icons.analytics, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Résumé Financier',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isProfit
                  ? AppTheme.successColor.withValues(alpha: 0.3)
                  : AppTheme.dangerColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isProfit ? AppTheme.successColor : AppTheme.dangerColor)
                    .withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Valeur d'achat
              _buildRow(
                context,
                icon: Icons.shopping_cart,
                label: 'Valeur d\'achat totale',
                value: _formatBIF(valeurAchatTotale),
                color: isDark
                    ? AppTheme.darkSidebarText
                    : AppTheme.lightSidebarText,
                isDark: isDark,
              ),
              Divider(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                height: 20,
              ),

              // Valeur de vente
              _buildRow(
                context,
                icon: Icons.sell,
                label: 'Valeur de vente totale',
                value: _formatBIF(valeurVenteTotale),
                color: AppTheme.primaryColor,
                isDark: isDark,
              ),
              Divider(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                height: 20,
              ),

              // Bénéfice
              _buildRow(
                context,
                icon: isProfit
                    ? Icons.trending_up
                    : Icons.trending_down,
                label: 'Bénéfice estimé',
                value: _formatBIF(beneficeEstime),
                color: isProfit ? AppTheme.successColor : AppTheme.dangerColor,
                isDark: isDark,
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.darkSidebarText
                        : AppTheme.lightSidebarText,
                  ),
            ),
          ],
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
                fontSize: isBold ? 16 : 14,
              ),
        ),
      ],
    );
  }
}
