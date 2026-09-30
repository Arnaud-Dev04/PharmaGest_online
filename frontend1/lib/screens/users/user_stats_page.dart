import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/user_stats.dart';
import 'package:frontend1/services/user_service.dart';
import 'package:frontend1/widgets/dashboard/stats_card.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/core/error_helper.dart';

class UserStatsPage extends StatefulWidget {
  final int userId;

  const UserStatsPage({super.key, required this.userId});

  @override
  State<UserStatsPage> createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  final UserService _userService = UserService();

  UserStats? _stats;
  bool _isLoading = true;
  String? _error;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({DateTimeRange? customRange}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fmt = DateFormat('yyyy-MM-dd');
      String startDateStr;
      String endDateStr;

      if (customRange != null) {
        startDateStr = fmt.format(customRange.start);
        endDateStr = fmt.format(customRange.end);
      } else {
        final now = DateTime.now();
        final start = now.subtract(Duration(days: _days));
        startDateStr = fmt.format(start);
        endDateStr = fmt.format(now);
      }

      final stats = await _userService.getUserStats(
        widget.userId,
        startDateStr,
        endDateStr,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHelper.extractErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  void _updateDays(int days) {
    if (_days == days) return;
    setState(() => _days = days);
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    // Si nous sommes dans le MainLayout, cette page occupera l'espace disponible.
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${languageProvider.translate('error')}: $_error',
              style: const TextStyle(color: Colors.red),
            ),
            ElevatedButton(
              onPressed: _loadStats,
              child: Text(languageProvider.translate('tryAgain')),
            ),
          ],
        ),
      );
    }

    if (_stats == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Back
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      _stats!.username.isNotEmpty
                          ? _stats!.username[0].toUpperCase()
                          : 'U',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stats!.username,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        languageProvider.translate('salesStats'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildPeriodSelector(languageProvider),
                ],
              ),
              const SizedBox(height: 24),

              // KPIs
              LayoutBuilder(
                builder: (context, constraints) {
                  int cols = constraints.maxWidth > 800 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    childAspectRatio: 1.8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      StatsCard(
                        icon: Icons.shopping_cart,
                        label: languageProvider.translate('sales'),
                        value: _stats!.totalSales.toString(),
                        iconBgColor: Colors.blue,
                      ),
                      StatsCard(
                        icon: Icons.attach_money,
                        label: languageProvider.translate('revenue'),
                        value: '${_stats!.totalRevenue.toStringAsFixed(0)} FBu',
                        iconBgColor: Colors.green,
                      ),
                      StatsCard(
                        icon: Icons.trending_up,
                        label: languageProvider.translate('avgCart'),
                        value:
                            '${_stats!.averageSaleAmount.toStringAsFixed(0)} FBu',
                        iconBgColor: Colors.purple,
                      ),
                      StatsCard(
                        icon: Icons.people,
                        label: languageProvider.translate('clients'),
                        value: _stats!.customersServed.toString(),
                        iconBgColor: Colors.orange,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${languageProvider.translate('salesEvolution')} ($_days ${languageProvider.translate('days')})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 300,
                        child: _buildChart(languageProvider),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Top Products
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.translate('top10Products'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_stats!.topProducts.isEmpty)
                        Text(languageProvider.translate('noSalesPeriod'))
                      else
                        Table(
                          border: TableBorder(
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                          children: [
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    languageProvider.translate('name'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    languageProvider.translate('code'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    languageProvider.translate('qty'),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    languageProvider.translate('revenue'),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ..._stats!.topProducts.map(
                              (p) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(p.medicineName),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(p.medicineCode),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      p.quantitySold.toString(),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      '${p.revenueGenerated.toStringAsFixed(0)} FBu',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(LanguageProvider languageProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Presets
          ...[7, 30, 90].map(
            (d) => InkWell(
              onTap: () => _updateDays(d),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _days == d ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _days == d
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 2)]
                      : null,
                ),
                child: Text(
                  '$d ${languageProvider.translate('days')}',
                  style: TextStyle(
                    fontWeight: _days == d
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _days == d ? Colors.black : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          // Custom Date Range
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            tooltip: languageProvider.translate('chooseDates'),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                // Determine days difference approx or just reload with explicit dates?
                // UserStatsPage logic relies on _days. We should probably refactor to use start/end in state too.
                // For now, let's just approximate days to reload stats, or better:
                // Update _loadStats to use dates if set.

                final diff = picked.end.difference(picked.start).inDays;
                setState(() => _days = diff > 0 ? diff : 1);
                // Ideally passing picked.start and picked.end to _loadStats
                // But _loadStats uses `now.subtract(days)`.
                // Let's stick to days for now as MVP or refactor _loadStats if critical.
                // Given the request "graph updated according to dates", specific dates are better.
                _loadStats(customRange: picked);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChart(LanguageProvider languageProvider) {
    if (_stats!.salesByDate.isEmpty) {
      return Center(child: Text(languageProvider.translate('noData')));
    }

    // Simplification: Display LineChart with FL Chart
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ), // Trop de dates pour afficher proprement sans logique complexe
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _stats!.salesByDate
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.revenue))
                .toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
