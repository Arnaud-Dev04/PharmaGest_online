/// Modèle léger pour les résultats de recherche POS.
/// Inclut les informations de lots (batches) et prix multi-niveaux.
class PosProduct {
  final int id;
  final String name;
  final String code;
  final double priceSell;
  final double availableQuantity;
  final List<BatchInfo> batches;
  // Multi-level pricing
  final double prixVenteUnite;
  final double prixVentePlaquette;
  final double prixVenteBoite;
  final double prixVenteCarton;
  final int comprimesParPlaquette;
  final int plaquettesParBoite;
  final int boxesPerCarton;
  // Medicine details
  final String? dosageForm;
  final String? dci;
  final String? formeGalenique;

  PosProduct({
    required this.id,
    required this.name,
    required this.code,
    required this.priceSell,
    required this.availableQuantity,
    required this.batches,
    this.prixVenteUnite = 0,
    this.prixVentePlaquette = 0,
    this.prixVenteBoite = 0,
    this.prixVenteCarton = 0,
    this.comprimesParPlaquette = 1,
    this.plaquettesParBoite = 1,
    this.boxesPerCarton = 1,
    this.dosageForm,
    this.dci,
    this.formeGalenique,
  });

  DateTime? get nearestExpiry =>
      batches.isNotEmpty ? batches.first.expirationDate : null;
  int get batchCount => batches.length;
  bool get isOutOfStock => availableQuantity <= 0;

  /// Prix au niveau donné
  double priceAtLevel(String level) {
    switch (level) {
      case 'carton': return prixVenteCarton > 0 ? prixVenteCarton : priceSell;
      case 'boite': return prixVenteBoite > 0 ? prixVenteBoite : priceSell;
      case 'plaquette': return prixVentePlaquette > 0 ? prixVentePlaquette : priceSell;
      default: return prixVenteUnite > 0 ? prixVenteUnite : priceSell;
    }
  }

  /// Conversion quantité au niveau → unités de base
  int toBaseUnits(int qty, String level) {
    switch (level) {
      case 'carton': return qty * boxesPerCarton * plaquettesParBoite * comprimesParPlaquette;
      case 'boite': return qty * plaquettesParBoite * comprimesParPlaquette;
      case 'plaquette': return qty * comprimesParPlaquette;
      default: return qty;
    }
  }

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    return PosProduct(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      priceSell: (json['price_sell'] as num).toDouble(),
      availableQuantity: (json['available_quantity'] as num).toDouble(),
      batches: (json['batches'] as List?)
              ?.map((b) => BatchInfo.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      prixVenteUnite: (json['prix_vente_unite'] as num?)?.toDouble() ?? 0,
      prixVentePlaquette: (json['prix_vente_plaquette'] as num?)?.toDouble() ?? 0,
      prixVenteBoite: (json['prix_vente_boite'] as num?)?.toDouble() ?? 0,
      prixVenteCarton: (json['prix_vente_carton'] as num?)?.toDouble() ?? 0,
      comprimesParPlaquette: json['comprimes_par_plaquette'] as int? ?? 1,
      plaquettesParBoite: json['plaquettes_par_boite'] as int? ?? 1,
      boxesPerCarton: json['boxes_per_carton'] as int? ?? 1,
      dosageForm: json['dosage_form'] as String?,
      dci: json['dci'] as String?,
      formeGalenique: json['forme_galenique'] as String?,
    );
  }
}

/// Informations d'un lot (batch) pour affichage.
class BatchInfo {
  final int id;
  final String batchNumber;
  final DateTime expirationDate;
  final double quantity;

  BatchInfo({
    required this.id,
    required this.batchNumber,
    required this.expirationDate,
    required this.quantity,
  });

  String get formattedExpiry =>
      '${expirationDate.day.toString().padLeft(2, '0')}/${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.year}';
  int get daysUntilExpiry => expirationDate.difference(DateTime.now()).inDays;
  bool get isExpiringSoon => daysUntilExpiry < 90 && daysUntilExpiry > 0;

  factory BatchInfo.fromJson(Map<String, dynamic> json) {
    return BatchInfo(
      id: json['id'] as int,
      batchNumber: json['batch_number'] as String,
      expirationDate: DateTime.parse(json['expiration_date'] as String),
      quantity: (json['quantity'] as num).toDouble(),
    );
  }
}

/// Allocation FEFO retournée par /pos/cart/add
class BatchAllocation {
  final int batchId;
  final String batchNumber;
  final DateTime? expirationDate;
  final int quantity;

  BatchAllocation({
    required this.batchId,
    required this.batchNumber,
    this.expirationDate,
    required this.quantity,
  });

  String get formattedExpiry {
    if (expirationDate == null) return '?';
    return '${expirationDate!.day.toString().padLeft(2, '0')}/${expirationDate!.month.toString().padLeft(2, '0')}/${expirationDate!.year}';
  }

  factory BatchAllocation.fromJson(Map<String, dynamic> json) {
    return BatchAllocation(
      batchId: json['batch_id'] as int,
      batchNumber: (json['batch_number'] as String?) ?? '',
      expirationDate: json['expiration_date'] != null
          ? DateTime.parse(json['expiration_date'] as String)
          : null,
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'batch_id': batchId,
        'batch_number': batchNumber,
        'expiration_date': expirationDate?.toIso8601String().split('T').first,
        'quantity': quantity,
      };
}
