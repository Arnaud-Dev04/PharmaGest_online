import 'package:flutter/material.dart';
import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/models/cart_item.dart';
import 'package:frontend1/models/pos_product.dart';
import 'package:frontend1/services/pos_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final PosService _posService = PosService();

  // Infos client temporaires (pour la vente en cours)
  int? customerId;
  String customerPhone = '';
  String customerFirstName = '';
  String customerLastName = '';
  String customerName = ''; // Nom client optionnel pour facture POS

  List<CartItem> get items => List.unmodifiable(_items);

  SaleType _saleTypeForLevel(String level) {
    switch (level) {
      case 'carton':
        return SaleType.carton;
      case 'plaquette':
        return SaleType.blister;
      case 'boite':
        return SaleType.packaging;
      default:
        return SaleType.unit;
    }
  }

  String _levelForSaleType(SaleType type) {
    switch (type) {
      case SaleType.carton:
        return 'carton';
      case SaleType.blister:
        return 'plaquette';
      case SaleType.packaging:
        return 'boite';
      case SaleType.unit:
        return 'unite';
    }
  }

  double _priceForLevel(Medicine medicine, String level) {
    switch (level) {
      case 'carton':
        return medicine.prixVenteCarton > 0 ? medicine.prixVenteCarton : medicine.priceSell;
      case 'boite':
        return medicine.prixVenteBoite > 0 ? medicine.prixVenteBoite : medicine.priceSell;
      case 'plaquette':
        return medicine.prixVentePlaquette > 0 ? medicine.prixVentePlaquette : medicine.priceSell;
      default:
        return medicine.prixVenteUnite > 0 ? medicine.prixVenteUnite : medicine.priceSell;
    }
  }

  /// Ajouter un produit au panier (depuis PosProduct avec batch info)
  void addToCartFromPosProduct(PosProduct product) {
    addToCartWithLevel(product, level: 'unite', quantity: 1, unitPrice: product.priceSell);
  }

  /// Ajouter au panier avec niveau de conditionnement
  void addToCartWithLevel(PosProduct product, {
    required String level,
    required int quantity,
    required double unitPrice,
  }) {
    // Vérifier si le produit existe déjà au même niveau
    final index = _items.indexWhere((item) => item.medicine.id == product.id && item.level == level);

    if (index >= 0) {
      _items[index].quantity += quantity;
      _refreshAllocations(_items[index]);
    } else {
      final medicine = Medicine(
        id: product.id,
        code: product.code,
        name: product.name,
        priceBuy: 0,
        priceSell: unitPrice,
        prixVenteUnite: product.prixVenteUnite,
        prixVentePlaquette: product.prixVentePlaquette,
        prixVenteBoite: product.prixVenteBoite,
        prixVenteCarton: product.prixVenteCarton,
        boxesPerCarton: product.boxesPerCarton,
        blistersPerBox: product.plaquettesParBoite,
        unitsPerBlister: product.comprimesParPlaquette,
        unitsPerPackaging: product.plaquettesParBoite * product.comprimesParPlaquette,
        quantity: product.availableQuantity.toInt(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final item = CartItem(
        medicine: medicine,
        quantity: quantity,
        saleType: _saleTypeForLevel(level),
        availableBatches: product.batches,
        level: level,
        unitPrice: unitPrice,
      );

      _items.add(item);
      _refreshAllocations(item);
    }
    notifyListeners();
  }

  /// Ajouter un produit au panier (ancien mode — garde compatibilité)
  void addToCart(Medicine medicine) {
    final index = _items.indexWhere((item) => item.medicine.id == medicine.id);

    if (index >= 0) {
      _items[index].quantity++;
      _refreshAllocations(_items[index]);
    } else {
      final item = CartItem(
        medicine: medicine,
        quantity: 1,
        saleType: SaleType.packaging,
      );
      _items.add(item);
      _refreshAllocations(item);
    }
    notifyListeners();
  }

  /// Rafraîchir les allocations FEFO pour un item
  Future<void> _refreshAllocations(CartItem item) async {
    try {
      final result = await _posService.cartAdd(
        item.medicine.id,
        item.quantity,
        level: item.level,
      );

      final allocs = (result['allocations'] as List?)
              ?.map((a) => BatchAllocation.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [];

      item.allocations = allocs;
      notifyListeners();
    } catch (e) {
      debugPrint('[CartProvider] FEFO allocation failed: $e');
    }
  }

  /// Retirer du panier
  void removeFromCart(int medicineId, {String? level}) {
    _items.removeWhere(
      (item) => item.medicine.id == medicineId && (level == null || item.level == level),
    );
    notifyListeners();
  }

  /// Mettre à jour la quantité
  void updateQuantity(int medicineId, int delta, {String? level}) {
    final index = _items.indexWhere(
      (item) => item.medicine.id == medicineId && (level == null || item.level == level),
    );
    if (index >= 0) {
      final newQty = _items[index].quantity + delta;
      if (newQty > 0) {
        _items[index].quantity = newQty;
        _refreshAllocations(_items[index]);
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Changer le type de vente (Carton, Boîte, etc.)
  void updateSaleType(int medicineId, SaleType type, {String? level}) {
    final index = _items.indexWhere(
      (item) => item.medicine.id == medicineId && (level == null || item.level == level),
    );
    if (index >= 0) {
      final newLevel = _levelForSaleType(type);
      _items[index].saleType = type;
      _items[index].level = newLevel;
      _items[index].unitPrice = _priceForLevel(_items[index].medicine, newLevel);
      _refreshAllocations(_items[index]);
      notifyListeners();
    }
  }

  /// Appliquer une remise (0-100%)
  void updateDiscount(int medicineId, double percent, {String? level}) {
    final index = _items.indexWhere(
      (item) => item.medicine.id == medicineId && (level == null || item.level == level),
    );
    if (index >= 0) {
      final validPercent = percent.clamp(0.0, 100.0);
      _items[index].discountPercent = validPercent;
      notifyListeners();
    }
  }

  /// Vider le panier
  void clearCart() {
    _items.clear();
    customerPhone = '';
    customerFirstName = '';
    customerLastName = '';
    customerName = '';
    customerId = null;
    notifyListeners();
  }

  /// Calcul du montant total
  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  /// Nombre total d'articles
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Mettre à jour les infos client
  void updateCustomerInfo({
    String? phone,
    String? firstName,
    String? lastName,
    int? id,
  }) {
    if (phone != null) customerPhone = phone;
    if (firstName != null) customerFirstName = firstName;
    if (lastName != null) customerLastName = lastName;
    if (id != null) customerId = id;
    notifyListeners();
  }

  /// Compteur de ventes finalisées pour rafraîchir la grille POS
  int _salesCount = 0;
  int get salesCount => _salesCount;

  void notifySaleCompleted() {
    _salesCount++;
    notifyListeners();
  }
}
