class UserStats {
  final String username;
  final int totalSales;
  final double totalRevenue;
  final double averageSaleAmount;
  final int customersServed;
  final List<UserSalesChartData> salesByDate;
  final List<UserTopProduct> topProducts;

  UserStats({
    required this.username,
    required this.totalSales,
    required this.totalRevenue,
    required this.averageSaleAmount,
    required this.customersServed,
    required this.salesByDate,
    required this.topProducts,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      username: json['username'] ?? '',
      totalSales: json['total_sales'] ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      averageSaleAmount: (json['average_sale_amount'] as num?)?.toDouble() ?? 0.0,
      customersServed: json['customers_served'] ?? 0,
      salesByDate: (json['sales_by_date'] as List?)
              ?.map((e) => UserSalesChartData.fromJson(e))
              .toList() ??
          [],
      topProducts: (json['top_products'] as List?)
              ?.map((e) => UserTopProduct.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class UserSalesChartData {
  final String date;
  final double revenue;

  UserSalesChartData({required this.date, required this.revenue});

  factory UserSalesChartData.fromJson(Map<String, dynamic> json) {
    return UserSalesChartData(
      date: json['date'] ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class UserTopProduct {
  final int medicineId;
  final String medicineName;
  final String medicineCode;
  final int quantitySold;
  final double revenueGenerated;

  UserTopProduct({
    required this.medicineId,
    required this.medicineName,
    required this.medicineCode,
    required this.quantitySold,
    required this.revenueGenerated,
  });

  factory UserTopProduct.fromJson(Map<String, dynamic> json) {
    return UserTopProduct(
      medicineId: json['medicine_id'] ?? 0,
      medicineName: json['medicine_name'] ?? '',
      medicineCode: json['medicine_code'] ?? '',
      quantitySold: json['quantity_sold'] ?? 0,
      revenueGenerated: (json['revenue_generated'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
