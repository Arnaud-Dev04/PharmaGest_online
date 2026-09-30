import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/dashboard_stats.dart';

class SalesByDayChart extends StatelessWidget {
  final List<SalesByDay> data;

  const SalesByDayChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find max for Y axis
    double maxY = 0;
    for (var d in data) {
      if (d.amount > maxY) maxY = d.amount;
    }
    if (maxY == 0) maxY = 100;

    return AspectRatio(
      aspectRatio: 1.7,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final dayName = data[value.toInt()].day;
                  // Map English/Full names to French short names if needed, or just use first 3 chars
                  // Assuming backend returns English names "Monday", etc.
                  // We should translate or map them.
                  // Simple map for now:
                  final shortName = _getShortDayName(dayName);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      shortName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.amount,
                  color: AppTheme.primaryColor,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY * 1.2,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                ),
              ],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: isDark ? AppTheme.darkCard : Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${_translateDay(data[groupIndex].day)}\n',
                  TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toInt()} FBu',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _getShortDayName(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Lun';
      case 'tuesday':
        return 'Mar';
      case 'wednesday':
        return 'Mer';
      case 'thursday':
        return 'Jeu';
      case 'friday':
        return 'Ven';
      case 'saturday':
        return 'Sam';
      case 'sunday':
        return 'Dim';
      default:
        return day.substring(0, 3);
    }
  }

  String _translateDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Lundi';
      case 'tuesday':
        return 'Mardi';
      case 'wednesday':
        return 'Mercredi';
      case 'thursday':
        return 'Jeudi';
      case 'friday':
        return 'Vendredi';
      case 'saturday':
        return 'Samedi';
      case 'sunday':
        return 'Dimanche';
      default:
        return day;
    }
  }
}

class SalesByHourChart extends StatelessWidget {
  final List<SalesByHour> data;

  const SalesByHourChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find max for Y axis
    double maxY = 0;
    for (var d in data) {
      if (d.amount > maxY) maxY = d.amount;
    }
    if (maxY == 0) maxY = 100;

    return AspectRatio(
      aspectRatio: 1.7,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDark ? Colors.white10 : Colors.black12,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4, // Show every 4 hours
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${value.toInt()}h',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 23,
          maxY: maxY * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: data
                  .map((e) => FlSpot(e.hour.toDouble(), e.amount))
                  .toList(),
              isCurved: true,
              curveSmoothness: 0.35,
              color: Colors.orange,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withValues(alpha: 0.2),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: isDark ? AppTheme.darkCard : Colors.white,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.x.toInt()}h\n',
                    TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: '${spot.y.toInt()} FBu',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
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
    );
  }
}
