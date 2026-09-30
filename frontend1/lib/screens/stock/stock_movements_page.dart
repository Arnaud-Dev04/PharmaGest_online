import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/services/api_service.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/error_helper.dart';

/// Page du journal des mouvements de stock
/// Affiche l'historique de toutes les entrées/sorties de stock
class StockMovementsPage extends StatefulWidget {
  const StockMovementsPage({super.key});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _movements = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _isLoading = false;
  String? _error;

  // Filtres
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, String>> _typeOptions = [
    {'value': '', 'label': 'Tous les types'},
    {'value': 'entree', 'label': '📥 Entrée'},
    {'value': 'sortie_vente', 'label': '📤 Sortie (Vente)'},
    {'value': 'ajustement', 'label': '🔄 Ajustement'},
    {'value': 'perte', 'label': '❌ Perte'},
    {'value': 'annulation_vente', 'label': '↩️ Annulation'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMovements();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _currentPage = 1;
        _loadMovements();
      }
    });
  }

  Future<void> _loadMovements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final queryParams = <String, dynamic>{
        'page': _currentPage,
        'page_size': 50,
      };

      final search = _searchController.text.trim();
      if (search.isNotEmpty) queryParams['search'] = search;
      if (_selectedType != null && _selectedType!.isNotEmpty) {
        queryParams['movement_type'] = _selectedType;
      }
      if (_startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
      if (_endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      }

      final response = await _apiService.get(
        '/stock/movements',
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _movements = List<Map<String, dynamic>>.from(data['items'] ?? []);
          _totalPages = data['total_pages'] ?? 1;
          _totalItems = data['total'] ?? 0;
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
    final lp = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(lp),
        const SizedBox(height: 16),
        _buildFilters(lp, isDark),
        const SizedBox(height: 16),
        Expanded(child: _buildContent(lp, isDark)),
      ],
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal des Mouvements',
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Historique de toutes les entrées et sorties de stock',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkSidebarText
                        : AppTheme.lightSidebarText,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedType = null;
                  _startDate = null;
                  _endDate = null;
                  _currentPage = 1;
                });
                _loadMovements();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réinitialiser'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(LanguageProvider lp, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            // Recherche
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher (médicament, référence...)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
              ),
            ),

            // Filtre type
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _selectedType ?? '',
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                items: _typeOptions
                    .map((t) => DropdownMenuItem(
                          value: t['value'],
                          child: Text(t['label']!, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                    _currentPage = 1;
                  });
                  _loadMovements();
                },
              ),
            ),

            // Date début
            _buildDatePicker(
              label: 'Date début',
              value: _startDate,
              onChanged: (date) {
                setState(() {
                  _startDate = date;
                  _currentPage = 1;
                });
                _loadMovements();
              },
            ),

            // Date fin
            _buildDatePicker(
              label: 'Date fin',
              value: _endDate,
              onChanged: (date) {
                setState(() {
                  _endDate = date;
                  _currentPage = 1;
                });
                _loadMovements();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return SizedBox(
      width: 180,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
            suffixIcon: value != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => onChanged(null),
                  )
                : const Icon(Icons.calendar_today, size: 16),
          ),
          child: Text(
            value != null ? DateFormat('dd/MM/yyyy').format(value) : '',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LanguageProvider lp, bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.dangerColor),
            const SizedBox(height: 16),
            Text('Erreur de chargement'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadMovements,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          Expanded(
            child: _movements.isEmpty
                ? const Center(child: Text('Aucun mouvement trouvé'))
                : _buildTable(isDark),
          ),
          if (_totalItems > 0) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildTable(bool isDark) {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(140), // Date
          1: FlexColumnWidth(2), // Médicament
          2: FixedColumnWidth(140), // Type
          3: FixedColumnWidth(100), // Quantité
          4: FlexColumnWidth(2), // Motif
          5: FlexColumnWidth(1.5), // Référence
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        children: [
          _buildTableHeader(isDark),
          ..._movements.map((m) => _buildTableRow(m, isDark)),
        ],
      ),
    );
  }

  TableRow _buildTableHeader(bool isDark) {
    Widget cell(String text, {TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          textAlign: align,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
              ),
        ),
      );
    }

    return TableRow(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInput : const Color(0xFFF9FAFB),
      ),
      children: [
        cell('Date'),
        cell('Médicament'),
        cell('Type'),
        cell('Quantité', align: TextAlign.right),
        cell('Motif'),
        cell('Référence'),
      ],
    );
  }

  TableRow _buildTableRow(Map<String, dynamic> movement, bool isDark) {
    final type = movement['type'] as String? ?? '';
    final quantite = movement['quantite'] as int? ?? 0;
    final isPositive = quantite > 0;

    // Format date
    String dateStr = '-';
    if (movement['date_mouvement'] != null) {
      try {
        final date = DateTime.parse(movement['date_mouvement']);
        dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
      } catch (_) {}
    }

    // Type badge
    final typeConfig = _getTypeConfig(type);

    return TableRow(
      children: [
        // Date
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(dateStr, style: const TextStyle(fontSize: 12)),
        ),

        // Médicament
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                movement['medicine_name'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              Text(
                movement['medicine_code'] ?? '',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),

        // Type badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeConfig['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: typeConfig['color'].withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(typeConfig['icon'], size: 14, color: typeConfig['color']),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    typeConfig['label'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: typeConfig['color'],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Quantité
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            '${isPositive ? "+" : ""}$quantite',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isPositive ? AppTheme.successColor : AppTheme.dangerColor,
            ),
          ),
        ),

        // Motif
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            movement['motif'] ?? '-',
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Référence
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            movement['reference'] ?? '-',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getTypeConfig(String type) {
    switch (type) {
      case 'entree':
        return {
          'label': 'Entrée',
          'color': AppTheme.successColor,
          'icon': Icons.arrow_downward,
        };
      case 'sortie_vente':
        return {
          'label': 'Vente',
          'color': AppTheme.primaryColor,
          'icon': Icons.arrow_upward,
        };
      case 'ajustement':
        return {
          'label': 'Ajustement',
          'color': Colors.orange,
          'icon': Icons.swap_vert,
        };
      case 'perte':
        return {
          'label': 'Perte',
          'color': AppTheme.dangerColor,
          'icon': Icons.remove_circle_outline,
        };
      case 'annulation_vente':
        return {
          'label': 'Annulation',
          'color': Colors.purple,
          'icon': Icons.undo,
        };
      default:
        return {
          'label': type,
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total: $_totalItems mouvements'),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadMovements();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page $_currentPage / $_totalPages'),
              IconButton(
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadMovements();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
