import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:frontend1/services/medicine_pricing_service.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Bouton d'en-tête ouvrant le Centre de Notifications avec tableaux scrollables
class NotificationsButton extends StatefulWidget {
  const NotificationsButton({super.key});

  @override
  State<NotificationsButton> createState() => _NotificationsButtonState();
}

class _NotificationsButtonState extends State<NotificationsButton> {
  final MedicinePricingService _service = MedicinePricingService();
  int _totalAlerts = 0;

  @override
  void initState() {
    super.initState();
    _loadAlertBadge();
  }

  Future<void> _loadAlertBadge() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = (prefs.getStringList('dismissed_alerts_keys') ?? []).toSet();

      final data = await _service.getAlerts();
      final expiring = ((data['expiring_soon'] as List<dynamic>?) ?? []).where((item) {
        final id = item['id'];
        final lot = item['lot'] ?? '';
        return !dismissed.contains('expiring_${id}_$lot');
      }).toList();

      final lowStock = ((data['low_stock'] as List<dynamic>?) ?? []).where((item) {
        final id = item['id'];
        final lot = item['lot'] ?? '';
        return !dismissed.contains('low_${id}_$lot');
      }).toList();

      final outOfStock = ((data['out_of_stock'] as List<dynamic>?) ?? []).where((item) {
        final id = item['id'];
        final lot = item['lot'] ?? '';
        return !dismissed.contains('rupture_${id}_$lot');
      }).toList();

      if (!mounted) return;
      setState(() {
        _totalAlerts = expiring.length + lowStock.length + outOfStock.length;
      });
    } catch (_) {
      // Ignored: badge will remain at current value
    }
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => NotificationsCenterDialog(
        onRefreshNeeded: _loadAlertBadge,
      ),
    ).then((_) => _loadAlertBadge());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            _totalAlerts > 0 ? Icons.notifications_active : Icons.notifications_outlined,
            size: 22,
            color: _totalAlerts > 0
                ? AppTheme.dangerColor
                : (isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText),
          ),
          tooltip: languageProvider.translate('notifications'),
          onPressed: () => _showNotificationsDialog(context),
        ),
        if (_totalAlerts > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _totalAlerts > 99 ? '99+' : '$_totalAlerts',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialogue plein écran / modale présentant les 3 tableaux scrollables
class NotificationsCenterDialog extends StatefulWidget {
  final VoidCallback onRefreshNeeded;

  const NotificationsCenterDialog({super.key, required this.onRefreshNeeded});

  @override
  State<NotificationsCenterDialog> createState() => _NotificationsCenterDialogState();
}

class _NotificationsCenterDialogState extends State<NotificationsCenterDialog> {
  final MedicinePricingService _service = MedicinePricingService();

  List<MedicinePricing> _expiringSoon = [];
  List<MedicinePricing> _lowStock = [];
  List<MedicinePricing> _outOfStock = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  final Set<String> _selectedAlertKeys = {};
  final Set<String> _dismissedAlertKeys = {};

  final ScrollController _scrollExpiringV = ScrollController();
  final ScrollController _scrollExpiringH = ScrollController();
  final ScrollController _scrollLowStockV = ScrollController();
  final ScrollController _scrollLowStockH = ScrollController();
  final ScrollController _scrollRuptureV = ScrollController();
  final ScrollController _scrollRuptureH = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void dispose() {
    _scrollExpiringV.dispose();
    _scrollExpiringH.dispose();
    _scrollLowStockV.dispose();
    _scrollLowStockH.dispose();
    _scrollRuptureV.dispose();
    _scrollRuptureH.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = (prefs.getStringList('dismissed_alerts_keys') ?? []).toSet();
      _dismissedAlertKeys.clear();
      _dismissedAlertKeys.addAll(dismissed);

      final data = await _service.getAlerts();
      final expiring = (data['expiring_soon'] as List<dynamic>?)
              ?.map((item) => MedicinePricing.fromJson(item as Map<String, dynamic>))
              .where((item) => !_dismissedAlertKeys.contains('expiring_${item.id}_${item.lot}'))
              .toList() ??
          [];
      final lowStock = (data['low_stock'] as List<dynamic>?)
              ?.map((item) => MedicinePricing.fromJson(item as Map<String, dynamic>))
              .where((item) => !_dismissedAlertKeys.contains('low_${item.id}_${item.lot}'))
              .toList() ??
          [];
      final outOfStock = (data['out_of_stock'] as List<dynamic>?)
              ?.map((item) => MedicinePricing.fromJson(item as Map<String, dynamic>))
              .where((item) => !_dismissedAlertKeys.contains('rupture_${item.id}_${item.lot}'))
              .toList() ??
          [];

      if (!mounted) return;
      setState(() {
        _expiringSoon = expiring;
        _lowStock = lowStock;
        _outOfStock = outOfStock;
        _isLoading = false;
        _selectedAlertKeys.removeWhere((k) =>
            !_expiringSoon.any((i) => 'expiring_${i.id}_${i.lot}' == k) &&
            !_lowStock.any((i) => 'low_${i.id}_${i.lot}' == k) &&
            !_outOfStock.any((i) => 'rupture_${i.id}_${i.lot}' == k));
      });
      widget.onRefreshNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger les alertes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _dismissNotifications(Set<String> keysToDismiss, String description) async {
    if (keysToDismiss.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Supprimer notification(s)"),
          ],
        ),
        content: Text(
          "Voulez-vous vraiment supprimer $description du centre de notifications ?\n(Cela n'efface pas les données de stock réelles).",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    _dismissedAlertKeys.addAll(keysToDismiss);
    await prefs.setStringList('dismissed_alerts_keys', _dismissedAlertKeys.toList());

    setState(() {
      _expiringSoon.removeWhere((item) => keysToDismiss.contains('expiring_${item.id}_${item.lot}'));
      _lowStock.removeWhere((item) => keysToDismiss.contains('low_${item.id}_${item.lot}'));
      _outOfStock.removeWhere((item) => keysToDismiss.contains('rupture_${item.id}_${item.lot}'));
      _selectedAlertKeys.removeAll(keysToDismiss);
    });

    widget.onRefreshNeeded();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${keysToDismiss.length} notification(s) supprimée(s)"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "Annuler",
            textColor: Colors.white,
            onPressed: () async {
              _dismissedAlertKeys.removeAll(keysToDismiss);
              await prefs.setStringList('dismissed_alerts_keys', _dismissedAlertKeys.toList());
              _loadAlerts();
            },
          ),
        ),
      );
    }
  }

  Future<void> _restoreAllDismissed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.blue),
            SizedBox(width: 8),
            Text("Restaurer les notifications"),
          ],
        ),
        content: Text(
          "Voulez-vous réafficher les ${_dismissedAlertKeys.length} alertes précédemment supprimées du centre de notifications ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Restaurer"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dismissed_alerts_keys');
    _dismissedAlertKeys.clear();
    _loadAlerts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Toutes les notifications ont été restaurées"),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  List<MedicinePricing> _filterList(List<MedicinePricing> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase().trim();
    return list.where((item) {
      final nom = item.nom.toLowerCase();
      final dci = item.dci?.toLowerCase() ?? '';
      final lot = item.lot.toLowerCase();
      return nom.contains(q) || dci.contains(q) || lot.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _expiringSoon.length + _lowStock.length + _outOfStock.length;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.user?.isAdmin == true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1100,
        height: 720,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              // Header
              _buildHeader(context, isDark, totalCount, isAdmin),
              const Divider(height: 1),

              // Search & Tab Bar
              _buildTabBarSection(isDark),

              // Selection Banner (if items are selected by Admin)
              if (isAdmin && _selectedAlertKeys.isNotEmpty) _buildSelectionBanner(isDark),

              // Content Area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Chargement des notifications en temps réel...'),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _loadAlerts,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          )
                        : TabBarView(
                            children: [
                              _buildExpiringTable(isDark, isAdmin),
                              _buildLowStockTable(isDark, isAdmin),
                              _buildRuptureTable(isDark, isAdmin),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBanner(bool isDark) {
    return Container(
      color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Text(
            "${_selectedAlertKeys.length} notification(s) sélectionnée(s)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.red.shade300 : Colors.red.shade800,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedAlertKeys.clear()),
            child: const Text("Tout désélectionner"),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
            label: Text(
              "Supprimer sélection (${_selectedAlertKeys.length})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _dismissNotifications(
              Set.from(_selectedAlertKeys),
              "${_selectedAlertKeys.length} notification(s)",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, int totalCount, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: totalCount > 0 ? Colors.red.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: totalCount > 0 ? Colors.red : AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Centre de Notifications & Alertes Stock',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: totalCount > 0 ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalCount active${totalCount > 1 ? "s" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Consultez les péremptions imminentes, les stocks faibles et les ruptures de stock.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (isAdmin && _dismissedAlertKeys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800,
                  side: BorderSide(color: Colors.blueGrey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.restore, size: 16),
                label: Text(
                  'Restaurer alertes (${_dismissedAlertKeys.length})',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: _restoreAllDismissed,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les alertes',
            onPressed: _loadAlerts,
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

  Widget _buildTabBarSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      color: isDark ? AppTheme.darkSidebarHover : AppTheme.lightSidebarHover,
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_bottom, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Péremption prochaine', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      _buildPillBadge(_expiringSoon.length, Colors.orange),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text('Stock Faible', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      _buildPillBadge(_lowStock.length, Colors.amber[800]!),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Rupture', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      _buildPillBadge(_outOfStock.length, Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Barre de filtre rapide
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtrer par nom ou lot...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  // 1. Tableau Pérémption prochaine (Scrollable verticalement et horizontalement)
  Widget _buildExpiringTable(bool isDark, bool isAdmin) {
    final filtered = _filterList(_expiringSoon);
    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'Aucun résultat pour "$_searchQuery"' : 'Aucun médicament proche de la péremption',
        Icons.check_circle_outline,
        Colors.green,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollExpiringV,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollExpiringV,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _scrollExpiringH,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: _scrollExpiringH,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: isAdmin,
                    onSelectAll: isAdmin
                        ? (selected) {
                            setState(() {
                              final keys = filtered.map((item) => 'expiring_${item.id}_${item.lot}');
                              if (selected == true) {
                                _selectedAlertKeys.addAll(keys);
                              } else {
                                _selectedAlertKeys.removeAll(keys);
                              }
                            });
                          }
                        : null,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    ),
                    columnSpacing: 24,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    columns: [
                      const DataColumn(label: Text('Médicament', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('DCI / Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Lot', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Date Péremption', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Échéance', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Stock Restant', style: TextStyle(fontWeight: FontWeight.bold))),
                      if (isAdmin)
                        const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filtered.map((item) {
                      final key = 'expiring_${item.id}_${item.lot}';
                      final isSelected = _selectedAlertKeys.contains(key);
                      final daysRemaining = item.datePeremption
                          ?.difference(DateTime.now())
                          .inDays;
                      final isExpired = daysRemaining != null && daysRemaining <= 0;

                      return DataRow(
                        selected: isAdmin && isSelected,
                        onSelectChanged: isAdmin
                            ? (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedAlertKeys.add(key);
                                  } else {
                                    _selectedAlertKeys.remove(key);
                                  }
                                });
                              }
                            : null,
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  isExpired ? Icons.cancel : Icons.access_time_filled,
                                  size: 16,
                                  color: isExpired ? Colors.red : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(item.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text(item.dci != null && item.dci!.isNotEmpty ? '${item.dci} (${item.dosage ?? ""})' : '-')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(item.lot, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.datePeremption != null
                                  ? DateFormat('dd/MM/yyyy').format(item.datePeremption!)
                                  : 'Inconnue',
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isExpired
                                     ? Colors.red.withValues(alpha: 0.15)
                                    : (daysRemaining != null && daysRemaining < 30
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isExpired
                                    ? 'EXPIRÉ'
                                    : (daysRemaining == 0
                                        ? "Expire aujourd'hui"
                                        : 'Dans $daysRemaining j'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isExpired ? Colors.red[800] : Colors.orange[900],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${item.totalComprimes} unités (${item.totalBoites} btes)',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (isAdmin)
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: "Supprimer cette notification",
                                onPressed: () => _dismissNotifications({key}, 'l\'alerte de péremption pour "${item.nom}"'),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 2. Tableau Stock Faible (Scrollable verticalement et horizontalement)
  Widget _buildLowStockTable(bool isDark, bool isAdmin) {
    final filtered = _filterList(_lowStock);
    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'Aucun résultat pour "$_searchQuery"' : 'Aucun médicament en stock faible',
        Icons.inventory_2_outlined,
        Colors.green,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollLowStockV,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollLowStockV,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _scrollLowStockH,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: _scrollLowStockH,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: isAdmin,
                    onSelectAll: isAdmin
                        ? (selected) {
                            setState(() {
                              final keys = filtered.map((item) => 'low_${item.id}_${item.lot}');
                              if (selected == true) {
                                _selectedAlertKeys.addAll(keys);
                              } else {
                                _selectedAlertKeys.removeAll(keys);
                              }
                            });
                          }
                        : null,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    ),
                    columnSpacing: 24,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    columns: [
                      const DataColumn(label: Text('Médicament', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('DCI / Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Lot', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Stock Actuel', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Seuil Alerte', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
                      if (isAdmin)
                        const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filtered.map((item) {
                      final key = 'low_${item.id}_${item.lot}';
                      final isSelected = _selectedAlertKeys.contains(key);

                      return DataRow(
                        selected: isAdmin && isSelected,
                        onSelectChanged: isAdmin
                            ? (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedAlertKeys.add(key);
                                  } else {
                                    _selectedAlertKeys.remove(key);
                                  }
                                });
                              }
                            : null,
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Text(item.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text(item.dci != null && item.dci!.isNotEmpty ? '${item.dci} (${item.dosage ?? ""})' : '-')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(item.lot, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${item.totalComprimes} unités',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          DataCell(Text('${item.seuilAlerte} unités')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Stock Faible',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber[900]),
                              ),
                            ),
                          ),
                          if (isAdmin)
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: "Supprimer cette notification",
                                onPressed: () => _dismissNotifications({key}, 'l\'alerte de stock faible pour "${item.nom}"'),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 3. Tableau Rupture (Scrollable verticalement et horizontalement)
  Widget _buildRuptureTable(bool isDark, bool isAdmin) {
    final filtered = _filterList(_outOfStock);
    if (filtered.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'Aucun résultat pour "$_searchQuery"' : 'Aucun médicament en rupture de stock !',
        Icons.verified_outlined,
        Colors.green,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollRuptureV,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollRuptureV,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _scrollRuptureH,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: _scrollRuptureH,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: isAdmin,
                    onSelectAll: isAdmin
                        ? (selected) {
                            setState(() {
                              final keys = filtered.map((item) => 'rupture_${item.id}_${item.lot}');
                              if (selected == true) {
                                _selectedAlertKeys.addAll(keys);
                              } else {
                                _selectedAlertKeys.removeAll(keys);
                              }
                            });
                          }
                        : null,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    ),
                    columnSpacing: 24,
                    dataRowMinHeight: 46,
                    dataRowMaxHeight: 52,
                    columns: [
                      const DataColumn(label: Text('Médicament', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('DCI / Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Dernier Lot', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Stock Actuel', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Seuil Requis', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold))),
                      if (isAdmin)
                        const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filtered.map((item) {
                      final key = 'rupture_${item.id}_${item.lot}';
                      final isSelected = _selectedAlertKeys.contains(key);

                      return DataRow(
                        selected: isAdmin && isSelected,
                        onSelectChanged: isAdmin
                            ? (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedAlertKeys.add(key);
                                  } else {
                                    _selectedAlertKeys.remove(key);
                                  }
                                });
                              }
                            : null,
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                const Icon(Icons.remove_circle, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(item.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text(item.dci != null && item.dci!.isNotEmpty ? '${item.dci} (${item.dosage ?? ""})' : '-')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(item.lot, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            ),
                          ),
                          DataCell(
                            const Text(
                              '0 unité (0 boîte)',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          DataCell(Text('${item.seuilAlerte} unités')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'RUPTURE TOTALE',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                              ),
                            ),
                          ),
                          if (isAdmin)
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: "Supprimer cette notification",
                                onPressed: () => _dismissNotifications({key}, 'l\'alerte de rupture pour "${item.nom}"'),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
