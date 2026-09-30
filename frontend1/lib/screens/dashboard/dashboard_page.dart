import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/dashboard_stats.dart';
import 'package:frontend1/services/dashboard_service.dart';
import 'package:frontend1/widgets/dashboard/stats_card.dart';
import 'package:frontend1/widgets/dashboard/period_toggle.dart';
import 'package:frontend1/widgets/dashboard/revenue_chart.dart';
import 'package:frontend1/widgets/dashboard/sales_patterns_charts.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/inventory_provider.dart';
import 'package:frontend1/services/prix_calculator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/error_helper.dart';

/// Page Dashboard complète reproduisant le design React
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();

  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;
  String? _error;
  int _selectedPeriod = 7;
  DashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      String? startDate;
      String? endDate;

      if (_selectedDateRange != null) {
        startDate = dateFormat.format(_selectedDateRange!.start);
        endDate = dateFormat.format(_selectedDateRange!.end);
      }

      final stats = await _dashboardService.getDashboardStats(
        _selectedPeriod,
        startDate: startDate,
        endDate: endDate,
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

  void _onPeriodChanged(int period) {
    setState(() {
      _selectedPeriod = period;
      _selectedDateRange =
          null; // Reset custom range if period preset is clicked
    });
    _loadDashboardStats();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        // Optionally update _selectedPeriod to something that indicates custom
      });
      _loadDashboardStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.user?.isAdmin ?? false;

    // Loading state
    if (_isLoading) {
      return _buildLoadingView(languageProvider);
    }

    // Error state
    if (_error != null) {
      return _buildErrorView(languageProvider);
    }

    // Empty stats protection
    if (_stats == null) {
      return _buildErrorView(languageProvider);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(languageProvider),
          const SizedBox(height: 24),

          // Stats Cards Grid
          _buildStatsGrid(languageProvider),
          const SizedBox(height: 24),

          // Revenue Chart — admin seulement
          if (isAdmin) ...[
            _buildRevenueChartCard(languageProvider),
            const SizedBox(height: 24),
          ],

          // Sales By Day Chart
          _buildSalesByDayCard(languageProvider),
          const SizedBox(height: 24),

          // Sales By Hour Chart
          _buildSalesByHourCard(languageProvider),
          const SizedBox(height: 24),

          // Recent Sales Table
          _buildRecentSalesCard(languageProvider),
          const SizedBox(height: 24),

          // Top Selling Products Table
          _buildTopProductsCard(languageProvider),
          const SizedBox(height: 24),

          // Expiring Medicines Table
          _buildExpiringMedicinesCard(languageProvider),
        ],
      ),
    );
  }

  // ========================================================================
  // HEADER
  // ========================================================================

  Widget _buildHeader(LanguageProvider languageProvider) {
    final auth = Provider.of<AuthProvider>(context);
    final inv = Provider.of<InventoryProvider>(context);
    final isAdmin = auth.user?.isAdmin ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.translate('dashboard'),
                style: Theme.of(
                  context,
                ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                languageProvider.translate('dashboardSubtitle'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkSidebarText
                      : AppTheme.lightSidebarText,
                ),
              ),
            ],
          ),
        ),

        // Admin actions (Refresh)
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 6.0),
            child: Row(
              children: [
                if (inv.loading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Rafraîchir',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      try {
                        await Provider.of<InventoryProvider>(context, listen: false)
                            .loadTotals();
                        await _loadDashboardStats();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rafraîchi')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ========================================================================
  // STATS CARDS GRID
  // ========================================================================

  Widget _buildStatsGrid(LanguageProvider languageProvider) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).user?.isAdmin ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid : 1 col mobile, 2 col tablet, 3 col desktop
        int crossAxisCount = 1;
        if (constraints.maxWidth > 600) crossAxisCount = 2;
        if (constraints.maxWidth > 900) crossAxisCount = 3;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 2.5,
          children: [
            // 1. Total Medicines (stock)
            StatsCard(
              icon: Icons.inventory_2,
              label: languageProvider.translate('totalMedicines'),
              value: _stats!.totalMedicines.toString(),
              iconBgColor: Colors.blue,
              onTap: () => _showModal(context, 'totalMedicines', languageProvider),
            ),

            // 2. Total Sales Count (nombre uniquement, sans montant)
            StatsCard(
              icon: Icons.receipt_long,
              label: languageProvider.translate('totalSales'),
              value: _stats!.totalSalesCount.toString(),
              iconBgColor: Colors.indigo,
              onTap: () => _showModal(context, 'totalSales', languageProvider),
            ),

            // 3. Weekly Sales — admin seulement (montant en FBu)
            if (isAdmin)
              StatsCard(
                icon: Icons.shopping_cart,
                label: languageProvider.translate('weeklySales'),
                value: '${_stats!.weeklySales.toStringAsFixed(0)} FBu',
                iconBgColor: AppTheme.successColor,
                onTap: () => _showModal(context, 'weeklySales', languageProvider),
              ),

            // 4. Suppliers
            StatsCard(
              icon: Icons.local_shipping,
              label: languageProvider.translate('suppliers'),
              value: _stats!.totalSuppliers.toString(),
              iconBgColor: Colors.purple,
              onTap: () => _showModal(context, 'suppliers', languageProvider),
            ),

            // 5. Expiring Soon
            StatsCard(
              icon: Icons.warning_amber,
              label: languageProvider.translate('expiringSoon'),
              value: _stats!.expiringSoonCount.toString(),
              iconBgColor: AppTheme.warningColor,
              onTap: () =>
                  _showModal(context, 'expiringSoon', languageProvider),
            ),

            // 6. Low Stock
            StatsCard(
              icon: Icons.error_outline,
              label: languageProvider.translate('lowStock'),
              value: _stats!.lowStockMedicines.toString(),
              iconBgColor: AppTheme.dangerColor,
              onTap: () => _showModal(context, 'lowStock', languageProvider),
            ),

            // 7. Total Revenue — admin seulement
            if (isAdmin)
              StatsCard(
                icon: Icons.attach_money,
                label: languageProvider.translate('revenue'),
                value: '${_stats!.totalRevenue.toStringAsFixed(0)} FBu',
                iconBgColor: Colors.teal,
                onTap: () =>
                    _showModal(context, 'totalRevenue', languageProvider),
              ),

            // 8. Cancelled Sales
            StatsCard(
              icon: Icons.cancel,
              label: languageProvider.translate('cancelled'),
              value: _stats!.cancelledSales.toString(),
              iconBgColor: Colors.red[700]!,
              onTap: () =>
                  _showModal(context, 'cancelledSales', languageProvider),
            ),

            // 9. Top Selling Products
            StatsCard(
              icon: Icons.star,
              label: languageProvider.translate('topProducts'),
              value: _stats!.topSellingProducts.length.toString(),
              iconBgColor: Colors.amber,
              onTap: () => _showModal(context, 'topProducts', languageProvider),
            ),

            // Admin-only: inventory totals (purchase & sell)
            if (isAdmin) ...[
              StatsCard(
                icon: Icons.account_balance_wallet,
                label: 'Valeur stock (achat)',
                value: PrixCalculator.fmtFBu(_stats!.totalPurchaseValue),
                iconBgColor: Colors.lightBlue,
                onTap: () => _showModal(context, 'totalPurchaseValue', languageProvider),
              ),

              StatsCard(
                icon: Icons.sell,
                label: 'Valeur stock (vente)',
                value: PrixCalculator.fmtFBu(_stats!.totalSellValue),
                iconBgColor: Colors.green,
                onTap: () => _showModal(context, 'totalSellValue', languageProvider),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showModal(
    BuildContext context,
    String type,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_getModalTitle(type, languageProvider)),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: _buildModalContent(type, languageProvider),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.translate('close')),
            ),
          ],
        );
      },
    );
  }

  String _getModalTitle(String type, LanguageProvider lp) {
    switch (type) {
      case 'totalMedicines':
        return lp.translate('totalMedicines');
      case 'totalSales':
        return lp.translate('totalSales');
      case 'weeklySales':
        return lp.translate('sales');
      case 'suppliers':
        return lp.translate('suppliers');
      case 'expiringSoon':
        return lp.translate('expiringSoon');
      case 'lowStock':
        return lp.translate('lowStock');
      case 'totalRevenue':
        return lp.translate('revenue');
      case 'cancelledSales':
        return lp.translate('cancelled');
      case 'topProducts':
        return lp.translate('topProducts');
      case 'totalPurchaseValue':
        return 'Valeur stock (achat)';
      case 'totalSellValue':
        return 'Valeur stock (vente)';
      default:
        return '';
    }
  }

  Widget _buildModalContent(String type, LanguageProvider lp) {
    switch (type) {
      case 'totalMedicines':
        return Column(
          children: [
            _buildSummaryBox(
              Colors.blue,
              lp.translate('totalMedicines'),
              _stats!.totalMedicines.toString(),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stock');
              },
              child: Text(lp.translate('actions')),
            ),
          ],
        );
      case 'totalSales':
        final isAdminTs = Provider.of<AuthProvider>(context, listen: false).user?.isAdmin ?? false;
        return Column(
          children: [
            _buildSummaryBox(
              Colors.indigo,
              lp.translate('totalSales'),
              _stats!.totalSalesCount.toString(),
            ),
            const SizedBox(height: 16),
            if (_stats!.recentSales.isNotEmpty && isAdminTs) ...[
              Text(
                lp.translate('recentSales'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTable(
                headers: ['Date', 'Montant'],
                rows: _stats!.recentSales
                    .take(5)
                    .map(
                      (s) => [
                        DateFormat('dd/MM HH:mm').format(s.date),
                        '${s.totalAmount.toStringAsFixed(0)} FBu',
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
        );
      case 'weeklySales':
        final isAdminWs = Provider.of<AuthProvider>(context, listen: false).user?.isAdmin ?? false;
        return Column(
          children: [
            _buildSummaryBox(
              AppTheme.successColor,
              'Ventes cette semaine',
              isAdminWs ? _stats!.weeklySales.toString() : '—',
            ),
            const SizedBox(height: 16),
            if (_stats!.recentSales.isNotEmpty && isAdminWs) ...[
              Text(
                lp.translate('recentSales'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTable(
                headers: ['Date', 'Montant'],
                rows: _stats!.recentSales
                    .take(5)
                    .map(
                      (s) => [
                        DateFormat('dd/MM HH:mm').format(s.date),
                        '${s.totalAmount.toStringAsFixed(0)} FBu',
                      ],
                    )
                    .toList(),
              ),
            ],
          ],
        );
      case 'suppliers':
        return Column(
          children: [
            _buildSummaryBox(
              Colors.purple,
              lp.translate('total'),
              _stats!.totalSuppliers.toString(),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/suppliers');
              },
              child: Text(lp.translate('actions')),
            ),
          ],
        );
      case 'expiringSoon':
        return Column(
          children: [
            _buildSummaryBox(
              AppTheme.warningColor,
              lp.translate('expiringSoon'),
              _stats!.expiringSoonCount.toString(),
            ),
            const SizedBox(height: 16),
            if (_stats!.expiringSoon.isNotEmpty)
              _buildTable(
                headers: ['Nom', 'Exp.', 'Qté'],
                rows: _stats!.expiringSoon
                    .map(
                      (m) => [
                        m.name,
                        DateFormat('dd/MM/yy').format(m.expiryDate),
                        m.quantity.toString(),
                      ],
                    )
                    .toList(),
              ),
          ],
        );
      case 'lowStock':
        return Column(
          children: [
            _buildSummaryBox(
              AppTheme.dangerColor,
              'Stock Faible',
              _stats!.lowStockMedicines.toString(),
            ),
            const SizedBox(height: 16),
            if (_stats!.lowStockList.isNotEmpty) ...[
              Text(
                lp.translate('lowStock'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildTable(
                headers: ['Nom', 'Qté', 'Min'],
                rows: _stats!.lowStockList
                    .map(
                      (m) => [
                        m.name,
                        m.quantity.toString(),
                        m.minStock.toString(),
                      ],
                    )
                    .toList(),
              ),
            ] else ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/stock');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.dangerColor,
                ),
                child: Text(lp.translate('actions')),
              ),
            ],
          ],
        );
      case 'totalRevenue':
        return Column(
          children: [
            _buildSummaryBox(
              Colors.teal,
              lp.translate('revenue'),
              '${_stats!.totalRevenue.toStringAsFixed(0)} FBu',
            ),
            const SizedBox(height: 16),
            RevenueChart(data: _stats!.revenueChart),
          ],
        );
      case 'cancelledSales':
        // Calculate dates for filter
        String? csStartDate;
        String? csEndDate;
        final csDateFormat = DateFormat('yyyy-MM-dd');
        if (_selectedDateRange != null) {
          csStartDate = csDateFormat.format(_selectedDateRange!.start);
          csEndDate = csDateFormat.format(_selectedDateRange!.end);
        } else if (_selectedPeriod > 0) {
          final end = DateTime.now();
          final start = end.subtract(Duration(days: _selectedPeriod));
          csStartDate = csDateFormat.format(start);
          csEndDate = csDateFormat.format(end);
        }

        return FutureBuilder<List<CancelledSale>>(
          future: _dashboardService.getCancelledSales(
            startDate: csStartDate,
            endDate: csEndDate,
          ),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }
            final sales = snapshot.data ?? [];
            if (sales.isEmpty) return Text(lp.translate('noSales'));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryBox(
                  Colors.red[700]!,
                  lp.translate('total'),
                  sales.length.toString(),
                ),
                const SizedBox(height: 16),
                // Detailed list of each cancelled sale
                ...sales.map((s) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Invoice code + amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${s.totalAmount.toStringAsFixed(0)} FBu',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lp.translate('cancelled'),
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        // Who cancelled
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              '${lp.translate('cancelledBy')}: ',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            Text(
                              s.userName ?? 'ID: ${s.userId}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // When cancelled
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              '${lp.translate('cancelledAt')}: ',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(s.cancelledAt ?? s.date),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Sale date
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              '${lp.translate('date')} vente: ',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(s.date),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        // Medicines in the sale
                        if (s.items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  s.items.map((i) => i.medicineName).join(', '),
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      case 'topProducts':
        return Column(
          children: [
            _buildSummaryBox(
              Colors.amber,
              lp.translate('topProducts'),
              _stats!.topSellingProducts.length.toString(),
            ),
            const SizedBox(height: 16),
            if (_stats!.topSellingProducts.isNotEmpty)
              _buildTable(
                headers: [
                  lp.translate('name'),
                  lp.translate('code'),
                  lp.translate('quantity'),
                ],
                rows: _stats!.topSellingProducts
                    .map((p) => [p.name, p.code, p.totalSold.toString()])
                    .toList(),
              ),
          ],
        );

      case 'totalPurchaseValue':
        return Column(
          children: [
            _buildSummaryBox(
              Colors.lightBlue,
              'Valeur stock (achat)',
              PrixCalculator.fmtFBu(_stats!.totalPurchaseValue),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stock');
              },
              child: const Text('Voir le stock'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await Provider.of<InventoryProvider>(context, listen: false).loadTotals();
                  await _loadDashboardStats();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rafraîchi')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Rafraîchir'),
            ),
          ],
        );

      case 'totalSellValue':
        return Column(
          children: [
            _buildSummaryBox(
              Colors.green,
              'Valeur stock (vente)',
              PrixCalculator.fmtFBu(_stats!.totalSellValue),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stock');
              },
              child: const Text('Voir le stock'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await Provider.of<InventoryProvider>(context, listen: false).loadTotals();
                  await _loadDashboardStats();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rafraîchi')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Rafraîchir'),
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildSummaryBox(Color color, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // REVENUE CHART CARD
  // ========================================================================

  Widget _buildRevenueChartCard(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec toggle période
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      languageProvider.translate('revenue'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Period Toggle & Date Picker
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      tooltip: 'Choisir une période',
                      onPressed: _pickDateRange,
                    ),
                    const SizedBox(width: 8),
                    PeriodToggle(
                      selectedPeriod: _selectedPeriod,
                      onPeriodChanged: _onPeriodChanged,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Graphique
            RevenueChart(data: _stats!.revenueChart),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SALES PATTERNS CARDS
  // ========================================================================

  Widget _buildSalesByDayCard(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_view_week, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "Ventes par Jour", // TODO: Add translation key 'salesByDay'
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SalesByDayChart(data: _stats!.salesByDay),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesByHourCard(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  "Ventes par Heure", // TODO: Add translation key 'salesByHour'
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SalesByHourChart(data: _stats!.salesByHour),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // RECENT SALES TABLE
  // ========================================================================

  Widget _buildRecentSalesCard(LanguageProvider languageProvider) {
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).user?.isAdmin ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.translate('recentSales'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/sales-history');
                  },
                  child: Text('${languageProvider.translate('actions')} →'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_stats!.recentSales.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(languageProvider.translate('noSales')),
                ),
              )
            else if (isAdmin)
              // Admin : affiche date + montant
              _buildTable(
                headers: ['Date', languageProvider.translate('price')],
                rows: _stats!.recentSales.map((sale) {
                  return [
                    DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(sale.date),
                    '${sale.totalAmount.toStringAsFixed(2)} FBu',
                  ];
                }).toList(),
              )
            else
              // Pharmacist : affiche date uniquement, sans montant
              _buildTable(
                headers: ['Date', 'Code'],
                rows: _stats!.recentSales.map((sale) {
                  return [
                    DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(sale.date),
                    sale.code,
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // TOP SELLING PRODUCTS TABLE
  // ========================================================================

  Widget _buildTopProductsCard(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.successColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  languageProvider.translate('topProducts'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_stats!.topSellingProducts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(languageProvider.translate('noDataAvailable')),
                ),
              )
            else
              _buildTable(
                headers: [
                  languageProvider.translate('name'),
                  languageProvider.translate('code'),
                  languageProvider.translate('quantity'),
                ],
                rows: _stats!.topSellingProducts.map((product) {
                  return [
                    product.name,
                    product.code,
                    product.totalSold.toString(),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // EXPIRING MEDICINES TABLE
  // ========================================================================

  Widget _buildExpiringMedicinesCard(LanguageProvider languageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppTheme.warningColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  languageProvider.translate('expiringSoon'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_stats!.expiringSoon.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(languageProvider.translate('noMedicinesFound')),
                ),
              )
            else
              _buildTable(
                headers: [
                  languageProvider.translate('name'),
                  'Code',
                  languageProvider.translate('expiryDate'),
                  languageProvider.translate('quantity'),
                ],
                rows: _stats!.expiringSoon.map((medicine) {
                  return [
                    medicine.name,
                    medicine.code,
                    DateFormat(
                      'dd/MM/yyyy',
                      'fr_FR',
                    ).format(medicine.expiryDate),
                    medicine.quantity.toString(),
                  ];
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // HELPER: BUILD TABLE
  // ========================================================================

  Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
        bottom: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
          ),
          children: headers.map((header) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                header,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppTheme.darkSidebarText
                      : AppTheme.lightSidebarText,
                ),
              ),
            );
          }).toList(),
        ),

        // Data rows
        ...rows.map((row) {
          return TableRow(
            children: row.asMap().entries.map((entry) {
              final isLastColumn = entry.key == row.length - 1;
              final isAmount = entry.value.startsWith('F');

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  entry.value,
                  textAlign: isLastColumn ? TextAlign.right : TextAlign.left,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isAmount || headers[entry.key] == 'Quantité Vendue'
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isAmount || headers[entry.key] == 'Quantité Vendue'
                        ? AppTheme.successColor
                        : (isDark
                              ? AppTheme.darkSidebarText
                              : AppTheme.lightSidebarText),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  // ========================================================================
  // STATES: LOADING & ERROR
  // ========================================================================

  Widget _buildLoadingView(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            languageProvider.translate('loading'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSidebarText
                  : AppTheme.lightSidebarText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.dangerColor),
          const SizedBox(height: 16),
          Text(
            languageProvider.translate('loadingError'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${languageProvider.translate('errorLoadingMedicines')}.\n${languageProvider.translate('tryAgain')}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSidebarText
                  : AppTheme.lightSidebarText,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDashboardStats,
            icon: const Icon(Icons.refresh),
            label: Text(languageProvider.translate('tryAgain')),
          ),
        ],
      ),
    );
  }
}
