import 'package:flutter/material.dart';
import 'package:frontend1/services/api_service.dart';

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
      final financeFuture = _api.get('/analyse/finance');
      final stockFuture = _api.get('/analyse/stock');
      final vendorsFuture = _api.get('/analyse/vendors');
      final productsFuture = _api.get('/analyse/products');

      final results = await Future.wait([
        financeFuture,
        stockFuture,
        vendorsFuture,
        productsFuture,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erreur de chargement: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadAllAnalytics, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tableau de Bord Analyse & Décision'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllAnalytics,
              tooltip: 'Actualiser les statistiques',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.attach_money), text: 'Finances (12 mois)'),
              Tab(icon: Icon(Icons.inventory_2), text: 'Santé Stock & Dormants'),
              Tab(icon: Icon(Icons.people), text: 'Performance Vendeurs'),
              Tab(icon: Icon(Icons.medication), text: 'Top Médicaments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFinanceTab(),
            _buildStockTab(),
            _buildVendorsTab(),
            _buildProductsTab(),
          ],
        ),
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
                  'Nombre Total Ventes',
                  '$totalSales transactions',
                  Icons.shopping_bag,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Moyenne Mensuelle',
                  '${(avgMonthly as num).toStringAsFixed(0)} FBu',
                  Icons.bar_chart,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Ã‰volution Mensuelle du Chiffre d\'Affaires',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: months.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final m = months[idx];
                return ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                  title: Text('Mois : ${m['month']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${m['sale_count']} ventes enregistrées'),
                  trailing: Text(
                    '${(m['revenue'] as num).toStringAsFixed(0)} FBu',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
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
    // totalMeds
    final stockPurchase = _stockData?['total_stock_value_purchase'] ?? 0.0;
    final stockSale = _stockData?['total_stock_value_sale'] ?? 0.0;
    final margin = _stockData?['potential_margin'] ?? 0.0;
    final slowMovers = (_stockData?['slow_movers'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Valorisation Achat', '${(stockPurchase as num).toStringAsFixed(0)} FBu', Icons.archive, Colors.blueGrey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard('Valorisation Vente', '${(stockSale as num).toStringAsFixed(0)} FBu', Icons.sell, Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard('Marge Potentielle', '${(margin as num).toStringAsFixed(0)} FBu', Icons.monetization_on, Colors.amber[800]!),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Produits Dormants (> 60 jours sans vente)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ces articles immobilisent du capital en stock sans rotation.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Card(
            child: slowMovers.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucun produit dormant identifié.'))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: slowMovers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = slowMovers[idx];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.hourglass_empty, color: Colors.white)),
                        title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Stock actuel : ${item['current_stock']} unités â€¢ P.U Achat : ${item['purchase_price']} FBu'),
                        trailing: Text(
                          'Immobilisé: ${(item['stock_value'] as num).toStringAsFixed(0)} FBu',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
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
          Text('Classement des Vendeurs par Chiffre d\'Affaires',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: _vendorsData.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucune donnée de vente enregistrée pour les utilisateurs.'))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vendorsData.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final v = _vendorsData[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: idx == 0 ? Colors.amber[700] : (idx == 1 ? Colors.grey : Colors.brown[400]),
                          child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(v['cashier_name']?.toString() ?? v['username']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${v['sale_count']} ventes â€¢ Panier moyen : ${(v['average_basket'] as num).toStringAsFixed(0)} FBu'),
                        trailing: Text(
                          '${(v['total_revenue'] as num).toStringAsFixed(0)} FBu',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
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
          Text('Top 10 des Médicaments les Plus Vendus (Volume)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topVolume.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = topVolume[idx];
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.medication, color: Colors.white)),
                  title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Chiffre d\'affaires : ${(p['revenue'] as num).toStringAsFixed(0)} FBu'),
                  trailing: Chip(label: Text('${p['quantity']} unités')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('Top 10 des Médicaments les Plus Rentables (Chiffre d\'Affaires)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topRevenue.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = topRevenue[idx];
                return ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.star, color: Colors.white)),
                  title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p['quantity']} unités vendues'),
                  trailing: Text(
                    '${(p['revenue'] as num).toStringAsFixed(0)} FBu',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16),
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
            CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

