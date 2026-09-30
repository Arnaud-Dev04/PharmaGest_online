import 'package:flutter/material.dart';

/// Widget représentant une carte de statistique (KPI Card)
/// Design identique au StatsCard React
class StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconBgColor;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconBgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: onTap != null ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Section gauche : Label + Value
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Value (grande)
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[900],
                          ),
                    ),
                  ],
                ),
              ),

              // Section droite : Icône dans container coloré
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
