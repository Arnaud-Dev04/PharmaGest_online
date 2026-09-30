import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/sale.dart';
import 'package:frontend1/models/app_settings.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/services/sales_service.dart';
import 'package:frontend1/services/pos_service.dart';
import 'package:frontend1/services/settings_service.dart';
import 'package:frontend1/services/invoice_auto_service.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/screens/sales/user_sales_performance_dialog.dart';
import 'package:frontend1/screens/sales/top_medicines_dialog.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final SalesService _salesService = SalesService();
  final PosService _posService = PosService();

  // États Filtres
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  // États Statistiques Filtres
  final _statsStartDateController = TextEditingController();
  final _statsEndDateController = TextEditingController();

  // Données
  List<Sale> _sales = [];
  List<MedicineSaleStats> _medicineStats = [];
  int _totalSales = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  bool _isLoadingSales = false;
  bool _isLoadingStats = false;
  String? _salesError;

  @override
  void initState() {
    super.initState();
    _loadSales();
    _loadStats();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _statsStartDateController.dispose();
    _statsEndDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoadingSales = true;
      _salesError = null;
    });
    try {
      // Charger les ventes classiques
      final response = await _salesService.getSalesHistory(
        page: _currentPage,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        minAmount: double.tryParse(_minAmountController.text),
        maxAmount: double.tryParse(_maxAmountController.text),
      );

      // Charger les ventes POS (FEFO/lots)
      List<Sale> posSales = [];
      int posTotal = 0;
      try {
        final posResponse = await _posService.getHistory(
          page: _currentPage,
          pageSize: 50,
          startDate: _startDateController.text.isNotEmpty ? _startDateController.text : null,
          endDate: _endDateController.text.isNotEmpty ? _endDateController.text : null,
        );
        final posItems = posResponse['items'] as List? ?? [];
        posSales = posItems
            .map((item) => Sale.fromJson(item as Map<String, dynamic>))
            .toList();
        posTotal = (posResponse['total'] as int?) ?? 0;
      } catch (e) {
        debugPrint('[SalesHistory] POS history fetch error (non-bloquant): $e');
      }

      if (mounted) {
        final mergedSales = [...response.items, ...posSales];
        mergedSales.sort((a, b) => b.date.compareTo(a.date));

        final minAmt = double.tryParse(_minAmountController.text);
        final maxAmt = double.tryParse(_maxAmountController.text);
        final filteredSales = mergedSales.where((s) {
          if (minAmt != null && s.totalAmount < minAmt) return false;
          if (maxAmt != null && s.totalAmount > maxAmt) return false;
          return true;
        }).toList();

        setState(() {
          _sales = filteredSales;
          _totalSales = response.total + posTotal;
          _totalPages = ((_totalSales + 49) ~/ 50).clamp(1, 9999);
          _isLoadingSales = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSales = false;
          _salesError = ErrorHelper.extractErrorMessage(e).contains('connexion') || ErrorHelper.extractErrorMessage(e).contains('connect')
              ? 'Impossible de joindre le serveur.\nVérifiez que le backend est démarré.'
              : 'Erreur de chargement: ${ErrorHelper.extractErrorMessage(e)}';
        });
      }
      debugPrint('Erreur loadSales: $e');
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _salesService.getMedicineSalesStats(
        startDate: _statsStartDateController.text,
        endDate: _statsEndDateController.text,
      );
      if (mounted) {
        setState(() {
          _medicineStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
      debugPrint('Erreur loadStats: $e');
    }
  }

  /// Génère et sauvegarde le PDF d'une vente depuis l'historique.
  Future<void> _downloadInvoice(Sale sale, LanguageProvider lp) async {
    if (!mounted) return;
    final snackController = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Génération du PDF en cours...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      AppSettings settings;
      try {
        settings = await SettingsService().getSettings();
      } catch (_) {
        settings = AppSettings();
      }

      final result = await InvoiceAutoService.generateAndSave(
        sale: sale,
        settings: settings,
        sellerName: sale.userName,
        autoOpen: true,
      );

      snackController.close();

      if (mounted) {
        if (result.isSuccess) {
          final path = result.savedPath ?? 'Documents/PharmaGest/Factures';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PDF sauvegardé : $path',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur PDF : ${result.error}'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    } catch (e) {
      snackController.close();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lp.translate('error')}: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _cancelSale(Sale sale, LanguageProvider lp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lp.translate('cancelSale')),
        content: Text(
          '${lp.translate('cancelSaleConfirm')} #${sale.code} ?\n${lp.translate('stockWillBeRestored')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lp.translate('no')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: Text(lp.translate('yesCancel')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (sale.code.startsWith('POS-')) {
          await _posService.cancelSale(sale.id);
        } else {
          await _salesService.cancelSale(sale.id);
        }
        _loadSales();
        _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lp.translate('saleCancelled')),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lp.translate('error')}: $e'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.translate('salesHistory'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      languageProvider.translate('salesHistorySubtitle'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => UserSalesPerformanceDialog.show(context),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                    label: Text(
                      Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin' ||
                              Provider.of<AuthProvider>(context, listen: false).user?.role == 'super_admin'
                          ? 'Performances Vendeurs'
                          : 'Mes Ventes (Bilan)',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin' ||
                      Provider.of<AuthProvider>(context, listen: false).user?.role == 'super_admin')
                    ElevatedButton.icon(
                      onPressed: () => TopMedicinesDialog.show(context),
                      icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                      label: const Text('Palmarès & Rentabilité'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filtres
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.translate('filters'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildDateFilter(languageProvider.translate('startDate'), _startDateController),
                      _buildDateFilter(languageProvider.translate('endDate'), _endDateController),
                      _buildNumberFilter('${languageProvider.translate('min')} (FBu)', _minAmountController),
                      _buildNumberFilter('${languageProvider.translate('max')} (FBu)', _maxAmountController),
                      ElevatedButton.icon(
                        onPressed: () {
                          _currentPage = 1;
                          _loadSales();
                        },
                        icon: const Icon(Icons.filter_list),
                        label: Text(languageProvider.translate('filter')),
                      ),
                      TextButton(
                        onPressed: () {
                          _startDateController.clear();
                          _endDateController.clear();
                          _minAmountController.clear();
                          _maxAmountController.clear();
                          _currentPage = 1;
                          _loadSales();
                        },
                        child: Text(languageProvider.translate('reset')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Summary Card
          if (_sales.isNotEmpty)
            Card(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.translate('totalSalesDisplayed'),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_totalSales ${languageProvider.translate('sales')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_sales.fold<double>(0, (sum, item) => sum + item.totalAmount).toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          languageProvider.translate('totalOnThisPage'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_sales.isNotEmpty) const SizedBox(height: 24),

          // Tableau Ventes
          SizedBox(
            height: 500,
            child: Card(
              child: _isLoadingSales
                  ? const Center(child: CircularProgressIndicator())
                  : _salesError != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off, size: 56, color: Colors.orange),
                          const SizedBox(height: 16),
                          Text(
                            _salesError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loadSales,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 800,
                            columns: [
                              DataColumn2(
                                label: Text(languageProvider.translate('medicines')),
                                size: ColumnSize.L,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('date')),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('price')),
                                size: ColumnSize.S,
                                numeric: true,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('status')),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('user')),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('client')),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('actions')),
                                size: ColumnSize.S,
                              ),
                            ],
                            rows: _sales
                                .map(
                                  (sale) => DataRow(
                                    onSelectChanged: (_) => _showInvoiceDetail(sale),
                                    color: sale.status == 'cancelled'
                                        ? WidgetStateProperty.all(
                                            Colors.red.withValues(alpha: 0.05),
                                          )
                                        : null,
                                    cells: [
                                      // Colonne 1 : Articles
                                      DataCell(
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (sale.code.startsWith('POS-'))
                                              Container(
                                                margin: const EdgeInsets.only(bottom: 2),
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  'POS · ${sale.code}',
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.teal,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ...sale.items.take(2).map(
                                              (i) => Text(
                                                '${i.medicineName} x${i.quantity}',
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Colonne 2 : Date
                                      DataCell(
                                        Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(sale.date)),
                                      ),
                                      // Colonne 3 : Montant
                                      DataCell(
                                        Text(
                                          '${sale.totalAmount.toStringAsFixed(0)} FBu',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      // Colonne 4 : Statut
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: sale.status == 'cancelled'
                                                ? Colors.red[100]
                                                : Colors.green[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: sale.status == 'cancelled'
                                              ? GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Row(
                                                          children: [
                                                            const Icon(Icons.info_outline, color: Colors.blue),
                                                            const SizedBox(width: 8),
                                                            Text(languageProvider.translate('cancelledSaleDetails')),
                                                          ],
                                                        ),
                                                        content: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              '${languageProvider.translate('cancelledBy')}: ${sale.cancelledBy ?? "N/A"}',
                                                              style: const TextStyle(fontSize: 16),
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Text(
                                                              '${languageProvider.translate('cancelledAt')}: ${sale.cancelledAt != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(sale.cancelledAt!) : "N/A"}',
                                                              style: const TextStyle(fontSize: 16),
                                                            ),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx),
                                                            child: Text(languageProvider.translate('close')),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    languageProvider.translate('cancelled'),
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  languageProvider.translate('completed'),
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      // Colonne 5 : Vendeur
                                      DataCell(Text(sale.userName)),
                                      // Colonne 6 : Client
                                      DataCell(Text(sale.customerName ?? sale.customerPhone ?? '-')),
                                      // Colonne 7 : Actions
                                      DataCell(
                                        Row(
                                          children: [
                                            Tooltip(
                                              message: 'Télécharger / Voir facture PDF',
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.picture_as_pdf,
                                                  size: 18,
                                                  color: Color(0xFFE53935),
                                                ),
                                                onPressed: () => _downloadInvoice(sale, languageProvider),
                                              ),
                                            ),
                                            if (sale.status != 'cancelled')
                                              Tooltip(
                                                message: 'Annuler la vente',
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.cancel,
                                                    size: 18,
                                                    color: AppTheme.dangerColor,
                                                  ),
                                                  onPressed: () => _cancelSale(sale, languageProvider),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        // Pagination
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${languageProvider.translate('page')} $_currentPage / $_totalPages'),
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 1
                                    ? () {
                                        setState(() => _currentPage--);
                                        _loadSales();
                                      }
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < _totalPages
                                    ? () {
                                        setState(() => _currentPage++);
                                        _loadSales();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Section
          Text(
            languageProvider.translate('medicineStats'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildDateFilter(languageProvider.translate('startDate'), _statsStartDateController),
                      const SizedBox(width: 16),
                      _buildDateFilter(languageProvider.translate('endDate'), _statsEndDateController),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _loadStats,
                        child: Text(languageProvider.translate('refresh')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _isLoadingStats
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        )
                      : SizedBox(
                          height: 300,
                          child: DataTable2(
                            columns: [
                              DataColumn2(label: Text(languageProvider.translate('medicine'))),
                              DataColumn2(label: Text(languageProvider.translate('code'))),
                              DataColumn2(
                                label: Text(languageProvider.translate('qtSold')),
                                numeric: true,
                              ),
                              DataColumn2(
                                label: Text(languageProvider.translate('totalRevenue')),
                                numeric: true,
                              ),
                            ],
                            rows: _medicineStats
                                .map(
                                  (stat) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text(stat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      DataCell(Text(stat.code)),
                                      DataCell(Text('${stat.totalQuantity}')),
                                      DataCell(
                                        Text(
                                          '${stat.totalRevenue.toStringAsFixed(0)} FBu',
                                          style: const TextStyle(color: AppTheme.successColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(String label, TextEditingController controller) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (date != null) {
            controller.text = DateFormat('yyyy-MM-dd').format(date);
          }
        },
      ),
    );
  }

  Widget _buildNumberFilter(String label, TextEditingController controller) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  /// Affiche les détails d'une facture dans un dialog
  void _showInvoiceDetail(Sale sale) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: sale.status == 'cancelled' ? AppTheme.dangerColor : AppTheme.primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Facture ${sale.code}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dateFormat.format(sale.date),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (sale.status == 'cancelled')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ANNULÉE',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _invoiceChip(Icons.person, sale.userName),
                          _invoiceChip(
                            Icons.credit_card,
                            sale.paymentMethod == 'cash' ? 'Espèces' : 'Assurance',
                          ),
                          if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty)
                            _invoiceChip(Icons.phone, sale.customerPhone!),
                          if (sale.customerName != null && sale.customerName!.isNotEmpty)
                            _invoiceChip(Icons.person_outline, sale.customerName!),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Table articles
                      Text(
                        'Articles',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Produit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
                                  Expanded(child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
                                  Expanded(flex: 2, child: Text('P.U.', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
                                  Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
                                ],
                              ),
                            ),
                            ...sale.items.map((item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(item.medicineName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                      Expanded(child: Text('x${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                      Expanded(flex: 2, child: Text('${item.unitPrice.toStringAsFixed(0)} FBu', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                      Expanded(flex: 2, child: Text('${item.totalPrice.toStringAsFixed(0)} FBu', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                    ],
                                  ),
                                  // Badge remise si applicable sur cet article
                                  if (item.discountPercent > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.red[200]!),
                                        ),
                                        child: Text(
                                          'Remise -${item.discountPercent.toStringAsFixed(0)}% appliquée',
                                          style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Badge remise globale (si au moins un article a une remise)
                      Builder(builder: (context) {
                        final hasDiscount = sale.items.any((i) => i.discountPercent > 0);
                        if (!hasDiscount) return const SizedBox.shrink();
                        final pct = sale.items.firstWhere((i) => i.discountPercent > 0).discountPercent;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.local_offer, size: 16, color: Colors.red[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Bonus client : remise de ${pct.toStringAsFixed(0)}% appliquée',
                                  style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Total
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                            ),
                            Text(
                              '${sale.totalAmount.toStringAsFixed(0)} FBu',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    // Fermer
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      child: const Text('Fermer'),
                    ),
                    const SizedBox(width: 8),

                    // Télécharger PDF
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final lp = Provider.of<LanguageProvider>(context, listen: false);
                          await _downloadInvoice(sale, lp);
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFE53935)),
                        label: const Text('Télécharger PDF', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                          side: const BorderSide(color: Color(0xFFE53935)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Imprimer
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          AppSettings settings;
                          try {
                            settings = await SettingsService().getSettings();
                          } catch (_) {
                            settings = AppSettings();
                          }
                          await InvoiceAutoService.printInvoice(
                            sale: sale,
                            settings: settings,
                            sellerName: sale.userName,
                          );
                        },
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Imprimer', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
