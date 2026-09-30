import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/cart_item.dart';
import 'package:frontend1/providers/cart_provider.dart';
import 'package:frontend1/widgets/pos/payment_modal.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/providers/inventory_provider.dart';

class CartPanel extends StatefulWidget {
  const CartPanel({super.key});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  // Pour gérer l'affichage du popup de remise par item
  int? _activeDiscountItemId;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header Panier
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Panier (${cart.itemCount})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (cart.items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      cart.clearCart();
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Vider'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Liste Items
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Votre panier est vide',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) =>
                        _buildCartItem(cart, cart.items[index], isDark),
                  ),
          ),

          // Nom client (optionnel)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              onChanged: (val) => cart.customerName = val,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Nom du client (optionnel)',
                isDense: true,
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: Icon(Icons.person_outline, size: 16, color: Colors.grey[400]),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),

          // Totaux & Actions — REDESIGNED
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
            ),
            child: Column(
              children: [
                // Summary row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${cart.items.length} produit${cart.items.length > 1 ? 's' : ''} · ${cart.itemCount} unité${cart.itemCount > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Total row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${cart.totalAmount.toStringAsFixed(0)} FBu',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // BIG GREEN ENCAISSER BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (context) => PaymentModal(
                                totalAmount: cart.totalAmount,
                                onSuccess: () {
                                  cart.clearCart();
                                  cart.notifySaleCompleted();
                                  // Refresh inventory totals after successful sale
                                  try {
                                    final inv = Provider.of<InventoryProvider>(context, listen: false);
                                    inv.loadTotals();
                                  } catch (_) {}
                                },
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: cart.items.isEmpty ? 0 : 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          cart.items.isEmpty
                              ? 'Encaisser'
                              : 'Encaisser · ${cart.totalAmount.toStringAsFixed(0)} FBu',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartProvider cart, CartItem item, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Row 1: Nom et Remove
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.medicine.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => cart.removeFromCart(item.medicine.id, level: item.level),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.dangerColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // === BATCH/LOT INFO ===
            _buildBatchAllocationInfo(item),
            const SizedBox(height: 8),

            // Row 2: Prix U et calculs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'PU: ${item.effectiveUnitPrice.toStringAsFixed(0)} FBu',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${item.totalAmount.toStringAsFixed(0)} FBu',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (item.discountPercent > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Remise -${item.discountPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Row 3: Controls (Type, Quantity, Discount)
            Row(
              children: [
                // Type Selector (Carton/Box/Unit)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Carton
                      if ((item.medicine.boxesPerCarton) > 1)
                        _buildTypeBtn(
                          cart,
                          item,
                          SaleType.carton,
                          Icons.inventory_2,
                          'Carton',
                        ),
                      // Box
                      _buildTypeBtn(
                        cart,
                        item,
                        SaleType.packaging,
                        Icons.inbox,
                        'Boîte',
                      ),
                      // Blister
                      if ((item.medicine.blistersPerBox) > 1)
                        _buildTypeBtn(
                          cart,
                          item,
                          SaleType.blister,
                          Icons.grid_view,
                          'Plaquette',
                        ),
                      // Unit
                      _buildTypeBtn(
                        cart,
                        item,
                        SaleType.unit,
                        Icons.circle,
                        'Unité',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Quantity
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildQtyBtn(
                        () => cart.updateQuantity(item.medicine.id, -1, level: item.level),
                        Icons.remove,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildQtyBtn(
                        () => cart.updateQuantity(item.medicine.id, 1, level: item.level),
                        Icons.add,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Discount Button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.percent,
                        size: 16,
                        color: item.discountPercent > 0
                            ? AppTheme.successColor
                            : Colors.grey,
                      ),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: item.discountPercent > 0
                                ? AppTheme.successColor
                                : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _activeDiscountItemId =
                              _activeDiscountItemId == item.medicine.id
                              ? null
                              : item.medicine.id;
                        });
                      },
                    ),
                    if (_activeDiscountItemId == item.medicine.id)
                      CompositedTransformTarget(
                        link: LayerLink(),
                        child: Container(),
                      ),
                  ],
                ),
              ],
            ),

            // Inline Discount Input (visible if active)
            if (_activeDiscountItemId == item.medicine.id)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Text('Remise % : ', style: TextStyle(fontSize: 12)),
                    SizedBox(
                      width: 60,
                      height: 30,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final p = double.tryParse(val) ?? 0;
                          cart.updateDiscount(item.medicine.id, p, level: item.level);
                        },
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          setState(() => _activeDiscountItemId = null),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('OK', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Widget d'info lot FEFO affiché dans chaque item du panier
  Widget _buildBatchAllocationInfo(CartItem item) {
    if (item.allocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            SizedBox(width: 6),
            Text(
              'Allocation lots...',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Affichage compact des allocations FEFO
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final alloc in item.allocations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 11,
                    color: Colors.teal[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${alloc.batchNumber} × ${alloc.quantity} — exp: ${alloc.formattedExpiry}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.teal[700],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeBtn(
    CartProvider cart,
    CartItem item,
    SaleType type,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = item.saleType == type;
    return InkWell(
      onTap: () => cart.updateSaleType(item.medicine.id, type, level: item.level),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(6),
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppTheme.primaryColor : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyBtn(VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: Colors.grey[700]),
      ),
    );
  }

}
