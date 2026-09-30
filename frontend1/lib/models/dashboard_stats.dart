// Modèles de données pour le Dashboard

/// Point de données pour le graphique de revenus
class RevenueChartPoint {
  final DateTime date;
  final double amount;

  RevenueChartPoint({required this.date, required this.amount});

  factory RevenueChartPoint.fromJson(Map<String, dynamic> json) {
    return RevenueChartPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'amount': amount};
  }
}

/// Vente récente
class RecentSale {
  final String code;
  final DateTime date;
  final double totalAmount;

  RecentSale({
    required this.code,
    required this.date,
    required this.totalAmount,
  });

  factory RecentSale.fromJson(Map<String, dynamic> json) {
    return RecentSale(
      code: json['code']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'date': date.toIso8601String(),
      'total_amount': totalAmount,
    };
  }
}

/// Produit le plus vendu
class TopProduct {
  final int id;
  final String name;
  final String code;
  final int totalSold;

  TopProduct({
    required this.id,
    required this.name,
    required this.code,
    required this.totalSold,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown',
      code: json['code']?.toString() ?? '',
      totalSold: json['total_sold'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'code': code, 'total_sold': totalSold};
  }
}

/// Médicament expirant bientôt
class ExpiringMedicine {
  final String code;
  final String name;
  final DateTime expiryDate;
  final double quantity;

  ExpiringMedicine({
    required this.code,
    required this.name,
    required this.expiryDate,
    required this.quantity,
  });

  factory ExpiringMedicine.fromJson(Map<String, dynamic> json) {
    return ExpiringMedicine(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      expiryDate:
          DateTime.tryParse(json['expiry_date']?.toString() ?? '') ??
          DateTime.now(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'expiry_date': expiryDate.toIso8601String(),
      'quantity': quantity,
    };
  }
}

/// Item d'une vente annulée
class CancelledSaleItem {
  final String medicineName;

  CancelledSaleItem({required this.medicineName});

  factory CancelledSaleItem.fromJson(Map<String, dynamic> json) {
    return CancelledSaleItem(
      medicineName: json['medicine_name']?.toString() ?? 'Unknown',
    );
  }
}

/// Vente annulée
/// Vente annulée
class CancelledSale {
  final int id;
  final int userId;
  final String? userName;
  final DateTime date;
  final DateTime? cancelledAt;
  final double totalAmount;
  final List<CancelledSaleItem> items;

  CancelledSale({
    required this.id,
    required this.userId,
    this.userName,
    required this.date,
    this.cancelledAt,
    required this.totalAmount,
    required this.items,
  });

  factory CancelledSale.fromJson(Map<String, dynamic> json) {
    return CancelledSale(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      userName: json['user_name'] as String?,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at']?.toString() ?? '')
          : null,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      items:
          (json['items'] as List?)
              ?.map((item) => CancelledSaleItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

/// Ventes par jour de la semaine
class SalesByDay {
  final String day;
  final double amount;

  SalesByDay({required this.day, required this.amount});

  factory SalesByDay.fromJson(Map<String, dynamic> json) {
    return SalesByDay(
      day: json['day']?.toString() ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'day': day, 'amount': amount};
}

/// Ventes par heure
class SalesByHour {
  final int hour;
  final double amount;

  SalesByHour({required this.hour, required this.amount});

  factory SalesByHour.fromJson(Map<String, dynamic> json) {
    return SalesByHour(
      hour: json['hour'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'hour': hour, 'amount': amount};
}

/// Médicament en rupture de stock
class LowStockMedicine {
  final String name;
  final String code;
  final double quantity;
  final double minStock;

  LowStockMedicine({
    required this.name,
    required this.code,
    required this.quantity,
    required this.minStock,
  });

  factory LowStockMedicine.fromJson(Map<String, dynamic> json) {
    return LowStockMedicine(
      name: json['name']?.toString() ?? 'Unknown',
      code: json['code']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      minStock: (json['min_stock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'quantity': quantity,
      'min_stock': minStock,
    };
  }
}

/// Statistiques complètes du Dashboard
class DashboardStats {
  final int totalMedicines;
  final int totalSalesCount;
  final double weeklySales;
  final int totalSuppliers;
  final int expiredMedicines;
  final int expiringSoonCount;
  final int lowStockMedicines;
  final double totalRevenue;
  final double totalPurchaseValue;
  final double totalSellValue;
  final int cancelledSales;
  final List<RevenueChartPoint> revenueChart;
  final List<RecentSale> recentSales;
  final List<TopProduct> topSellingProducts;
  final List<ExpiringMedicine> expiringSoon;
  final List<SalesByDay> salesByDay;
  final List<SalesByHour> salesByHour;
  final List<LowStockMedicine> lowStockList;

  DashboardStats({
    required this.totalMedicines,
    required this.totalSalesCount,
    required this.weeklySales,
    required this.totalSuppliers,
    required this.expiredMedicines,
    required this.expiringSoonCount,
    required this.lowStockMedicines,
    required this.totalRevenue,
    required this.totalPurchaseValue,
    required this.totalSellValue,
    required this.cancelledSales,
    required this.revenueChart,
    required this.recentSales,
    required this.topSellingProducts,
    required this.expiringSoon,
    required this.salesByDay,
    required this.salesByHour,
    required this.lowStockList,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalMedicines: json['total_medicines'] as int? ?? 0,
      totalSalesCount: json['total_sales_count'] as int? ?? 0,
      weeklySales: (json['weekly_sales'] as num?)?.toDouble() ?? 0.0,
      totalSuppliers: json['total_suppliers'] as int? ?? 0,
      expiredMedicines: json['expired_medicines'] as int? ?? 0,
      expiringSoonCount: json['expiring_soon_count'] as int? ?? 0,
      lowStockMedicines: json['low_stock_medicines'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalPurchaseValue: (json['total_purchase_value'] as num?)?.toDouble() ?? 0.0,
      totalSellValue: (json['total_sell_value'] as num?)?.toDouble() ?? 0.0,
      cancelledSales: json['cancelled_sales'] as int? ?? 0,
      revenueChart:
          (json['revenue_chart'] as List?)
              ?.map((item) => RevenueChartPoint.fromJson(item))
              .toList() ??
          [],
      recentSales:
          (json['recent_sales'] as List?)
              ?.map((item) => RecentSale.fromJson(item))
              .toList() ??
          [],
      topSellingProducts:
          (json['top_selling_products'] as List?)
              ?.map((item) => TopProduct.fromJson(item))
              .toList() ??
          [],
      expiringSoon:
          (json['expiring_soon'] as List?)
              ?.map((item) => ExpiringMedicine.fromJson(item))
              .toList() ??
          [],
      salesByDay:
          (json['sales_by_day'] as List?)
              ?.map((item) => SalesByDay.fromJson(item))
              .toList() ??
          [],
      salesByHour:
          (json['sales_by_hour'] as List?)
              ?.map((item) => SalesByHour.fromJson(item))
              .toList() ??
          [],
      lowStockList:
          (json['low_stock_list'] as List?)
              ?.map((item) => LowStockMedicine.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_medicines': totalMedicines,
      'total_sales_count': totalSalesCount,
      'weekly_sales': weeklySales,
      'total_suppliers': totalSuppliers,
      'expired_medicines': expiredMedicines,
      'expiring_soon_count': expiringSoonCount,
      'low_stock_medicines': lowStockMedicines,
      'total_revenue': totalRevenue,
      'total_purchase_value': totalPurchaseValue,
      'total_sell_value': totalSellValue,
      'cancelled_sales': cancelledSales,
      'revenue_chart': revenueChart.map((e) => e.toJson()).toList(),
      'recent_sales': recentSales.map((e) => e.toJson()).toList(),
      'top_selling_products': topSellingProducts
          .map((e) => e.toJson())
          .toList(),
      'expiring_soon': expiringSoon.map((e) => e.toJson()).toList(),
      'sales_by_day': salesByDay.map((e) => e.toJson()).toList(),
      'sales_by_hour': salesByHour.map((e) => e.toJson()).toList(),
      'low_stock_list': lowStockList.map((e) => e.toJson()).toList(),
    };
  }
}
