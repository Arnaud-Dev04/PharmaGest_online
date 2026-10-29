import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';

/// Diagramme Donut de santé globale de l'inventaire
class StockHealthChart extends StatefulWidget {
  final int totalMedicines;
  final int lowStockCount;
  final int expiringSoonCount;
  final int expiredCount;

  const StockHealthChart({
    super.key,
    required this.totalMedicines,
    required this.lowStockCount,
    required this.expiringSoonCount,
    required this.expiredCount,
  });

  @override
  State<StockHealthChart> createState() => _StockHealthChartState();
}

class _StockHealthChartState extends State<StockHealthChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = widget.totalMedicines;
    if (total <= 0) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'Aucun médicament en stock',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      );
    }

    final lowStock = widget.lowStockCount;
    final expired = widget.expiredCount;
    final expiringSoon = widget.expiringSoonCount;
    final normalStock = max(0, total - lowStock - expired);

    final categories = [
      {
        'label': 'Stock optimal',
        'count': normalStock,
        'color': AppTheme.successColor,
        'icon': Icons.check_circle_outline,
      },
      {
        'label': 'Stock faible (alerte)',
        'count': lowStock,
        'color': const Color(0xFFF59E0B),
        'icon': Icons.warning_amber_rounded,
      },
      {
        'label': 'Expire bientôt (<90j)',
        'count': expiringSoon,
        'color': const Color(0xFFEA580C),
        'icon': Icons.schedule,
      },
      {
        'label': 'Périmé (retrait)',
        'count': expired,
        'color': AppTheme.dangerColor,
        'icon': Icons.cancel_outlined,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 450;

        final chartWidget = SizedBox(
          height: 190,
          width: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections: List.generate(categories.length, (i) {
                    final cat = categories[i];
                    final count = cat['count'] as int;
                    if (count <= 0) {
                      return PieChartSectionData(
                        color: Colors.transparent,
                        value: 0,
                        showTitle: false,
                        radius: 0,
                      );
                    }
                    final isTouched = i == _touchedIndex;
                    final radius = isTouched ? 42.0 : 34.0;
                    final pct = (count / total) * 100;

                    return PieChartSectionData(
                      color: cat['color'] as Color,
                      value: count.toDouble(),
                      title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                      radius: radius,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    'références',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        final legendWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(categories.length, (i) {
            final cat = categories[i];
            final color = cat['color'] as Color;
            final count = cat['count'] as int;
            final isSelected = i == _touchedIndex;
            final pct = total > 0 ? (count / total) * 100 : 0.0;

            return InkWell(
              onTap: () {
                setState(() {
                  _touchedIndex = (_touchedIndex == i) ? -1 : i;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count (${pct.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: count > 0 && (i == 1 || i == 3) ? color : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );

        if (isNarrow) {
          return Column(
            children: [
              Center(child: chartWidget),
              const SizedBox(height: 16),
              legendWidget,
            ],
          );
        }

        return Row(
          children: [
            chartWidget,
            const SizedBox(width: 16),
            Expanded(child: legendWidget),
          ],
        );
      },
    );
  }
}

