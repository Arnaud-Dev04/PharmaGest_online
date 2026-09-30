import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/deletion_log.dart';
import 'package:frontend1/services/audit_service.dart';

/// Boîte de dialogue affichant le Journal des Suppressions (Médicaments et Factures)
class DeletionLogsDialog extends StatefulWidget {
  const DeletionLogsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const DeletionLogsDialog(),
    );
  }

  @override
  State<DeletionLogsDialog> createState() => _DeletionLogsDialogState();
}

class _DeletionLogsDialogState extends State<DeletionLogsDialog> {
  final AuditService _auditService = AuditService();
  List<DeletionLogEntry> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _filterType = 'all'; // 'all', 'medicine', 'pricing', 'sale'
  String _searchQuery = '';

  final ScrollController _scrollV = ScrollController();
  final ScrollController _scrollH = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollV.dispose();
    _scrollH.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await _auditService.getDeletionLogs(
        entityType: _filterType == 'all' ? null : _filterType,
        search: _searchQuery,
      );

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger le journal des suppressions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: Column(
          children: [
            // En-tête
            _buildHeader(context, isDark),
            const Divider(height: 1),

            // Barre de filtres et recherche
            _buildToolbar(isDark),

            // Contenu scrollable
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Chargement du journal d\'audit des suppressions...'),
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
                                onPressed: _loadLogs,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        )
                      : _buildTable(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.red,
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
                      'Journal des Suppressions & Annulations',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_logs.length} événement${_logs.length > 1 ? "s" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Traçabilité complète : qui a supprimé quel médicament ou annulé quelle facture.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loadLogs,
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

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: isDark ? AppTheme.darkSidebarHover : AppTheme.lightSidebarHover,
      child: Row(
        children: [
          // Filtre Type
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('Tous')),
              ButtonSegment(value: 'medicine', label: Text('Médicaments')),
              ButtonSegment(value: 'pricing', label: Text('Lots / Tarifs')),
              ButtonSegment(value: 'sale', label: Text('Factures')),
            ],
            selected: {_filterType},
            onSelectionChanged: (val) {
              setState(() => _filterType = val.first);
              _loadLogs();
            },
          ),
          const Spacer(),
          // Recherche
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, code ou utilisateur...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _loadLogs();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDark ? AppTheme.darkInput : AppTheme.lightInput,
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _loadLogs();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isDark) {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'Aucune suppression enregistrée pour le moment.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollV,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollV,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _scrollH,
              thumbVisibility: true,
              notificationPredicate: (notif) => notif.depth == 1,
              child: SingleChildScrollView(
                controller: _scrollH,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    ),
                    columnSpacing: 24,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Date & Heure', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action / Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Élément Supprimé / Annulé', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Supprimé Par', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Rôle', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Détails', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _logs.map((log) {
                      final isSale = log.entityType == 'sale';
                      final typeLabel = isSale
                          ? 'FACTURE'
                          : (log.entityType == 'pricing' ? 'LOT / TARIF' : 'MÉDICAMENT');
                      final typeColor = isSale
                          ? Colors.purple
                          : (log.entityType == 'pricing' ? Colors.blue : Colors.red);

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              log.createdAt != null
                                  ? DateFormat('dd/MM/yyyy HH:mm:ss').format(log.createdAt!.toLocal())
                                  : 'Inconnue',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: typeColor,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  isSale ? Icons.receipt_long : Icons.medication_outlined,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  log.entityName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Text(
                                  log.username,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                log.userRole ?? 'N/A',
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              log.details ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
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
