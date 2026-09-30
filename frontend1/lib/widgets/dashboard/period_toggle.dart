import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Widget toggle pour sélectionner la période (7/30/90 jours)
/// Design identique au toggle React avec 3 boutons
class PeriodToggle extends StatelessWidget {
  final int selectedPeriod;
  final ValueChanged<int> onPeriodChanged;

  const PeriodToggle({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(context, 7, languageProvider, isDark),
          _buildButton(context, 30, languageProvider, isDark),
          _buildButton(context, 90, languageProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    int days,
    LanguageProvider languageProvider,
    bool isDark,
  ) {
    final isSelected = selectedPeriod == days;

    return GestureDetector(
      onTap: () => onPeriodChanged(days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkSidebarHover : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$days ${languageProvider.translate('days')}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isSelected
                ? (isDark ? AppTheme.darkForeground : AppTheme.lightForeground)
                : (isDark
                      ? AppTheme.darkSidebarText
                      : AppTheme.lightSidebarText),
          ),
        ),
      ),
    );
  }
}
