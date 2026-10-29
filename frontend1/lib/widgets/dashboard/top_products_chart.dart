import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/dashboard_stats.dart';

/// Diagramme Donut interactif des produits les plus vendus
class TopProductsPieChart extends StatefulWidget {
  final List<TopProduct> topProducts;

  const TopProductsPieChart({super.key, required this.topProducts});

  @override
  State<TopProductsPieChart> createState() => _TopProductsPieChartState();
}

class _TopProductsPieChartState extends State<TopProductsPieChart> {
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    AppTheme.primaryColor,
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF64748B), // Slate / Autres
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.topProducts.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'Aucune vente enregistrée sur cette période',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      );
    }

    final topItems = widget.topProducts.take(5).toList();
    final totalSold = widget.topProducts.fold<int>(0, (sum, p) => sum + p.totalSold);

    if (totalSold <= 0) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: Text(
          'Aucun article vendu',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
        ),
      );
    }

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
                  sectionsSpace: 2,
                  centerSpaceRadius: 46,
                  sections: List.generate(topItems.length, (i) {
                    final isTouched = i == _touchedIndex;
                    final radius = isTouched ? 42.0 : 34.0;
                    final item = topItems[i];
                    final pct = (item.totalSold / totalSold) * 100;
                    final color = _palette[i % _palette.length];

                    return PieChartSectionData(
                      color: color,
                      value: item.totalSold.toDouble(),
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
                    '$totalSold',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    'unités',
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
          children: List.generate(topItems.length, (i) {
            final item = topItems[i];
            final color = _palette[i % _palette.length];
            final isSelected = i == _touchedIndex;
            final pct = (item.totalSold / totalSold) * 100;

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
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
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
                        item.name,
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
                      '${item.totalSold} (${pct.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
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

