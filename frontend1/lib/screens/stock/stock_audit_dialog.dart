import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:frontend1/services/pos_service.dart';
import 'package:frontend1/providers/auth_provider.dart';

/// Fenêtre modale du Journal d'Audit du Stock :
/// Affiche la traçabilité complète des modifications et suppressions de médicaments :
/// - Qui a fait l'action (nom d'utilisateur et rôle)
/// - À quelle date et quelle heure précise (HH:mm:ss)
/// - Ce qui a été modifié (anciens prix/stock vs nouveaux prix/stock)
class StockAuditDialog extends StatefulWidget {
  final int? initialMedicineId;
  final String? initialMedicineName;

  const StockAuditDialog({
    super.key,
    this.initialMedicineId,
    this.initialMedicineName,
  });

  static Future<void> show(BuildContext context, {int? medicineId, String? medicineName}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StockAuditDialog(
        initialMedicineId: medicineId,
        initialMedicineName: medicineName,
      ),
    );
  }

  @override
  State<StockAuditDialog> createState() => _StockAuditDialogState();
}

class _StockAuditDialogState extends State<StockAuditDialog> {
  final PosService _posService = PosService();
  final DateFormat _dateDisplayFmt = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeDisplayFmt = DateFormat('dd/MM/yyyy à HH:mm:ss');
  final DateFormat _apiDateFmt = DateFormat('yyyy-MM-dd');

  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedAction = 'all'; // 'all', 'UPDATE', 'DELETE'
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  final int _pageSize = 25;

  bool _isLoading = true;
  bool _isDeleting = false;
  final Set<int> _selectedLogIds = {};
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  int _totalLogs = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialMedicineName != null) {
      _searchCtrl.text = widget.initialMedicineName!;
    }
    _loadLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sStr = _startDate != null ? _apiDateFmt.format(_startDate!) : null;
      final eStr = _endDate != null ? _apiDateFmt.format(_endDate!) : null;
      final search = _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null;

      final res = await _posService.getStockAuditLogs(
        action: _selectedAction,
        search: search,
        startDate: sStr,
        endDate: eStr,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final items = (res['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final total = (res['total'] as num?)?.toInt() ?? 0;
      final totalPages = (res['total_pages'] as num?)?.toInt() ?? 1;

      if (mounted) {
        setState(() {
          _logs = items;
          _totalLogs = total;
          _totalPages = totalPages > 0 ? totalPages : 1;
          _isLoading = false;
          _selectedLogIds.removeWhere((id) => !_logs.any((l) => (l['id'] as num?)?.toInt() == id));
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

  Future<void> _confirmDeleteLog(Map<String, dynamic> log) async {
    final name = log['entity_name'] as String? ?? 'cet élément';
    final logId = (log['id'] as num).toInt();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Confirmer la suppression"),
          ],
        ),
        content: Text(
          "Voulez-vous vraiment supprimer définitivement cet enregistrement d'audit pour \"$name\" ?\nCette action est irréversible.",
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

    try {
      await _posService.deleteStockAuditLog(logId);
      _selectedLogIds.remove(logId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Enregistrement d'audit supprimé avec succès"),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${ErrorHelper.extractErrorMessage(e)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedLogIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Suppression groupée"),
          ],
        ),
        content: Text(
          "Voulez-vous vraiment supprimer définitivement les $count enregistrements d'audit sélectionnés ?\nCette action est irréversible.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text("Supprimer ($count)", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final deleted = await _posService.deleteStockAuditLogs(_selectedLogIds.toList());
      _selectedLogIds.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$deleted enregistrement(s) d'audit supprimé(s) avec succès"),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${ErrorHelper.extractErrorMessage(e)}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Widget _buildSelectionBar(bool isDark) {
    return Container(
      color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Text(
            "${_selectedLogIds.length} enregistrement(s) sélectionné(s)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.red.shade300 : Colors.red.shade800,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedLogIds.clear()),
            child: const Text("Tout désélectionner"),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            icon: _isDeleting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_forever, size: 16, color: Colors.white),
            label: Text(
              "Supprimer la sélection (${_selectedLogIds.length})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: _isDeleting ? null : _confirmDeleteSelected,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1;
      });
      _loadLogs();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1100 ? 1050.0 : screenWidth * 0.96;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.user?.isAdmin == true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            _buildFilterBar(isDark),
            if (isAdmin && _selectedLogIds.isNotEmpty) _buildSelectionBar(isDark),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorView()
                      : _buildTable(isDark, isAdmin),
            ),
            _buildPaginationBar(isDark),
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
              color: Colors.blueGrey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.history_edu, color: Colors.blueGrey.shade800, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Journal d'Audit du Stock & Traçabilité",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  "Historique des modifications et suppressions de médicaments (qui, quand, et quoi)",
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
          // Recherche
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Médicament, utilisateur, lot...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadLogs();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDark ? AppTheme.darkCard : Colors.white,
              ),
              onSubmitted: (_) {
                setState(() => _currentPage = 1);
                _loadLogs();
              },
            ),
          ),

          // Filtre type d'action
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'all',
                label: Text('Toutes'),
              ),
              ButtonSegment<String>(
                value: 'UPDATE',
                label: Text('Modifications'),
                icon: Icon(Icons.edit, size: 14),
              ),
              ButtonSegment<String>(
                value: 'DELETE',
                label: Text('Suppressions'),
                icon: Icon(Icons.delete, size: 14),
              ),
            ],
            selected: {_selectedAction},
            onSelectionChanged: (val) {
              setState(() {
                _selectedAction = val.first;
                _currentPage = 1;
              });
              _loadLogs();
            },
          ),

          // Filtre dates
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _pickDateRange,
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(
                  _startDate != null && _endDate != null
                      ? '${_dateDisplayFmt.format(_startDate!)} - ${_dateDisplayFmt.format(_endDate!)}'
                      : 'Période...',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_startDate != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Effacer filtre date',
                  onPressed: _clearDateFilter,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error ?? 'Erreur inconnue'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(bool isDark, bool isAdmin) {
    if (_logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                "Aucun enregistrement d'audit trouvé pour ces critères.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Les modifications et suppressions de médicaments futures s'afficheront ici automatiquement.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            showCheckboxColumn: isAdmin,
            onSelectAll: isAdmin
                ? (selected) {
                    setState(() {
                      if (selected == true) {
                        for (final log in _logs) {
                          final id = (log['id'] as num?)?.toInt();
                          if (id != null) _selectedLogIds.add(id);
                        }
                      } else {
                        _selectedLogIds.clear();
                      }
                    });
                  }
                : null,
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
            columnSpacing: 16,
            columns: [
              const DataColumn(label: Text('Date & Heure', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Médicament concerné', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Auteur (Utilisateur)', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Détails des modifications', style: TextStyle(fontWeight: FontWeight.bold))),
              if (isAdmin)
                const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _logs.map((log) {
              final logId = (log['id'] as num?)?.toInt();
              final isSelected = logId != null && _selectedLogIds.contains(logId);
              final action = log['action'] as String? ?? '';
              final name = log['entity_name'] as String? ?? 'N/A';
              final user = log['username'] as String? ?? 'Système';
              final role = log['user_role'] as String? ?? '';
              final details = log['details'] as String? ?? 'Aucun détail';
              final createdAtStr = log['created_at'] as String?;

              String formattedTime = 'N/A';
              if (createdAtStr != null) {
                try {
                  final dt = DateTime.parse(createdAtStr);
                  formattedTime = _dateTimeDisplayFmt.format(dt);
                } catch (_) {
                  formattedTime = createdAtStr;
                }
              }

              return DataRow(
                selected: isAdmin && isSelected,
                onSelectChanged: isAdmin && logId != null
                    ? (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedLogIds.add(logId);
                          } else {
                            _selectedLogIds.remove(logId);
                          }
                        });
                      }
                    : null,
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(formattedTime, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),
                  DataCell(_buildActionBadge(action)),
                  DataCell(
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.blue.withValues(alpha: 0.15),
                          child: Text(
                            user.isNotEmpty ? user[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(user, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        details,
                        style: TextStyle(
                          fontSize: 12,
                          color: action.startsWith('DELETE') ? Colors.red.shade700 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: "Supprimer cet enregistrement d'audit",
                        onPressed: () => _confirmDeleteLog(log),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total : $_totalLogs entrée(s) • Page $_currentPage sur $_totalPages',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadLogs();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadLogs();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    final isDelete = action.toUpperCase().contains('DELETE') || action.toUpperCase().contains('SUPPRESSION');
    final color = isDelete ? Colors.red : Colors.blue;
    final label = isDelete ? 'SUPPRESSION' : 'MODIFICATION';
    final icon = isDelete ? Icons.delete_outline : Icons.edit_note;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
