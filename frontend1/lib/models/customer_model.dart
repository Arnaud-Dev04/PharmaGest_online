class Customer {
  final int id;
  final String firstName;
  final String lastName;
  final String phone;
  final int totalPoints;

  Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.totalPoints = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      totalPoints: json['total_points'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'total_points': totalPoints,
    };
  }
}
