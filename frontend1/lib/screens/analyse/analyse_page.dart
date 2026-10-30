import 'package:flutter/material.dart';
import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/widgets/common/modern_tab_bar.dart';


class AnalysePage extends StatefulWidget {
  const AnalysePage({super.key});

  @override
  State<AnalysePage> createState() => _AnalysePageState();
}

class _AnalysePageState extends State<AnalysePage> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _financeData;
  Map<String, dynamic>? _stockData;
  List<Map<String, dynamic>> _vendorsData = [];
  Map<String, dynamic>? _productsData;

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.get('/analyse/finance'),
        _api.get('/analyse/stock'),
        _api.get('/analyse/vendors'),
        _api.get('/analyse/products'),
      ]);

      if (mounted) {
        setState(() {
          _financeData = Map<String, dynamic>.from(results[0].data as Map);
          _stockData = Map<String, dynamic>.from(results[1].data as Map);
          _vendorsData = (results[2].data as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _productsData = Map<String, dynamic>.from(results[3].data as Map);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Erreur de chargement:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: ModernPillTabBar(
                    isScrollable: true,
                    tabs: [
                      ModernTab(icon: Icons.payments_outlined, text: 'Finances'),
                      ModernTab(icon: Icons.inventory_2_outlined, text: 'Stock'),
                      ModernTab(icon: Icons.people_alt_outlined, text: 'Vendeurs'),
                      ModernTab(icon: Icons.medication_outlined, text: 'Produits'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _loadAllAnalytics,
                  tooltip: 'Actualiser',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFinanceTab(),
                _buildStockTab(),
                _buildVendorsTab(),
                _buildProductsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceTab() {
    final months = (_financeData?['monthly_revenue'] as List<dynamic>?) ?? [];
    final totalRev = _financeData?['total_revenue_12m'] ?? 0.0;
    final totalSales = _financeData?['total_sales_12m'] ?? 0;
    final avgMonthly = _financeData?['average_monthly_revenue'] ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'CA Total (12 mois)',
                  '${(totalRev as num).toStringAsFixed(0)} FBu',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Total Ventes',
                  '$totalSales transactions',
                  Icons.shopping_bag,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Moy. Mensuelle',
                  '${(avgMonthly as num).toStringAsFixed(0)} FBu',
                  Icons.bar_chart,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Evolution Mensuelle du CA (12 derniers mois)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: months.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune vente enregistree sur les 12 derniers mois.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: months.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final m = months[idx];
                      return ListTile(
                        leading: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                        title: Text(
                          'Mois : ${m['month']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${m['sale_count']} ventes'),
                        trailing: Text(
                          '${(m['revenue'] as num).toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    final stockPurchase = _stockData?['total_stock_value_purchase'] ?? 0.0;
    final stockSale = _stockData?['total_stock_value_sale'] ?? 0.0;
    final margin = _stockData?['potential_margin'] ?? 0.0;
    final lowStock = _stockData?['low_stock_count'] ?? 0;
    final slowMovers = (_stockData?['slow_movers'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Valeur Achat',
                  '${(stockPurchase as num).toStringAsFixed(0)} FBu',
                  Icons.archive,
                  Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Valeur Vente',
                  '${(stockSale as num).toStringAsFixed(0)} FBu',
                  Icons.sell,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Marge Potentielle',
                  '${(margin as num).toStringAsFixed(0)} FBu',
                  Icons.monetization_on,
                  Colors.amber[800]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lowStock > 0)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '$lowStock medicament(s) en stock bas',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Produits Dormants (> 60 jours sans vente)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ces articles immobilisent du capital en stock sans rotation.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Card(
            child: slowMovers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun produit dormant identifie.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: slowMovers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = slowMovers[idx];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.hourglass_empty, color: Colors.white),
                        ),
                        title: Text(
                          item['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Stock: ${item['current_stock']} u. | Prix achat: ${item['purchase_price']} FBu',
                        ),
                        trailing: Text(
                          '${(item['stock_value'] as num).toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classement des Vendeurs par Chiffre d\'Affaires',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: _vendorsData.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune donnee de vente enregistree pour les utilisateurs.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vendorsData.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final v = _vendorsData[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: idx == 0
                              ? Colors.amber[700]
                              : (idx == 1 ? Colors.grey : Colors.brown[400]),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          v['cashier_name']?.toString() ?? v['username']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${v['sale_count']} ventes | Panier moy: ${(v['average_basket'] as num).toStringAsFixed(0)} FBu',
                        ),
                        trailing: Text(
                          '${(v['total_revenue'] as num).toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    final topVolume = (_productsData?['top_by_volume'] as List<dynamic>?) ?? [];
    final topRevenue = (_productsData?['top_by_revenue'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 10 Medicaments les Plus Vendus (Volume)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: topVolume.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune vente enregistree.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topVolume.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final p = topVolume[idx];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.medication, color: Colors.white),
                        ),
                        title: Text(
                          p['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'CA: ${(p['revenue'] as num).toStringAsFixed(0)} FBu',
                        ),
                        trailing: Chip(label: Text('${p['quantity']} u.')),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          Text(
            'Top 10 Medicaments les Plus Rentables (CA)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: topRevenue.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucune vente enregistree.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: topRevenue.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final p = topRevenue[idx];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.star, color: Colors.white),
                        ),
                        title: Text(
                          p['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${p['quantity']} unites vendues'),
                        trailing: Text(
                          '${(p['revenue'] as num).toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
