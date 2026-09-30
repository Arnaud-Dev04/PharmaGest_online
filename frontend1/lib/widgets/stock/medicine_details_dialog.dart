import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/models/medicine_pricing.dart';
import 'package:frontend1/services/pos_service.dart';
import 'package:frontend1/services/medicine_pricing_service.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/providers/auth_provider.dart';

/// Dialogue complet affichant les détails d'un médicament et l'état exact de ses lots
/// Permet de comprendre instantanément pourquoi une quantité apparaît dans le stock ou dans le POS
class MedicineDetailsDialog extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback? onEdit;

  const MedicineDetailsDialog({
    super.key,
    required this.medicine,
    this.onEdit,
  });

  @override
  State<MedicineDetailsDialog> createState() => _MedicineDetailsDialogState();
}

class _MedicineDetailsDialogState extends State<MedicineDetailsDialog> {
  final PosService _posService = PosService();
  final MedicinePricingService _pricingService = MedicinePricingService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _batches = [];
  MedicinePricing? _latestPricing;
  List<Map<String, dynamic>> _auditLogs = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _posService.getBatches(widget.medicine.id, includeEmpty: true),
        _pricingService.getPricings(search: widget.medicine.name, pageSize: 15),
        _posService.getMedicineAuditLogs(widget.medicine.id),
      ]);

      final batchesList = futures[0] as List<Map<String, dynamic>>;
      final pricingRes = futures[1] as dynamic;
      final auditList = futures[2] as List<Map<String, dynamic>>;

      MedicinePricing? matchedPricing;
      if (pricingRes != null && pricingRes.items != null) {
        final items = pricingRes.items as List<MedicinePricing>;
        final found = items.where((p) =>
            p.medicineId == widget.medicine.id ||
            p.nom.trim().toLowerCase() == widget.medicine.name.trim().toLowerCase()).toList();
        if (found.isNotEmpty) {
          matchedPricing = found.first;
        }
      }

      if (mounted) {
        setState(() {
          _batches = batchesList;
          _latestPricing = matchedPricing;
          _auditLogs = auditList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHelper.extractErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final med = widget.medicine;
    final isStrictAdmin = Provider.of<AuthProvider>(context, listen: false).user?.isAdmin == true;

    // Calculs de stocks
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    double totalPosStock = 0.0;
    double expiredStock = 0.0;
    int activeBatchCount = 0;

    for (final b in _batches) {
      final qty = (b['quantity'] as num?)?.toDouble() ?? 0.0;
      final isActive = b['is_active'] == true;
      final expStr = b['expiration_date'] as String?;
      DateTime? expDate;
      if (expStr != null && expStr.isNotEmpty) {
        try {
          expDate = DateTime.parse(expStr);
        } catch (_) {}
      }

      final isExpired = expDate != null && expDate.isBefore(todayDate);

      if (isActive && qty > 0) {
        if (!isExpired) {
          totalPosStock += qty;
          activeBatchCount++;
        } else {
          expiredStock += qty;
        }
      }
    }

    final stockMagasin = med.quantity.toDouble();
    final isSynchronized = (stockMagasin == totalPosStock);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── En-tête ──
            _buildHeader(isDark, med),

            // ── Onglets de Navigation Rapide (Admin uniquement) ──
            if (isStrictAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.dashboard_outlined, size: 16),
                      label: const Text('Diagnostic & Lots'),
                      selected: _selectedTab == 0,
                      onSelected: (v) => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      avatar: const Icon(Icons.history_edu, size: 16),
                      label: Text(
                        'Historique & Traçabilité (${_auditLogs.length})',
                        style: TextStyle(
                          fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedTab == 1,
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      onSelected: (v) => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
              ),

            // ── Corps Scrollable ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: (isStrictAdmin && _selectedTab == 1)
                              ? _buildAuditHistorySection(isDark)
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Diagnostic comparatif des stocks
                                    _buildStockDiagnosticCard(
                                      isDark: isDark,
                                      stockMagasin: stockMagasin,
                                      stockPos: totalPosStock,
                                      expiredStock: expiredStock,
                                      isSynchronized: isSynchronized,
                                      activeBatchCount: activeBatchCount,
                                    ),
                                    const SizedBox(height: 20),

                                    // Tableau détaillé des Lots
                                    _buildBatchesSection(isDark, todayDate),
                                    const SizedBox(height: 20),

                                    // Conditionnement & Tarifs
                                    _buildPricingAndPackagingSection(isDark, med),
                                    if (isStrictAdmin) ...[
                                      const SizedBox(height: 20),
                                      // Historique des modifications & Traçabilité
                                      _buildAuditHistorySection(isDark),
                                    ],
                                  ],
                                ),
                        ),
            ),


            // ── Bas de page (Actions) ──
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Medicine med) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 18, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        med.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (med.code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          med.code,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (med.dci != null && med.dci!.isNotEmpty) 'DCI: ${med.dci}',
                    if (med.formeGalenique != null && med.formeGalenique!.isNotEmpty) med.formeGalenique,
                    if (med.dosageForm != null && med.dosageForm != med.formeGalenique) med.dosageForm,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildStockDiagnosticCard({
    required bool isDark,
    required double stockMagasin,
    required double stockPos,
    required double expiredStock,
    required bool isSynchronized,
    required int activeBatchCount,
  }) {
    final statusColor = isSynchronized ? AppTheme.successColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSynchronized ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isSynchronized
                    ? 'Stock Magasin & Caisse POS parfaitement synchronisés'
                    : 'Information : Différence détectée entre Magasin et POS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Blocs métriques côte à côte
          Row(
            children: [
              // 1. Stock Fiche Magasin
              Expanded(
                child: _metricCard(
                  title: 'Stock Total Fiche',
                  subtitle: 'Gestion de Stock',
                  value: '${stockMagasin.toInt()} u.',
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),

              // 2. Stock Disponible POS
              Expanded(
                child: _metricCard(
                  title: 'Stock Disponible POS',
                  subtitle: 'En caisse ($activeBatchCount lot${activeBatchCount > 1 ? 's' : ''})',
                  value: '${stockPos.toInt()} u.',
                  icon: Icons.point_of_sale_rounded,
                  color: AppTheme.successColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),

              // 3. Lots exclus / expirés
              Expanded(
                child: _metricCard(
                  title: 'Exclu du POS',
                  subtitle: expiredStock > 0 ? 'Expiré / non vendable' : 'Aucune exclusion',
                  value: expiredStock > 0 ? '${expiredStock.toInt()} u.' : '0 u.',
                  icon: Icons.warning_amber_rounded,
                  color: expiredStock > 0 ? AppTheme.dangerColor : Colors.grey,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          if (!isSynchronized) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expiredStock > 0
                          ? 'Le POS ignore les lots dont la date de péremption est dépassée (${expiredStock.toInt()} unités dans ce cas).'
                          : 'Le stock disponible en caisse est calculé selon la somme des lots actifs.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500]),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesSection(bool isDark, DateTime todayDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Lots enregistrés (Traçabilité FEFO)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_batches.length} lot${_batches.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_batches.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.1) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Aucun lot enregistré pour ce médicament.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.1) : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _batches.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
              itemBuilder: (ctx, idx) {
                final b = _batches[idx];
                final batchNum = b['batch_number'] ?? 'Sans numéro';
                final qty = (b['quantity'] as num?)?.toDouble() ?? 0.0;
                final purchasePrice = (b['purchase_price'] as num?)?.toDouble() ?? 0.0;
                final isActive = b['is_active'] == true;

                final expStr = b['expiration_date'] as String?;
                DateTime? expDate;
                if (expStr != null && expStr.isNotEmpty) {
                  try {
                    expDate = DateTime.parse(expStr);
                  } catch (_) {}
                }

                final isExpired = expDate != null && expDate.isBefore(todayDate);
                final daysLeft = expDate != null ? expDate.difference(todayDate).inDays : null;

                // Statut visuel du lot
                Color badgeColor;
                String badgeText;
                IconData badgeIcon;

                if (!isActive || qty <= 0) {
                  badgeColor = Colors.grey;
                  badgeText = 'Épuisé (0 u)';
                  badgeIcon = Icons.remove_circle_outline;
                } else if (isExpired) {
                  badgeColor = AppTheme.dangerColor;
                  badgeText = 'Expiré (Hors POS)';
                  badgeIcon = Icons.cancel_outlined;
                } else if (daysLeft != null && daysLeft <= 90) {
                  badgeColor = AppTheme.warningColor;
                  badgeText = 'Expire bientôt ($daysLeft j)';
                  badgeIcon = Icons.warning_amber_rounded;
                } else {
                  badgeColor = AppTheme.successColor;
                  badgeText = 'Actif en Caisse POS';
                  badgeIcon = Icons.check_circle_outline;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Icône de lot
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(badgeIcon, size: 18, color: badgeColor),
                      ),
                      const SizedBox(width: 12),

                      // Infos lot
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Lot $batchNum',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expDate != null
                                  ? 'Péremption : ${DateFormat('dd/MM/yyyy').format(expDate)}${daysLeft != null ? " ($daysLeft jours restants)" : ""}'
                                  : 'Aucune date de péremption',
                              style: TextStyle(
                                fontSize: 11,
                                color: isExpired ? AppTheme.dangerColor : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quantité & Prix du lot
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${qty.toInt()} unités',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: qty > 0 ? (isExpired ? Colors.grey : AppTheme.primaryColor) : Colors.grey,
                            ),
                          ),
                          if (purchasePrice > 0)
                            Text(
                              'Achat: ${purchasePrice.toStringAsFixed(0)} FBu/u',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPricingAndPackagingSection(bool isDark, Medicine med) {
    final bpc = med.boxesPerCarton > 0 ? med.boxesPerCarton : 1;
    final ppb = med.blistersPerBox > 0 ? med.blistersPerBox : 1;
    final cpp = med.unitsPerBlister > 0 ? med.unitsPerBlister : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.15) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.sell_outlined, size: 18, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Conditionnement & Prix par niveau', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              if (med.fournisseur != null && med.fournisseur!.isNotEmpty)
                Text(
                  'Fournisseur : ${med.fournisseur}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Grille des prix par niveau
          Row(
            children: [
              Expanded(child: _priceLevelTile('Unité', med.prixVenteUnite, med.prixAchatUnite, '1 u', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _priceLevelTile('Plaquette', med.prixVentePlaquette, med.prixAchatPlaquette, '$cpp u', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _priceLevelTile('Boîte', med.prixVenteBoite, med.prixAchatBoite, '$ppb plaq', isDark)),
              const SizedBox(width: 8),
              Expanded(child: _priceLevelTile('Carton', med.prixVenteCarton, med.prixAchatCarton, '$bpc btes', isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceLevelTile(String label, double pv, double pa, String sub, bool isDark) {
    final marge = (pv > 0 && pa > 0) ? ((pv - pa) / pa * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
              Text(sub, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            pv > 0 ? '${pv.toStringAsFixed(0)} FBu' : '-',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          if (marge > 0)
            Text(
              '+${marge.toStringAsFixed(0)}% marge',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.successColor),
            ),
        ],
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
            const Icon(Icons.error_outline_rounded, color: AppTheme.dangerColor, size: 36),
            const SizedBox(height: 8),
            Text('Erreur: $_error', style: const TextStyle(color: AppTheme.dangerColor)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Actualiser'),
          ),
          Row(
            children: [
              if (widget.onEdit != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onEdit!();
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Modifier ce médicament'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditHistorySection(bool isDark) {
    final dtFmt = DateFormat('dd/MM/yyyy à HH:mm:ss');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, color: Colors.blueGrey.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Historique des Modifications & Traçabilité',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_auditLogs.length} opération(s)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_auditLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Aucune modification récente enregistrée pour ce médicament.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _auditLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final log = _auditLogs[i];
                final action = log['action'] as String? ?? 'MODIFICATION';
                final isDelete = action.toUpperCase().contains('DELETE');
                final user = log['username'] as String? ?? 'Système';
                final role = log['user_role'] as String? ?? '';
                final details = log['details'] as String? ?? '';
                final createdAtStr = log['created_at'] as String?;

                String formattedTime = 'N/A';
                if (createdAtStr != null) {
                  try {
                    final dt = DateTime.parse(createdAtStr);
                    formattedTime = dtFmt.format(dt);
                  } catch (_) {
                    formattedTime = createdAtStr;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (isDelete ? Colors.red : Colors.blue).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDelete ? Icons.delete_outline : Icons.edit_note,
                          size: 16,
                          color: isDelete ? Colors.red : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  user,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (role.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(role, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  formattedTime,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              details,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDelete ? Colors.red.shade700 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

