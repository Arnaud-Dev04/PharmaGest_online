import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/dashboard_stats.dart';
import 'package:intl/intl.dart';

/// Widget graphique de revenus avec fl_chart
/// Reproduit exactement le AreaChart React (Recharts)
class RevenueChart extends StatelessWidget {
  final List<RevenueChartPoint> data;

  const RevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Text(
            'Pas de données disponibles pour la période sélectionnée',
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
        child: LineChart(
          LineChartData(
            // Grille
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _calculateInterval(data),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              },
            ),

            // Titres des axes
            titlesData: FlTitlesData(
              // Désactiver les titres en haut et à droite
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),

              // Axe Y (gauche) - Montants
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  interval: _calculateInterval(data),
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()} FBu',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkSidebarText
                            : const Color(0xFF6B7280),
                      ),
                    );
                  },
                ),
              ),

              // Axe X (bas) - Dates
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _calculateDateInterval(data.length),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }

                    final date = data[index].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('dd/MM').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkSidebarText
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bordures
            borderData: FlBorderData(show: false),

            // Min/Max
            minY: 0,
            maxY: _calculateMaxY(data),

            // Données de la ligne
            lineBarsData: [
              LineChartBarData(
                spots: data.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.amount);
                }).toList(),

                // Courbe lisse (monotone)
                isCurved: true,
                curveSmoothness: 0.3,

                // Couleur de la ligne (bleu)
                color: const Color(0xFF3B82F6),
                barWidth: 2,

                // Points sur la courbe
                dotData: const FlDotData(show: false),

                // Gradient sous la courbe (AreaChart effect)
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      const Color(0xFF3B82F6).withValues(alpha: 0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],

            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: isDark
                    ? AppTheme.darkCard
                    : Colors.white.withValues(alpha: 0.95),
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.all(8),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    if (index < 0 || index >= data.length) {
                      return null;
                    }

                    final point = data[index];
                    return LineTooltipItem(
                      '${DateFormat('dd/MM').format(point.date)}\n',
                      TextStyle(
                        color: isDark
                            ? AppTheme.darkSidebarText
                            : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${point.amount.toStringAsFixed(0)} FBu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkForeground
                                : AppTheme.lightForeground,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Calcule l'intervalle de la grille horizontale
  double _calculateInterval(List<RevenueChartPoint> data) {
    if (data.isEmpty) return 5000;

    final maxAmount = data.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    if (maxAmount < 1000) return 200;
    if (maxAmount < 5000) return 1000;
    if (maxAmount < 20000) return 5000;
    if (maxAmount < 50000) return 10000;
    return 20000;
  }

  /// Calcule le max Y pour le graphique
  double _calculateMaxY(List<RevenueChartPoint> data) {
    if (data.isEmpty) return 10000;

    final maxAmount = data.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
    final interval = _calculateInterval(data);

    // Arrondir au prochain intervalle
    return ((maxAmount / interval).ceil() * interval).toDouble();
  }

  /// Calcule l'intervalle pour afficher les dates (ne pas afficher toutes les dates)
  double _calculateDateInterval(int dataLength) {
    if (dataLength <= 7) return 1;
    if (dataLength <= 15) return 2;
    if (dataLength <= 30) return 3;
    return 7;
  }
}
