import 'package:intl/intl.dart';

enum RestockStatus { draft, confirmed, received, cancelled }

class RestockItem {
  final int? id;
  final int medicineId;
  final String medicineName;
  final int quantity;
  final double priceBuy;
  final DateTime? expiryDate;

  RestockItem({
    this.id,
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.priceBuy,
    this.expiryDate,
  });

  factory RestockItem.fromJson(Map<String, dynamic> json) {
    return RestockItem(
      id: json['id'],
      medicineId: json['medicine_id'],
      medicineName: json['medicine_name'] ?? 'Inconnu',
      quantity: json['quantity'],
      priceBuy: (json['price_buy'] as num).toDouble(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_id': medicineId,
      'quantity': quantity,
      'price_buy': priceBuy,
      'expiry_date': expiryDate != null
          ? DateFormat('yyyy-MM-dd').format(expiryDate!)
          : null,
    };
  }
}

class RestockOrder {
  final int id;
  final int supplierId;
  final String? supplierName;
  final RestockStatus status;
  final DateTime date;
  final double totalAmount;
  final List<RestockItem> items;

  RestockOrder({
    required this.id,
    required this.supplierId,
    this.supplierName,
    required this.status,
    required this.date,
    required this.totalAmount,
    required this.items,
  });

  factory RestockOrder.fromJson(Map<String, dynamic> json) {
    return RestockOrder(
      id: json['id'],
      supplierId: json['supplier_id'],
      supplierName: json['supplier_name'],
      status: RestockStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RestockStatus.draft,
      ),
      date: DateTime.parse(json['date']),
      totalAmount: (json['total_amount'] as num).toDouble(),
      items:
          (json['items'] as List?)
              ?.map((i) => RestockItem.fromJson(i))
              .toList() ??
          [],
    );
  }

  bool get isDraft => status == RestockStatus.draft;
}
