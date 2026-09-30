import 'package:frontend1/models/medicine.dart';
import 'package:frontend1/models/pos_product.dart';

enum SaleType {
  unit,
  blister,
  packaging, // Boîte standard
  carton,
}

class CartItem {
  final Medicine medicine;
  int quantity;            // Quantité saisie (ex: 2 cartons)
  SaleType saleType;       // Type de vente
  double discountPercent;  // Remise (0-100)

  // === BATCH/LOT INFO (POS) ===
  List<BatchAllocation> allocations;
  List<BatchInfo> availableBatches;

  // === LEVEL / MULTI-PRIX ===
  String level;          // 'unite', 'plaquette', 'boite', 'carton'
  double? unitPrice;     // Prix unitaire au niveau choisi

  CartItem({
    required this.medicine,
    this.quantity = 1,
    this.saleType = SaleType.packaging,
    this.discountPercent = 0.0,
    this.allocations = const [],
    this.availableBatches = const [],
    this.level = 'unite',
    this.unitPrice,
  });

  /// Prix unitaire de base selon le type (avant remise)
  double get baseUnitTestPrice {
    final unitsPerPackaging = medicine.unitsPerPackaging > 0 ? medicine.unitsPerPackaging : 1;
    final unitPrice = medicine.priceSell / unitsPerPackaging;

    switch (saleType) {
      case SaleType.unit:
        return unitPrice;
      case SaleType.blister:
        return unitPrice * (medicine.unitsPerBlister > 0 ? medicine.unitsPerBlister : 1);
      case SaleType.packaging:
        return medicine.priceSell;
      case SaleType.carton:
        return medicine.priceSell * (medicine.boxesPerCarton > 0 ? medicine.boxesPerCarton : 1);
    }
  }

  /// Prix unitaire après remise (utilise unitPrice si défini par le dialog de niveau)
  double get effectiveUnitPrice {
    final base = unitPrice ?? baseUnitTestPrice;
    return base * (1 - (discountPercent / 100));
  }

  /// Total pour cet item (prix * quantité)
  double get totalAmount {
    return effectiveUnitPrice * quantity;
  }

  /// Conversion de la quantité saisie en UNITÉS TOTALES pour le backend
  /// C'est ici que la correction logique s'opère pour sécuriser le stock
  int get totalUnits {
    int multiplier = 1;

    switch (saleType) {
      case SaleType.unit:
        multiplier = 1;
        break;
      case SaleType.blister:
        multiplier = medicine.unitsPerBlister > 0 ? medicine.unitsPerBlister : 1;
        break;
      case SaleType.packaging:
        // 1 Boîte = X Plaquettes * Y Unités ( = unitsPerPackaging)
        multiplier = medicine.unitsPerPackaging > 0 ? medicine.unitsPerPackaging : 1;
        break;
      case SaleType.carton:
        // 1 Carton = Z Boîtes * (Unités par Boîte)
        final unitsPerBox = medicine.unitsPerPackaging > 0 ? medicine.unitsPerPackaging : 1;
        multiplier = (medicine.boxesPerCarton > 0 ? medicine.boxesPerCarton : 1) * unitsPerBox;
        break;
    }

    return quantity * multiplier;
  }

  /// Résumé des lots utilisés pour affichage dans le panier
  String get batchSummary {
    if (allocations.isEmpty) return 'Aucun lot';
    if (allocations.length == 1) {
      final a = allocations.first;
      return 'Lot ${a.batchNumber} (exp: ${a.formattedExpiry})';
    }
    return '${allocations.length} lots utilisés';
  }

  /// Date d'expiration la plus proche parmi les allocations
  DateTime? get nearestExpiry {
    if (allocations.isEmpty) return null;
    return allocations
        .where((a) => a.expirationDate != null)
        .map((a) => a.expirationDate!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  CartItem copyWith({
    Medicine? medicine,
    int? quantity,
    SaleType? saleType,
    double? discountPercent,
    List<BatchAllocation>? allocations,
    List<BatchInfo>? availableBatches,
    String? level,
    double? unitPrice,
  }) {
    return CartItem(
      medicine: medicine ?? this.medicine,
      quantity: quantity ?? this.quantity,
      saleType: saleType ?? this.saleType,
      discountPercent: discountPercent ?? this.discountPercent,
      allocations: allocations ?? this.allocations,
      availableBatches: availableBatches ?? this.availableBatches,
      level: level ?? this.level,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}
