class Supplier {
  final int id;
  final String name;
  final String contact;
  final String phone;
  final String email;
  final String address;

  Supplier({
    required this.id,
    required this.name,
    this.contact = '',
    this.phone = '',
    this.email = '',
    this.address = '',
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      contact: json['contact_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact_name': contact,
      'phone': phone,
      'email': email,
      'address': address,
    };
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? contact,
    String? phone,
    String? email,
    String? address,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
    );
  }
}

class SupplierResponse {
  final List<Supplier> items;
  final int total;
  final int page;
  final int size;
  final int totalPages;

  SupplierResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
    required this.totalPages,
  });

  factory SupplierResponse.fromJson(Map<String, dynamic> json) {
    return SupplierResponse(
      items:
          (json['items'] as List?)?.map((i) => Supplier.fromJson(i)).toList() ??
          [],
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      size:
          json['size'] ??
          10, // backend might send 'page_size' instead of 'size'
      totalPages: json['total_pages'] ?? 1,
    );
  }
}
