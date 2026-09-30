import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:frontend1/services/pos_service.dart';

/// Dialogue interactif affichant :
/// 1. Les médicaments les plus vendus en volume (quantité)
/// 2. Les médicaments les plus rentables (qui font gagner le plus d'argent / marge nette)
/// Basé sur l'historique complet des ventes de tous les comptes.
class TopMedicinesDialog extends StatefulWidget {
  const TopMedicinesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const TopMedicinesDialog(),
    );
  }

  @override
  State<TopMedicinesDialog> createState() => _TopMedicinesDialogState();
}

class _TopMedicinesDialogState extends State<TopMedicinesDialog> {
  final PosService _posService = PosService();
  final NumberFormat _currencyFmt = NumberFormat('#,###', 'fr_FR');
  final DateFormat _dateDisplayFmt = DateFormat('dd/MM/yyyy');
  final DateFormat _apiDateFmt = DateFormat('yyyy-MM-dd');

  // Filtres
  String _selectedPreset = 'month'; // 'today', 'week', 'month', 'year', 'all', 'custom'
  String _sortBy = 'quantity'; // 'quantity', 'profit', 'revenue'
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _setPreset('month');
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      if (preset == 'today') {
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day);
      } else if (preset == 'week') {
        _startDate = now.subtract(const Duration(days: 6));
        _endDate = now;
      } else if (preset == 'month') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      } else if (preset == 'year') {
        _startDate = DateTime(now.year, 1, 1);
        _endDate = now;
      } else if (preset == 'all') {
        _startDate = null;
        _endDate = null;
      }
    });
    _loadTopMedicines();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: _startDate ?? now.subtract(const Duration(days: 30)),
        end: _endDate ?? now,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadTopMedicines();
    }
  }

  Future<void> _loadTopMedicines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sStr = _startDate != null ? _apiDateFmt.format(_startDate!) : null;
      final eStr = _endDate != null ? _apiDateFmt.format(_endDate!) : null;

      final res = await _posService.getTopMedicines(
        startDate: sStr,
        endDate: eStr,
        sortBy: _sortBy,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _data = res;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1050 ? 1000.0 : screenWidth * 0.96;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 750),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            _buildFilterBar(isDark),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView()
                      : _buildTableContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade700, Colors.orange.shade500],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Palmarès des Médicaments & Rentabilité',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  _startDate != null && _endDate != null
                      ? 'Période du ${_dateDisplayFmt.format(_startDate!)} au ${_dateDisplayFmt.format(_endDate!)} • Tous les comptes'
                      : 'Historique complet des ventes • Tous les comptes',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isDark ? const Color(0xFF151E2E) : const Color(0xFFF1F5F9),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Segmented button classement : Volume vs Rentabilité
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'quantity',
                label: Text('Plus vendus (Volume)'),
                icon: Icon(Icons.inventory_2, size: 16),
              ),
              ButtonSegment<String>(
                value: 'profit',
                label: Text("Plus rentables (Gain d'argent)"),
                icon: Icon(Icons.monetization_on, size: 16),
              ),
              ButtonSegment<String>(
                value: 'revenue',
                label: Text("Chiffre d'Affaires"),
                icon: Icon(Icons.trending_up, size: 16),
              ),
            ],
            selected: {_sortBy},
            onSelectionChanged: (newVal) {
              setState(() => _sortBy = newVal.first);
              _loadTopMedicines();
            },
          ),

          // Périodes
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildPresetChip('today', "Aujourd'hui"),
              _buildPresetChip('week', '7 jours'),
              _buildPresetChip('month', 'Ce mois'),
              _buildPresetChip('year', 'Année'),
              _buildPresetChip('all', 'Tout'),
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _selectedPreset == 'custom' && _startDate != null && _endDate != null
                          ? '${_dateDisplayFmt.format(_startDate!)} - ${_dateDisplayFmt.format(_endDate!)}'
                          : 'Dates...',
                    ),
                  ],
                ),
                selected: _selectedPreset == 'custom',
                onSelected: (_) => _pickCustomDateRange(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSelected = _selectedPreset == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) _setPreset(key);
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Erreur inconnue', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTopMedicines,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableContent(bool isDark) {
    if (_data == null) return const SizedBox.shrink();

    final summary = _data!['summary'] as Map<String, dynamic>? ?? {};
    final items = (_data!['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final totalQty = (summary['total_quantity_sold'] as num?)?.toInt() ?? 0;
    final totalRev = (summary['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalProfit = (summary['total_profit'] as num?)?.toDouble() ?? 0.0;
    final topQtyName = summary['top_quantity_name'] as String? ?? 'N/A';
    final topProfitName = summary['top_profit_name'] as String? ?? 'N/A';

    final maxQty = items.isNotEmpty ? (items.first['total_quantity'] as num?)?.toDouble() ?? 1.0 : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4 Cartes KPI
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  title: 'N°1 en Volume',
                  value: topQtyName,
                  subtitle: 'Médicament le plus distribué',
                  icon: Icons.inventory_2,
                  color: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  title: "N°1 en Gain d'Argent",
                  value: topProfitName,
                  subtitle: 'Plus grosse marge bénéficiaire',
                  icon: Icons.monetization_on,
                  color: Colors.amber.shade800,
                  bgColor: Colors.amber.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  title: "Chiffre d'Affaires Total",
                  value: '${_currencyFmt.format(totalRev)} FBu',
                  subtitle: '$totalQty unités vendues',
                  icon: Icons.payments,
                  color: Colors.indigo.shade700,
                  bgColor: Colors.indigo.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  title: 'Bénéfice Net Cumulé',
                  value: '${_currencyFmt.format(totalProfit)} FBu',
                  subtitle: totalRev > 0
                      ? 'Marge globale : ${((totalProfit / totalRev) * 100).toStringAsFixed(1)}%'
                      : 'Marge globale',
                  icon: Icons.savings,
                  color: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tableau de données
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('Aucune vente enregistrée sur cette période.'),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Rang', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Médicament', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Quantité Vendue', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text("Chiffre d'Affaires", style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text("Coût d'Achat", style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text("Bénéfice Net (Gain)", style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Marge %', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: items.map((item) {
                    final rank = item['rank'] as int? ?? 0;
                    final name = item['name'] as String? ?? 'N/A';
                    final forme = item['forme'] as String? ?? '';
                    final dosage = item['dosage'] as String? ?? '';
                    final code = item['code'] as String? ?? '';
                    final qty = (item['total_quantity'] as num?)?.toInt() ?? 0;
                    final rev = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;
                    final cost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
                    final profit = (item['total_profit'] as num?)?.toDouble() ?? 0.0;
                    final margin = (item['margin_percent'] as num?)?.toDouble() ?? 0.0;
                    final salesCount = (item['sales_count'] as num?)?.toInt() ?? 0;

                    final progress = maxQty > 0 ? (qty / maxQty).clamp(0.0, 1.0) : 0.0;

                    return DataRow(
                      cells: [
                        DataCell(_buildRankBadge(rank)),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                [if (forme.isNotEmpty) forme, if (dosage.isNotEmpty) dosage, if (code.isNotEmpty) '($code)']
                                    .join(' • '),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 50,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _sortBy == 'profit' ? Colors.amber.shade700 : AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$qty unités', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        DataCell(Text('${_currencyFmt.format(rev)} FBu', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('${_currencyFmt.format(cost)} FBu', style: TextStyle(color: Colors.grey.shade700))),
                        DataCell(
                          Text(
                            '${_currencyFmt.format(profit)} FBu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: profit >= 0 ? Colors.green.shade700 : Colors.red,
                            ),
                          ),
                        ),
                        DataCell(_buildMarginBadge(margin)),
                        DataCell(Text('$salesCount tickets')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color(0xFFFFD700),
        child: Text('🥇', style: TextStyle(fontSize: 12)),
      );
    }
    if (rank == 2) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color(0xFFC0C0C0),
        child: Text('🥈', style: TextStyle(fontSize: 12)),
      );
    }
    if (rank == 3) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color(0xFFCD7F32),
        child: Text('🥉', style: TextStyle(fontSize: 12)),
      );
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#$rank',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildMarginBadge(double margin) {
    Color color = Colors.grey;
    if (margin >= 30) {
      color = Colors.green.shade700;
    } else if (margin >= 15) {
      color = Colors.orange.shade700;
    } else if (margin > 0) {
      color = Colors.blue.shade700;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$margin%',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
