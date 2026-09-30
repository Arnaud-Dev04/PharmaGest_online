class AppSettings {
  final String pharmacyName;
  final String pharmacyAddress;
  final String pharmacyPhone;
  final String pharmacyNif;
  final String logoUrl;
  final String currency;
  final int licenseWarningDays;
  final int licenseWarningDuration;
  final String licenseWarningMessage;

  AppSettings({
    this.pharmacyName = '',
    this.pharmacyAddress = '',
    this.pharmacyPhone = '',
    this.pharmacyNif = '',
    this.logoUrl = '',
    this.currency = 'FBu',
    this.licenseWarningDays = 60,
    this.licenseWarningDuration = 30,
    this.licenseWarningMessage = '',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      pharmacyName: json['pharmacy_name'] ?? '',
      pharmacyAddress: json['pharmacy_address'] ?? '',
      pharmacyPhone: json['pharmacy_phone'] ?? '',
      pharmacyNif: json['pharmacy_nif'] ?? '',
      logoUrl: json['logo_url'] ?? '',
      currency: json['currency'] ?? 'FBu',
      licenseWarningDays: json['license_warning_bdays'] ?? 60,
      licenseWarningDuration: json['license_warning_duration'] ?? 30,
      licenseWarningMessage: json['license_warning_message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pharmacy_name': pharmacyName,
      'pharmacy_address': pharmacyAddress,
      'pharmacy_phone': pharmacyPhone,
      'pharmacy_nif': pharmacyNif,
      'logo_url': logoUrl,
      'currency': currency,
      'license_warning_bdays': licenseWarningDays,
      'license_warning_duration': licenseWarningDuration,
      'license_warning_message': licenseWarningMessage,
    };
  }
}
