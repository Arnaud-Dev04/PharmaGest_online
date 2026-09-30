import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/pos_product.dart';
import 'package:frontend1/providers/cart_provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/services/pos_service.dart';
import 'package:frontend1/widgets/pos/level_selection_dialog.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/error_helper.dart';
import 'package:frontend1/screens/sales/user_sales_performance_dialog.dart';

/// Widget POS principal — grille/liste des produits avec lots (FEFO)
/// Inclut: section fréquents, toggle vue, alertes expiration, polices améliorées
class ProductGrid extends StatefulWidget {
  const ProductGrid({super.key});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final PosService _posService = PosService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<PosProduct> _products = [];
  List<PosProduct> _topProducts = [];
  bool _isLoading = false;
  bool _isListView = false; // Toggle grille/liste
  String? _error;

  int _lastSalesCount = 0;
  Timer? _clockTimer;
  Timer? _debounceTimer;
  DateTime _currentDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTopProducts();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);

    // Horloge temps réel (actualisation chaque seconde)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentDateTime = DateTime.now();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = Provider.of<CartProvider>(context);
    if (cart.salesCount != _lastSalesCount) {
      _lastSalesCount = cart.salesCount;
      _loadProducts();
      _loadTopProducts();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadProducts();
    });
  }

  Future<void> _loadTopProducts() async {
    try {
      final results = await _posService.getTopProducts(limit: 8);
      if (mounted) {
        setState(() {
          _topProducts = results.map((r) => PosProduct.fromJson(r)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts({bool showToast = false}) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final query = _searchController.text.trim();
      final results = await _posService.searchProducts(query, limit: 1000);
      if (mounted) {
        setState(() {
          _products = results.map((r) => PosProduct.fromJson(r)).toList();
          _isLoading = false;
        });
        if (showToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('${_products.length} médicament(s) chargé(s) dans le POS'),
                ],
              ),
              backgroundColor: Colors.teal[700],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = ErrorHelper.extractErrorMessage(e); _isLoading = false; });
      }
    }
  }

  void _addToCart(PosProduct product) async {
    // Show level selection dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => LevelSelectionDialog(product: product),
    );
    if (result == null) return; // cancelled

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addToCartWithLevel(
      product,
      level: result['level'] as String,
      quantity: result['quantity'] as int,
      unitPrice: result['unit_price'] as double,
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${product.name} ajouté (${result['quantity']}× ${result['level']})', overflow: TextOverflow.ellipsis)),
          ],
        ),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        width: 320,
        backgroundColor: Colors.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === HEADER ===
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('posTitle'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _products.isNotEmpty
                        ? '${_products.length} médicament(s) disponible(s) en caisse'
                        : lang.translate('posSubtitle'),
                    style: TextStyle(
                      color: _products.isNotEmpty ? (isDark ? Colors.teal[300] : Colors.teal[700]) : Colors.grey[500],
                      fontSize: 13,
                      fontWeight: _products.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Bouton Rafraîchir / Actualiser le stock POS
            Tooltip(
              message: 'Recharger les nouveaux médicaments et réapprovisionnements',
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.teal.withValues(alpha: 0.4) : Colors.teal.withValues(alpha: 0.3),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _isLoading ? null : () {
                      _loadProducts(showToast: true);
                      _loadTopProducts();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16, color: Colors.teal),
                          const SizedBox(width: 6),
                          Text(
                            'Actualiser',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.teal[300] : Colors.teal[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bouton Mes Ventes (Bilan personnel de caisse)
            Tooltip(
              message: 'Consulter mon bilan de ventes et chiffre d\'affaires',
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => UserSalesPerformanceDialog.show(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.point_of_sale_rounded, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Mes Ventes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Horloge Date et Heure exactes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.blue.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_filled_rounded, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy • HH:mm:ss').format(_currentDateTime),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // Toggle Grille / Liste
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewToggle(Icons.grid_view_rounded, false, isDark),
                  _buildViewToggle(Icons.view_list_rounded, true, isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // === SEARCH BAR ===
        TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: '🔍 Rechercher un médicament...',
            prefixIcon: const Icon(Icons.search, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _loadProducts();
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 12),

        // === FREQUENT PRODUCTS (horizontal scroll) ===
        if (_topProducts.isNotEmpty && _searchController.text.isEmpty) ...[
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                'Produits fréquents',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _topProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _buildTopProductChip(_topProducts[i], isDark),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: isDark ? AppTheme.darkBorder : Colors.grey[200]),
          const SizedBox(height: 8),
        ],

        // === PRODUCTS LIST/GRID ===
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Erreur: $_error'))
                  : _products.isEmpty
                      ? _buildEmptyState()
                      : _isListView
                          ? _buildListView(isDark)
                          : _buildGridView(isDark),
        ),
      ],
    );
  }

  // === TOP PRODUCT CHIP (horizontal scroll) ===
  Widget _buildTopProductChip(PosProduct product, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: product.isOutOfStock ? null : () => _addToCart(product),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${product.priceSell.toStringAsFixed(0)} FBu',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: product.availableQuantity < 10
                          ? AppTheme.dangerColor.withValues(alpha: 0.1)
                          : Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${product.availableQuantity.toInt()}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: product.availableQuantity < 10
                            ? AppTheme.dangerColor
                            : Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === GRID VIEW ===
  Widget _buildGridView(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    int cols = 2;
    double ratio = 0.60;
    if (width > 1200) { cols = 4; ratio = 0.65; }
    else if (width > 800) { cols = 3; ratio = 0.62; }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: ratio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (_, i) => _buildProductCard(_products[i], isDark),
    );
  }

  // === LIST VIEW (compact) ===
  Widget _buildListView(bool isDark) {
    return ListView.separated(
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _buildProductListTile(_products[i], isDark),
    );
  }

  // === PRODUCT CARD (grid) ===
  Widget _buildProductCard(PosProduct product, bool isDark) {
    final isExpiringSoon = product.nearestExpiry != null &&
        product.nearestExpiry!.difference(DateTime.now()).inDays < 7;

    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpiringSoon
              ? Colors.red.withValues(alpha: 0.5)
              : isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: isExpiringSoon ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: product.isOutOfStock ? null : () => _addToCart(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: icon + badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.medication, color: AppTheme.primaryColor, size: 18),
                  ),
                  if (product.isOutOfStock)
                    _buildBadge('STOCK 0 (RUPTURE)', AppTheme.dangerColor)
                  else if (isExpiringSoon)
                    _buildBadge('⚠ EXP < 7J', Colors.red),
                ],
              ),
              const SizedBox(height: 6),

              // Product name
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(product.code, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              if (product.dci != null || product.dosageForm != null || product.formeGalenique != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (product.formeGalenique != null && product.formeGalenique!.isNotEmpty)
                        _buildInfoTag(product.formeGalenique!, Colors.indigo),
                      if (product.dci != null && product.dci!.isNotEmpty)
                        _buildInfoTag(product.dci!, Colors.teal),
                      if (product.dosageForm != null && product.dosageForm!.isNotEmpty)
                        _buildInfoTag(product.dosageForm!, Colors.deepPurple),
                    ],
                  ),
                ),
              const SizedBox(height: 6),

              // Batch info — Flexible so it can shrink
              Flexible(child: _buildBatchChip(product)),
              const SizedBox(height: 6),

              // Price + Stock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${product.priceSell.toStringAsFixed(0)} FBu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.availableQuantity < 10
                          ? AppTheme.dangerColor.withValues(alpha: 0.1)
                          : Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.isOutOfStock
                          ? '0 dispo (RUPTURE)'
                          : '${product.availableQuantity.toInt()} dispo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: product.availableQuantity < 10 ? AppTheme.dangerColor : Colors.teal[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === PRODUCT LIST TILE (compact list view) ===
  Widget _buildProductListTile(PosProduct product, bool isDark) {
    final isExpiringSoon = product.nearestExpiry != null &&
        product.nearestExpiry!.difference(DateTime.now()).inDays < 7;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: product.isOutOfStock ? null : () => _addToCart(product),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpiringSoon
                  ? Colors.red.withValues(alpha: 0.5)
                  : isDark ? AppTheme.darkBorder : Colors.grey[200]!,
              width: isExpiringSoon ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medication, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Name + batch info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.dci != null || product.dosageForm != null || product.formeGalenique != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            if (product.formeGalenique != null && product.formeGalenique!.isNotEmpty)
                              _buildInfoTag(product.formeGalenique!, Colors.indigo),
                            if (product.dci != null && product.dci!.isNotEmpty)
                              _buildInfoTag(product.dci!, Colors.teal),
                            if (product.dosageForm != null && product.dosageForm!.isNotEmpty)
                              _buildInfoTag(product.dosageForm!, Colors.deepPurple),
                          ],
                        ),
                      ),
                    const SizedBox(height: 3),
                    _buildBatchChip(product),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.priceSell.toStringAsFixed(0)} FBu',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.isOutOfStock
                        ? '0 dispo (RUPTURE)'
                        : '${product.availableQuantity.toInt()} dispo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: product.availableQuantity < 10 ? AppTheme.dangerColor : Colors.teal,
                    ),
                  ),
                ],
              ),

              // Badges
              if (product.isOutOfStock) ...[
                const SizedBox(width: 8),
                _buildBadge('STOCK 0 (RUPTURE)', AppTheme.dangerColor),
              ] else if (isExpiringSoon) ...[
                const SizedBox(width: 8),
                _buildBadge('⚠ EXP', Colors.red),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // === BATCH INFO CHIP ===
  Widget _buildBatchChip(PosProduct product) {
    if (product.batches.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Text('⚠ Aucun lot', style: TextStyle(fontSize: 11, color: Colors.orange)),
      );
    }

    final nearest = product.batches.first;
    final daysLeft = nearest.expirationDate.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft < 7;
    final isSoon = daysLeft < 90 && !isUrgent;

    Color chipColor = Colors.teal;
    if (isUrgent) chipColor = Colors.red;
    else if (isSoon) chipColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            size: 13,
            color: chipColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${product.batchCount} lot${product.batchCount > 1 ? 's' : ''} · Exp: ${nearest.formattedExpiry}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chipColor.withValues(alpha: 0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // === BADGE ===
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // === VIEW TOGGLE ===
  Widget _buildViewToggle(IconData icon, bool isListMode, bool isDark) {
    final isActive = _isListView == isListMode;
    return InkWell(
      onTap: () => setState(() => _isListView = isListMode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? AppTheme.primaryColor : Colors.grey,
        ),
      ),
    );
  }

  // === EMPTY STATE ===
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Essayez un autre terme de recherche',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // === INFO TAG (forme, DCI, dosage) ===
  Widget _buildInfoTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
