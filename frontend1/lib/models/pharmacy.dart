class Pharmacy {
  final int id;
  final String name;
  final String code;
  final String? address;
  final String? phone;
  final String? email;
  final String? country;
  final String? city;
  final bool isActive;
  final String plan;
  final int maxUsers;
  final DateTime? createdAt;

  const Pharmacy({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.phone,
    this.email,
    this.country,
    this.city,
    required this.isActive,
    required this.plan,
    required this.maxUsers,
    this.createdAt,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    return Pharmacy(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      isActive: json['is_active'] as bool? ?? false,
      plan: json['plan']?.toString() ?? 'basic',
      maxUsers: (json['max_users'] as num?)?.toInt() ?? 3,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

class PlatformMetrics {
  final int pharmacyCount;
  final int activePharmacyCount;
  final int userCount;
  final int saleCount;
  final double totalRevenue;

  const PlatformMetrics({
    required this.pharmacyCount,
    required this.activePharmacyCount,
    required this.userCount,
    required this.saleCount,
    required this.totalRevenue,
  });

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformMetrics(
      pharmacyCount: (json['pharmacy_count'] as num?)?.toInt() ?? 0,
      activePharmacyCount: (json['active_pharmacy_count'] as num?)?.toInt() ?? 0,
      userCount: (json['user_count'] as num?)?.toInt() ?? 0,
      saleCount: (json['sale_count'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PharmacyPage {
  final List<Pharmacy> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PharmacyPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PharmacyPage.fromJson(Map<String, dynamic> json) => PharmacyPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => Pharmacy.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['page_size'] as num?)?.toInt() ?? 25,
        totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      );
}