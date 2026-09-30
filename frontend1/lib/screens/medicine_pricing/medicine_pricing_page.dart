import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:frontend1/services/medicine_pricing_service.dart';
import 'package:frontend1/services/prix_calculator.dart';
import 'package:frontend1/screens/stock/add_medicine_wizard.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/providers/inventory_provider.dart';
import 'package:frontend1/providers/cart_provider.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/widgets/stock/medicine_details_dialog.dart';
import 'package:frontend1/screens/stock/stock_audit_dialog.dart';

/// Page liste unifiée — Phase 2 : tri, filtres, groupement lots, sélecteur niveau
class MedicinePricingPage extends StatefulWidget {
  const MedicinePricingPage({super.key});
  @override
  State<MedicinePricingPage> createState() => _MedicinePricingPageState();
}

class _MedicinePricingPageState extends State<MedicinePricingPage> {
  final MedicinePricingService _service = MedicinePricingService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<MedicinePricing> _entries = [];
  int _currentPage = 1, _totalPages = 1, _totalItems = 0;
  bool _isLoading = false;
  String? _error;

  // Dashboard totals are provided by InventoryProvider

  // Niveau d'affichage sélectionné
  NiveauPrix _niveau = NiveauPrix.comprime;

  // Filtres
  bool _showFilters = false;
  bool _filterStockBas = false;
  bool _filterPerime = false;
  bool _filterExpire3Mois = false;

  // Tri
  String _sortBy = 'nom';
  bool _sortAsc = true;

  // Lots dépliés (par nom de médicament)
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _searchCtrl.addListener(() {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) { _currentPage = 1; _loadEntries(); }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user = Provider.of<AuthProvider>(context, listen: false).user;
        final role = user?.role.toLowerCase();
        final isAdmin = user?.isAdmin == true || role == 'pharmacien' || role == 'pharmacist';
        if (isAdmin) {
          Provider.of<InventoryProvider>(context, listen: false).loadTotals();
        }
      }
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadEntries() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await _service.getPricings(
        page: _currentPage,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );
      if (mounted) {
        setState(() {
          _entries = response.items;
          _totalPages = response.totalPages;
          _totalItems = response.total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = ErrorHelper.extractErrorMessage(e); _isLoading = false; });
    }
  }

  /// Regroupe les entrées par nom normalisé
  Map<String, List<MedicinePricing>> get _grouped {
    final map = <String, List<MedicinePricing>>{};
    for (final e in _filteredEntries) {
      final key = e.nom.trim().toLowerCase();
      map.putIfAbsent(key, () => []).add(e);
    }
    // Tri des groupes
    final sorted = map.entries.toList();
    sorted.sort((a, b) {
      switch (_sortBy) {
        case 'benefice':
          final ba = a.value.fold(0.0, (s, e) => s + e.beneficeEstime);
          final bb = b.value.fold(0.0, (s, e) => s + e.beneficeEstime);
          return _sortAsc ? ba.compareTo(bb) : bb.compareTo(ba);
        case 'stock':
          final sa = a.value.fold(0, (s, e) => s + e.totalComprimes);
          final sb = b.value.fold(0, (s, e) => s + e.totalComprimes);
          return _sortAsc ? sa.compareTo(sb) : sb.compareTo(sa);
        case 'date':
          final da = a.value.map((e) => e.datePeremption).whereType<DateTime>().fold<DateTime?>(null, (prev, d) => prev == null || d.isBefore(prev) ? d : prev);
          final db = b.value.map((e) => e.datePeremption).whereType<DateTime>().fold<DateTime?>(null, (prev, d) => prev == null || d.isBefore(prev) ? d : prev);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return _sortAsc ? da.compareTo(db) : db.compareTo(da);
        default: // nom
          return _sortAsc ? a.key.compareTo(b.key) : b.key.compareTo(a.key);
      }
    });
    return Map.fromEntries(sorted);
  }

  List<MedicinePricing> get _filteredEntries {
    return _entries.where((e) {
      if (_filterStockBas && e.totalComprimes >= e.seuilAlerte) return false;
      if (_filterPerime && !PrixCalculator.estPerime(e)) return false;
      if (_filterExpire3Mois && !PrixCalculator.expireDans(e, 90)) return false;
      return true;
    }).toList();
  }

  Future<void> _openForm({MedicinePricing? entry}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddMedicineWizard(existing: entry),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
    );
    if (result == true) {
      _loadEntries();
      // Refresh inventory totals after adding a new pricing entry
      try { Provider.of<InventoryProvider>(context, listen: false).loadTotals(); } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Médicament enregistré avec succès !'),
          ]),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  Future<void> _deleteEntry(MedicinePricing entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer "${entry.nom}" (Lot: ${entry.lot}) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _service.deletePricing(entry.id);
        _loadEntries();
        if (!mounted) return;
        // Actualiser immédiatement les valeurs achats et ventes
        try {
          Provider.of<InventoryProvider>(context, listen: false).loadTotals();
        } catch (_) {}
        // Notifier le POS pour actualiser instantanément son affichage
        try {
          Provider.of<CartProvider>(context, listen: false).notifySaleCompleted();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrée supprimée')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.dangerColor));
      }
    }
  }

  void _openDetails(MedicinePricing entry) {
    showDialog(
      context: context,
      builder: (context) => MedicineDetailsDialog(
        medicine: Medicine(
          id: entry.medicineId ?? entry.id,
          code: entry.id.toString(),
          name: entry.nom,
          dosageForm: entry.forme,
          packaging: entry.forme,
          boxesPerCarton: entry.boitesParCarton,
          blistersPerBox: entry.plaquettesParBoite,
          unitsPerBlister: entry.comprimesParPlaquette,
          unitsPerPackaging: entry.totalComprimes,
          priceBuy: entry.achatBoite,
          priceSell: entry.venteBoite,
          prixAchatUnite: entry.achatComprime,
          prixVenteUnite: entry.venteComprime,
          prixAchatPlaquette: entry.achatPlaquette,
          prixVentePlaquette: entry.ventePlaquette,
          prixAchatBoite: entry.achatBoite,
          prixVenteBoite: entry.venteBoite,
          prixAchatCarton: entry.achatCarton,
          prixVenteCarton: entry.venteCarton,
          quantity: entry.totalComprimes,
          expiryDate: entry.datePeremption,
          dci: entry.dci,
          formeGalenique: entry.forme,
          fournisseur: entry.fournisseur,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        onEdit: () {
          Navigator.of(context).pop();
          _openForm(entry: entry);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final role = user?.role.toLowerCase();
    final isAdmin = user?.isAdmin == true || role == 'pharmacien' || role == 'pharmacist';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuperAdmin = user?.isAdmin == true;

    if (!isAdmin && _sortBy == 'benefice') {
      _sortBy = 'nom';
    }

    return Column(children: [
      _buildHeader(isAdmin, isSuperAdmin),
      const SizedBox(height: 12),
      _buildToolbar(isAdmin, isSuperAdmin, isDark),
      if (_showFilters) _buildFilterPanel(isDark),
      const SizedBox(height: 8),
      Expanded(child: _buildContent(isAdmin, isSuperAdmin, isDark)),
    ]);
  }

  // ==================== HEADER ====================
  Widget _buildHeader(bool isAdmin, bool isSuperAdmin) {
    final inv = Provider.of<InventoryProvider>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Médicaments', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$_totalItems entrées • Niveau: ${PrixCalculator.niveauLabel(_niveau)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText)),
          if (isSuperAdmin) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Text('Valeur achat: ${PrixCalculator.fmtFBu(inv.totalPurchaseValue)}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              Text('Valeur vente: ${PrixCalculator.fmtFBu(inv.totalSellValue)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isSuperAdmin)
              OutlinedButton.icon(
                onPressed: () => StockAuditDialog.show(context),
                icon: const Icon(Icons.history_edu, size: 18),
                label: const Text("Journal d'Audit"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ElevatedButton.icon(onPressed: () => _openForm(), icon: const Icon(Icons.add), label: const Text('Nouveau')),
          ],
        ),
      ],
    );
  }

  // ==================== TOOLBAR ====================
  Widget _buildToolbar(bool isAdmin, bool isSuperAdmin, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          Row(children: [
            // Search
            Expanded(child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom, lot, DCI, fournisseur...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none, contentPadding: EdgeInsets.zero,
              ),
            )),
            if (isSuperAdmin) ...[
              const SizedBox(width: 8),
              // Journal d'Audit (Admin uniquement)
              IconButton(
                onPressed: () => StockAuditDialog.show(context),
                icon: const Icon(Icons.history_edu),
                tooltip: "Journal d'Audit",
                color: Colors.blueGrey,
              ),
            ],
            const SizedBox(width: 8),
            // Filter toggle
            IconButton(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
              tooltip: 'Filtres',
              color: _showFilters ? AppTheme.primaryColor : null,
            ),
          ]),
          const SizedBox(height: 8),
          // Niveau selector + Sort
          Row(children: [
            // Niveau
            Expanded(child: SegmentedButton<NiveauPrix>(
              segments: NiveauPrix.values.map((n) => ButtonSegment(
                value: n, label: Text(PrixCalculator.niveauLabel(n), style: const TextStyle(fontSize: 11)),
              )).toList(),
              selected: {_niveau},
              onSelectionChanged: (s) => setState(() => _niveau = s.first),
              showSelectedIcon: false,
              style: ButtonStyle(padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 4))),
            )),
            const SizedBox(width: 12),
            // Sort dropdown
            DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              isDense: true,
              items: [
                const DropdownMenuItem(value: 'nom', child: Text('Tri: Nom')),
                if (isAdmin) const DropdownMenuItem(value: 'benefice', child: Text('Tri: Bénéfice')),
                const DropdownMenuItem(value: 'stock', child: Text('Tri: Stock')),
                const DropdownMenuItem(value: 'date', child: Text('Tri: Expiration')),
              ],
              onChanged: (v) { if (v != null) setState(() => _sortBy = v); },
            ),
            IconButton(
              onPressed: () => setState(() => _sortAsc = !_sortAsc),
              icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
              tooltip: _sortAsc ? 'Ascendant' : 'Descendant',
            ),
          ]),
        ]),
      ),
    );
  }

  // ==================== FILTER PANEL ====================
  Widget _buildFilterPanel(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(spacing: 12, children: [
          FilterChip(label: const Text('Stock bas'), selected: _filterStockBas,
            onSelected: (v) => setState(() => _filterStockBas = v)),
          FilterChip(label: const Text('Périmé'), selected: _filterPerime,
            onSelected: (v) => setState(() => _filterPerime = v)),
          FilterChip(label: const Text('Expire < 3 mois'), selected: _filterExpire3Mois,
            onSelected: (v) => setState(() => _filterExpire3Mois = v)),
        ]),
      ),
    );
  }

  // ==================== CONTENT ====================
  Widget _buildContent(bool isAdmin, bool isSuperAdmin, bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: AppTheme.dangerColor),
      const SizedBox(height: 16), const Text('Erreur de chargement'),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _loadEntries, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
    ]));
    if (_entries.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.price_change, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
      const SizedBox(height: 16), const Text('Aucune entrée de prix'),
      const SizedBox(height: 8), Text('Cliquez sur "Nouveau" pour commencer', style: Theme.of(context).textTheme.bodySmall),
    ]));

    return Card(child: Column(children: [
      // ─── EN-TÊTES DE COLONNES (FIXES) ───
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          border: Border(
            bottom: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        ),
        child: Row(children: [
          // Expand icon + N° space
          const SizedBox(width: 54),
          // Nom
          Expanded(flex: 3, child: Text('NOM DU MÉDICAMENT',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor))),
          // Date exp
          Expanded(flex: 2, child: Text('DATE D\'EXPIRATION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor))),
          // Qté (avec le niveau sélectionné)
          Expanded(flex: 1, child: Text('QTÉ (${PrixCalculator.niveauLabel(_niveau).toUpperCase()})',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor))),
          // PA
          Expanded(flex: 1, child: Text('PRIX ACHAT',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor))),
          // PV
          Expanded(flex: 1, child: Text('PRIX VENTE',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor))),
          if (isAdmin)
            Expanded(flex: 1, child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('BÉNÉFICE',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor)),
            )),
          // Statut
          SizedBox(width: 120, child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('STATUT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor)),
          )),
          // Actions
          if (isAdmin) SizedBox(width: isSuperAdmin ? 140 : 105, child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('ACTIONS',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.primaryColor)),
          )),
        ]),
      ),
      Expanded(child: _buildGroupedList(isAdmin, isSuperAdmin, isDark)),
      if (_totalItems > 0) _buildPagination(),
    ]));
  }

  // ==================== GROUPED LIST ====================
  Widget _buildGroupedList(bool isAdmin, bool isSuperAdmin, bool isDark) {
    final groups = _grouped;
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      itemBuilder: (context, index) {
        final name = groups.keys.elementAt(index);
        final lots = groups[name]!;
        final displayName = lots.first.nom;
        final isExpanded = _expandedGroups.contains(name);
        final totalBenefice = lots.fold(0.0, (s, e) => s + e.beneficeEstime);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Group header row
          InkWell(
            onTap: lots.length > 1 ? () => setState(() {
              isExpanded ? _expandedGroups.remove(name) : _expandedGroups.add(name);
            }) : () => _openDetails(lots.first),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                // Expand icon
                if (lots.length > 1)
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
                if (lots.length > 1) const SizedBox(width: 4),
                // N°
                SizedBox(width: 30, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                // Name + badges
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    if (lots.length > 1) ...[
                      const SizedBox(width: 6),
                      _badge('${lots.length} lots', Colors.deepPurple),
                    ],
                  ]),
                  if (lots.first.forme != null || lots.first.dci != null)
                    Text([lots.first.forme, lots.first.dci].whereType<String>().join(' • '),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ])),
                // Date exp (earliest)
                Expanded(flex: 2, child: _buildExpiryCell(lots)),
                // Qté au niveau sélectionné
                Expanded(flex: 1, child: _buildQtyCell(lots, _niveau, isAdmin)),
                // PA
                Expanded(flex: 1, child: Text(
                  PrixCalculator.fmtFBu(PrixCalculator.prixAchatAuNiveau(lots.first, _niveau)),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12),
                )),
                // PV
                Expanded(flex: 1, child: Text(
                  PrixCalculator.fmtFBu(PrixCalculator.prixVenteAuNiveau(lots.first, _niveau)),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                )),
                if (isAdmin)
                  Expanded(flex: 1, child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      PrixCalculator.fmtFBu(totalBenefice),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: totalBenefice >= 0 ? AppTheme.successColor : AppTheme.dangerColor),
                    ),
                  )),
                // Statut
                SizedBox(width: 120, child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildGroupBadges(lots),
                )),
                // Actions
                if (isAdmin && lots.length == 1) SizedBox(width: isSuperAdmin ? 140 : 105, child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end, children: [
                      IconButton(
                        onPressed: () => _openDetails(lots.first),
                        icon: const Icon(Icons.info_outline, size: 16),
                        color: AppTheme.primaryColor,
                        tooltip: 'Détails & Diagnostic POS',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        iconSize: 16,
                      ),
                      if (isSuperAdmin)
                        IconButton(
                          onPressed: () => StockAuditDialog.show(
                            context,
                            medicineId: lots.first.medicineId ?? lots.first.id,
                            medicineName: lots.first.nom,
                          ),
                          icon: const Icon(Icons.history_edu, size: 16),
                          color: Colors.blueGrey,
                          tooltip: 'Historique des modifications',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          iconSize: 16,
                        ),
                      IconButton(
                        onPressed: () => _openForm(entry: lots.first),
                        icon: const Icon(Icons.edit, size: 16),
                        color: AppTheme.primaryColor,
                        tooltip: 'Modifier',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        iconSize: 16,
                      ),
                      IconButton(
                        onPressed: () => _deleteEntry(lots.first),
                        icon: const Icon(Icons.delete, size: 16),
                        color: AppTheme.dangerColor,
                        tooltip: 'Supprimer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        iconSize: 16,
                      ),
                    ],
                  ),
                )),
                if (isAdmin && lots.length > 1) SizedBox(width: isSuperAdmin ? 140 : 105, child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _openDetails(lots.first),
                        icon: const Icon(Icons.info_outline, size: 16),
                        color: AppTheme.primaryColor,
                        tooltip: 'Détails & Diagnostic POS',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        iconSize: 16,
                      ),
                      if (isSuperAdmin)
                        IconButton(
                          onPressed: () => StockAuditDialog.show(
                            context,
                            medicineId: lots.first.medicineId ?? lots.first.id,
                            medicineName: lots.first.nom,
                          ),
                          icon: const Icon(Icons.history_edu, size: 16),
                          color: Colors.blueGrey,
                          tooltip: 'Historique des modifications',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          iconSize: 16,
                        ),
                    ],
                  ),
                )),
              ]),
            ),
          ),
          // Expanded lot rows
          if (isExpanded && lots.length > 1)
            ...lots.map((e) => _buildLotRow(e, isAdmin, isSuperAdmin, isDark)),
        ]);
      },
    );
  }

  // ==================== LOT ROW (sub-row) ====================
  Widget _buildLotRow(MedicinePricing e, bool isAdmin, bool isSuperAdmin, bool isDark) {
    final df = DateFormat('dd/MM/yy');
    return Container(
      color: isDark ? AppTheme.darkInput.withValues(alpha: 0.3) : const Color(0xFFF5F6FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        const SizedBox(width: 54), // indent
        Expanded(flex: 3, child: Row(children: [
          Text('↳ ', style: TextStyle(color: Colors.grey[500])),
          Text('Lot: ${e.lot}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          if (e.fournisseur != null) Text(' • ${e.fournisseur}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
        Expanded(flex: 2, child: Text(
          e.datePeremption != null ? df.format(e.datePeremption!) : '-',
          style: TextStyle(fontSize: 11, color: _expiryColor(e)),
        )),
        Expanded(flex: 1, child: _buildQtyCellEntry(e, _niveau, isAdmin)),
        Expanded(flex: 1, child: Text(PrixCalculator.fmtFBu(PrixCalculator.prixAchatAuNiveau(e, _niveau)), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
        Expanded(flex: 1, child: Text(PrixCalculator.fmtFBu(PrixCalculator.prixVenteAuNiveau(e, _niveau)), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
        if (isAdmin)
          Expanded(flex: 1, child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(PrixCalculator.fmtFBu(e.beneficeEstime), textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: e.beneficeEstime >= 0 ? AppTheme.successColor : AppTheme.dangerColor)),
          )),
        SizedBox(width: 120, child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _buildEntryBadges(e),
        )),
        if (isAdmin) SizedBox(width: isSuperAdmin ? 140 : 105, child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (isSuperAdmin)
              IconButton(
                onPressed: () => StockAuditDialog.show(
                  context,
                  medicineId: e.medicineId ?? e.id,
                  medicineName: '${e.nom} (Lot ${e.lot})',
                ),
                icon: const Icon(Icons.history_edu, size: 14),
                color: Colors.blueGrey,
                tooltip: 'Historique des modifications',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 14,
              ),
            IconButton(
              onPressed: () => _openForm(entry: e),
              icon: const Icon(Icons.edit, size: 14),
              color: AppTheme.primaryColor,
              tooltip: 'Modifier',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              iconSize: 14,
            ),
            IconButton(
              onPressed: () => _deleteEntry(e),
              icon: const Icon(Icons.delete, size: 14),
              color: AppTheme.dangerColor,
              tooltip: 'Supprimer',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              iconSize: 14,
            ),
          ]),
        )),
      ]),
    );
  }


  // ==================== HELPERS ====================
  /// Formate la quantité totale d'un groupe de lots au niveau sélectionné
  String _fmtQteNiveau(List<MedicinePricing> lots, NiveauPrix niveau) {
    final totalComprimes = lots.fold(0, (s, e) => s + e.totalComprimes);
    if (lots.isEmpty || totalComprimes <= 0) return '0 u. (RUPTURE)';
    // Utiliser le premier lot pour les ratios de conditionnement
    final ref = lots.first;
    final qte = PrixCalculator.qteAuNiveau(ref, niveau);
    // Pour les groupes multi-lots, recalculer en sommant
    if (lots.length > 1) {
      final total = lots.fold(0.0, (s, e) => s + PrixCalculator.qteAuNiveau(e, niveau));
      final suffix = _niveauSuffix(niveau);
      return total == total.roundToDouble()
          ? '${total.toInt()} $suffix'
          : '${total.toStringAsFixed(1)} $suffix';
    }
    final suffix = _niveauSuffix(niveau);
    return qte == qte.roundToDouble()
        ? '${qte.toInt()} $suffix'
        : '${qte.toStringAsFixed(1)} $suffix';
  }

  /// Formate la quantité d'une seule entrée au niveau sélectionné
  String _fmtQteEntry(MedicinePricing e, NiveauPrix niveau) {
    if (e.totalComprimes <= 0) return '0 u. (RUPTURE)';
    final qte = PrixCalculator.qteAuNiveau(e, niveau);
    final suffix = _niveauSuffix(niveau);
    return qte == qte.roundToDouble()
        ? '${qte.toInt()} $suffix'
        : '${qte.toStringAsFixed(1)} $suffix';
  }

  /// Suffixe abrégé pour le niveau
  String _niveauSuffix(NiveauPrix niveau) {
    switch (niveau) {
      case NiveauPrix.comprime: return 'u.';
      case NiveauPrix.plaquette: return 'plq.';
      case NiveauPrix.boite: return 'bte.';
      case NiveauPrix.carton: return 'crt.';
    }
  }

  Widget _buildQtyCell(List<MedicinePricing> lots, NiveauPrix niveau, bool isAdmin) {
    final selectedText = _fmtQteNiveau(lots, niveau);
    if (!isAdmin) {
      return Text(selectedText, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12));
    }

    final totalCartons = lots.fold(0.0, (s, e) => s + PrixCalculator.qteAuNiveau(e, NiveauPrix.carton));
    final totalBoites = lots.fold(0.0, (s, e) => s + PrixCalculator.qteAuNiveau(e, NiveauPrix.boite));
    final totalPlaquettes = lots.fold(0.0, (s, e) => s + PrixCalculator.qteAuNiveau(e, NiveauPrix.plaquette));
    final totalUnites = lots.fold(0.0, (s, e) => s + PrixCalculator.qteAuNiveau(e, NiveauPrix.comprime));

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(selectedText, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
      const SizedBox(height: 2),
      Text(
        'CRT ${_fmtQty(totalCartons)} • BTE ${_fmtQty(totalBoites)} • PLQ ${_fmtQty(totalPlaquettes)} • U ${_fmtQty(totalUnites)}',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8)),
      ),
    ]);
  }

  Widget _buildQtyCellEntry(MedicinePricing e, NiveauPrix niveau, bool isAdmin) {
    final selectedText = _fmtQteEntry(e, niveau);
    if (!isAdmin) {
      return Text(selectedText, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11));
    }

    final carton = PrixCalculator.qteAuNiveau(e, NiveauPrix.carton);
    final boite = PrixCalculator.qteAuNiveau(e, NiveauPrix.boite);
    final plaquette = PrixCalculator.qteAuNiveau(e, NiveauPrix.plaquette);
    final unite = PrixCalculator.qteAuNiveau(e, NiveauPrix.comprime);

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(selectedText, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
      const SizedBox(height: 2),
      Text(
        'CRT ${_fmtQty(carton)} • BTE ${_fmtQty(boite)} • PLQ ${_fmtQty(plaquette)} • U ${_fmtQty(unite)}',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 9, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75)),
      ),
    ]);
  }

  String _fmtQty(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  Widget _buildExpiryCell(List<MedicinePricing> lots) {
    final df = DateFormat('dd/MM/yy');
    final earliest = lots
        .where((e) => e.datePeremption != null)
        .fold<DateTime?>(null, (prev, e) => prev == null || e.datePeremption!.isBefore(prev) ? e.datePeremption : prev);
    if (earliest == null) return const Text('-', style: TextStyle(fontSize: 12));
    final daysLeft = earliest.difference(DateTime.now()).inDays;
    Color c = daysLeft <= 0 ? AppTheme.dangerColor : (daysLeft <= 90 ? AppTheme.warningColor : AppTheme.successColor);
    String icon = daysLeft <= 0 ? '🔴' : (daysLeft <= 90 ? '🟡' : '🟢');
    return Text('$icon ${df.format(earliest)}', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w500));
  }

  Color _expiryColor(MedicinePricing e) {
    if (PrixCalculator.estPerime(e)) return AppTheme.dangerColor;
    if (PrixCalculator.expireDans(e, 90)) return AppTheme.warningColor;
    return AppTheme.successColor;
  }

  Widget _buildGroupBadges(List<MedicinePricing> lots) {
    final badges = <Widget>[];
    final anyExpired = lots.any((e) => PrixCalculator.estPerime(e));
    final anyExpiring = lots.any((e) => PrixCalculator.expireDans(e, 90));
    final anyLowStock = lots.any((e) => e.totalComprimes < e.seuilAlerte && e.totalComprimes > 0);
    final anyRupture = lots.any((e) => e.totalComprimes <= 0);

    if (anyExpired) badges.add(_badge('PÉRIMÉ', AppTheme.dangerColor));
    if (anyExpiring) badges.add(_badge('EXP.3M', AppTheme.warningColor));
    if (anyRupture) badges.add(_badge('RUPTURE', AppTheme.dangerColor));
    else if (anyLowStock) badges.add(_badge('STOCK↓', Colors.orange));
    if (badges.isEmpty) badges.add(_badge('OK', AppTheme.successColor));
    return Wrap(spacing: 4, runSpacing: 2, children: badges);
  }

  Widget _buildEntryBadges(MedicinePricing e) {
    final badges = <Widget>[];
    if (PrixCalculator.estPerime(e)) badges.add(_badge('PÉRIMÉ', AppTheme.dangerColor));
    else if (PrixCalculator.expireDans(e, 90)) badges.add(_badge('EXP.3M', AppTheme.warningColor));
    if (e.totalComprimes <= 0) badges.add(_badge('RUPTURE', AppTheme.dangerColor));
    else if (e.totalComprimes < e.seuilAlerte) badges.add(_badge('STOCK↓', Colors.orange));
    if (badges.isEmpty) badges.add(_badge('OK', AppTheme.successColor));
    return Wrap(spacing: 4, runSpacing: 2, children: badges);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total: $_totalItems entrées'),
        Row(children: [
          IconButton(
            onPressed: _currentPage > 1 ? () { setState(() => _currentPage--); _loadEntries(); } : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page $_currentPage / $_totalPages'),
          IconButton(
            onPressed: _currentPage < _totalPages ? () { setState(() => _currentPage++); _loadEntries(); } : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      ]),
    );
  }
}
