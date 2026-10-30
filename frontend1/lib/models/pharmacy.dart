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
  final String status;
  final String plan;
  final int maxUsers;
  final DateTime? createdAt;
  final DateTime? licenseExpiresAt;
  final bool licenseIsTrial;
  final String? licenseKey;
  final String? nif;
  final String? rcNumber;
  final String? taxCenter;
  final bool obrEnabled;
  final String obrEnvironment;

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
    this.status = 'active',
    required this.plan,
    required this.maxUsers,
    this.createdAt,
    this.licenseExpiresAt,
    this.licenseIsTrial = false,
    this.licenseKey,
    this.nif,
    this.rcNumber,
    this.taxCenter,
    this.obrEnabled = false,
    this.obrEnvironment = 'sandbox',
  });

  bool get isPendingApproval => status == 'pending_approval' || !isActive;

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    final active = json['is_active'] as bool? ?? false;
    final stat = json['status']?.toString() ?? (active ? 'active' : 'pending_approval');

    return Pharmacy(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      isActive: active,
      status: stat,
      plan: json['plan']?.toString() ?? 'basic',
      maxUsers: (json['max_users'] as num?)?.toInt() ?? 3,
      createdAt: parseDate(json['created_at']),
      licenseExpiresAt: parseDate(json['license_expires_at']),
      licenseIsTrial: json['license_is_trial'] as bool? ?? false,
      licenseKey: json['license_key']?.toString(),
      nif: json['nif']?.toString(),
      rcNumber: json['rc_number']?.toString(),
      taxCenter: json['tax_center']?.toString(),
      obrEnabled: json['obr_enabled'] as bool? ?? false,
      obrEnvironment: json['obr_environment']?.toString() ?? 'sandbox',
    );
  }
}

class PlatformMetrics {
  final int pharmacyCount;
  final int activePharmacyCount;
  final int pendingPharmacyCount;
  final int userCount;
  final int saleCount;
  final double totalRevenue;

  const PlatformMetrics({
    required this.pharmacyCount,
    required this.activePharmacyCount,
    this.pendingPharmacyCount = 0,
    required this.userCount,
    required this.saleCount,
    required this.totalRevenue,
  });

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformMetrics(
      pharmacyCount: (json['pharmacy_count'] as num?)?.toInt() ?? 0,
      activePharmacyCount: (json['active_pharmacy_count'] as num?)?.toInt() ?? 0,
      pendingPharmacyCount: (json['pending_pharmacy_count'] as num?)?.toInt() ?? 0,
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
