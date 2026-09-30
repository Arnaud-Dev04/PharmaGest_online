import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/services/pos_service.dart';

/// Fenêtre modale complète affichant le chiffre d'affaires et le bilan des ventes
/// selon une période choisie par l'utilisateur (Aujourd'hui, 7 jours, Ce mois, Personnalisé).
/// - Vendeur standard : voit son propre chiffre d'affaires et ses ventes.
/// - Administrateur : voit un tableau comparatif consolidé de TOUS les comptes vendeurs.
class UserSalesPerformanceDialog extends StatefulWidget {
  final int? initialUserId;

  const UserSalesPerformanceDialog({super.key, this.initialUserId});

  static Future<void> show(BuildContext context, {int? userId}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UserSalesPerformanceDialog(initialUserId: userId),
    );
  }

  @override
  State<UserSalesPerformanceDialog> createState() => _UserSalesPerformanceDialogState();
}

class _UserSalesPerformanceDialogState extends State<UserSalesPerformanceDialog> {
  final PosService _posService = PosService();
  final NumberFormat _currencyFmt = NumberFormat('#,###', 'fr_FR');
  final DateFormat _dateDisplayFmt = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeDisplayFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
  final DateFormat _apiDateFmt = DateFormat('yyyy-MM-dd');

  // Période sélectionnée
  String _selectedPreset = 'today'; // 'today', 'week', 'month', 'custom'
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  int? _selectedUserId;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.initialUserId;
    _setPreset('today');
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
      }
    });
    _loadSalesSummary();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSalesSummary();
    }
  }

  Future<void> _loadSalesSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sStr = _apiDateFmt.format(_startDate);
      final eStr = _apiDateFmt.format(_endDate);

      final res = await _posService.getUserSalesSummary(
        startDate: sStr,
        endDate: eStr,
        userId: _selectedUserId,
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isSuperAdmin = auth.user?.role.toLowerCase() == 'super_admin';
    final isAdmin = auth.user?.role.toLowerCase() == 'admin' || isSuperAdmin;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 950 ? 900.0 : screenWidth * 0.95;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark, isAdmin),
            _buildPeriodSelector(isDark),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView()
                      : _buildContent(isDark, isAdmin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isAdmin) {
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
              color: Colors.green.shade600.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.point_of_sale_rounded, color: Colors.green.shade700, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin && _selectedUserId == null
                      ? 'Performance des Ventes — Tous les Comptes'
                      : 'Bilan de Ventes par Période',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Du ${_dateDisplayFmt.format(_startDate)} au ${_dateDisplayFmt.format(_endDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (isAdmin && _selectedUserId != null)
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedUserId = null);
                _loadSalesSummary();
              },
              icon: const Icon(Icons.group, size: 16),
              label: const Text('Voir tous les comptes'),
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

  Widget _buildPeriodSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: isDark ? const Color(0xFF151E2E) : const Color(0xFFF1F5F9),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Période :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          _buildPresetChip('today', "Aujourd'hui"),
          _buildPresetChip('week', '7 derniers jours'),
          _buildPresetChip('month', 'Ce mois'),
          ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.date_range, size: 14),
                const SizedBox(width: 4),
                Text(
                  _selectedPreset == 'custom'
                      ? '${_dateDisplayFmt.format(_startDate)} - ${_dateDisplayFmt.format(_endDate)}'
                      : 'Personnalisée...',
                ),
              ],
            ),
            selected: _selectedPreset == 'custom',
            onSelected: (_) => _pickCustomDateRange(),
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
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
              onPressed: _loadSalesSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, bool isAdmin) {
    if (_data == null) return const SizedBox.shrink();

    final isAdminView = _data!['is_admin_view'] == true && _selectedUserId == null;

    if (isAdminView) {
      return _buildAdminAllAccountsView(isDark);
    } else {
      return _buildSingleUserView(isDark);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VUE ADMIN : TOUS LES COMPTES VENDEURS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminAllAccountsView(bool isDark) {
    final grandTotal = _data!['grand_total'] as Map<String, dynamic>? ?? {};
    final usersSummary = (_data!['users_summary'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final grandRevenue = (grandTotal['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final grandCount = (grandTotal['total_sales_count'] as num?)?.toInt() ?? 0;
    final grandAvg = (grandTotal['average_basket'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Cartes globales
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: "Chiffre d'Affaires Global",
                  value: '${_currencyFmt.format(grandRevenue)} FBu',
                  subtitle: 'Total de la pharmacie sur la période',
                  icon: Icons.payments_rounded,
                  color: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'Transactions Réalisées',
                  value: '$grandCount ventes',
                  subtitle: '${usersSummary.length} comptes actifs',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'Panier Moyen',
                  value: '${_currencyFmt.format(grandAvg)} FBu',
                  subtitle: 'Moyenne par ticket',
                  icon: Icons.shopping_basket_rounded,
                  color: Colors.orange.shade700,
                  bgColor: Colors.orange.shade50,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Titre section
          const Text(
            'Répartition des Ventes par Vendeur :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          // Tableau des utilisateurs
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
                columns: const [
                  DataColumn(label: Text('Vendeur / Utilisateur', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rôle', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Nb Ventes', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text("Chiffre d'Affaires", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Part (%)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(numeric: true, label: Text('Panier Moyen', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: usersSummary.map((u) {
                  final uId = u['user_id'] as int;
                  final uName = u['username'] as String? ?? 'N/A';
                  final uFullName = u['full_name'] as String? ?? uName;
                  final uRole = u['role'] as String? ?? '';
                  final count = (u['total_sales_count'] as num?)?.toInt() ?? 0;
                  final rev = (u['total_revenue'] as num?)?.toDouble() ?? 0.0;
                  final pct = (u['percentage_of_total'] as num?)?.toDouble() ?? 0.0;
                  final avg = (u['average_basket'] as num?)?.toDouble() ?? 0.0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: Text(
                                uName.isNotEmpty ? uName[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(uFullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('@$uName', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(_buildRoleBadge(uRole)),
                      DataCell(Text('$count', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(
                        Text(
                          '${_currencyFmt.format(rev)} FBu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: rev > 0 ? Colors.green.shade700 : Colors.grey,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 45,
                              child: LinearProgressIndicator(
                                value: (pct / 100).clamp(0.0, 1.0),
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('$pct%', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      DataCell(Text('${_currencyFmt.format(avg)} FBu')),
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() => _selectedUserId = uId);
                            _loadSalesSummary();
                          },
                          icon: const Icon(Icons.visibility, size: 14),
                          label: const Text('Détails'),
                        ),
                      ),
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

  // ══════════════════════════════════════════════════════════════════════════
  // VUE INDIVIDUELLE : VENDEUR UNIQUE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildSingleUserView(bool isDark) {
    final user = _data!['user'] as Map<String, dynamic>? ?? {};
    final summary = _data!['summary'] as Map<String, dynamic>? ?? {};
    final dailyList = (_data!['sales_by_day'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final recentSales = (_data!['recent_sales'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final rev = (summary['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final count = (summary['total_sales_count'] as num?)?.toInt() ?? 0;
    final avg = (summary['average_basket'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Carte résumé utilisateur
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    (user['username'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] as String? ?? user['username'] as String? ?? 'Utilisateur',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Compte : @${user['username']} • Rôle : ${user['role']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3 KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: "Chiffre d'Affaires Réalisé",
                  value: '${_currencyFmt.format(rev)} FBu',
                  subtitle: 'Total vendu sur la période',
                  icon: Icons.payments_rounded,
                  color: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'Nombre de Ventes',
                  value: '$count',
                  subtitle: 'Tickets enregistrés',
                  icon: Icons.receipt_long_rounded,
                  color: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'Panier Moyen',
                  value: '${_currencyFmt.format(avg)} FBu',
                  subtitle: 'Par vente',
                  icon: Icons.shopping_basket_rounded,
                  color: Colors.orange.shade700,
                  bgColor: Colors.orange.shade50,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Évolution quotidienne
          if (dailyList.isNotEmpty) ...[
            const Text(
              'Ventes par Jour :',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dailyList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = dailyList[i];
                  final d = item['date'] as String? ?? '';
                  final r = (item['revenue'] as num?)?.toDouble() ?? 0.0;
                  final c = (item['count'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.calendar_today, size: 16),
                    title: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$c vente(s)'),
                    trailing: Text(
                      '${_currencyFmt.format(r)} FBu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Liste des ventes récentes
          const Text(
            'Dernières Ventes Réalisées :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          if (recentSales.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('Aucune vente enregistrée sur cette période.'),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentSales.take(15).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = recentSales[i];
                  final code = s['code'] as String? ?? 'N/A';
                  final amt = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final dtStr = s['date'] as String?;
                  String formattedDate = 'N/A';
                  if (dtStr != null) {
                    try {
                      final dt = DateTime.parse(dtStr);
                      formattedDate = _dateTimeDisplayFmt.format(dt);
                    } catch (_) {}
                  }

                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
                    ),
                    title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(formattedDate),
                    trailing: Text(
                      '${_currencyFmt.format(amt)} FBu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 14,
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = Colors.grey;
    String label = role;
    if (role.toLowerCase() == 'super_admin') {
      color = Colors.purple;
      label = 'Super Admin';
    } else if (role.toLowerCase() == 'admin') {
      color = Colors.blue;
      label = 'Admin';
    } else if (role.toLowerCase() == 'pharmacist') {
      color = Colors.teal;
      label = 'Pharmacien';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
