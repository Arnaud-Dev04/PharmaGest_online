import 'package:flutter/material.dart';

/// Modele representant un item de navigation dans la sidebar
class NavigationItem {
  final String name;
  final String route;
  final IconData icon;
  final bool adminOnly;
  final bool superAdminOnly;
  final bool platformAdminOnly;

  const NavigationItem({
    required this.name,
    required this.route,
    required this.icon,
    this.adminOnly = false,
    this.superAdminOnly = false,
    this.platformAdminOnly = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationItem &&
        other.name == name &&
        other.route == route &&
        other.icon == icon &&
        other.adminOnly == adminOnly &&
        other.superAdminOnly == superAdminOnly &&
        other.platformAdminOnly == platformAdminOnly;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      route,
      icon,
      adminOnly,
      superAdminOnly,
      platformAdminOnly,
    );
  }
}

/// Liste des items de navigation
class NavigationItems {
  static final List<NavigationItem> items = [
    const NavigationItem(
      name: 'dashboard',
      route: '/dashboard',
      icon: Icons.space_dashboard_rounded,
    ),
    const NavigationItem(
      name: 'stock',
      route: '/stock',
      icon: Icons.inventory_2_outlined,
    ),
    const NavigationItem(
      name: 'pos',
      route: '/pos',
      icon: Icons.point_of_sale_rounded,
    ),
    const NavigationItem(
      name: 'cashRegister',
      route: '/cash-register',
      icon: Icons.account_balance_wallet_outlined,
    ),
    const NavigationItem(
      name: 'salesHistory',
      route: '/sales-history',
      icon: Icons.receipt_long_rounded,
    ),
    const NavigationItem(
      name: 'suppliers',
      route: '/suppliers',
      icon: Icons.local_shipping_outlined,
    ),
    const NavigationItem(
      name: 'users',
      route: '/users',
      icon: Icons.people_alt_outlined,
      adminOnly: true,
    ),
    const NavigationItem(
      name: 'analyse',
      route: '/analyse',
      icon: Icons.analytics_outlined,
      adminOnly: true,
    ),
    const NavigationItem(
      name: 'license',
      route: '/license',
      icon: Icons.workspace_premium_outlined,
      adminOnly: true,
    ),
    const NavigationItem(
      name: 'reports',
      route: '/reports',
      icon: Icons.bar_chart_rounded,
    ),
    const NavigationItem(
      name: 'settings',
      route: '/settings',
      icon: Icons.tune_rounded,
    ),
    const NavigationItem(
      name: 'superAdmin',
      route: '/super-admin',
      icon: Icons.admin_panel_settings_outlined,
      superAdminOnly: true,
    ),
    // Modules dédiés Platform Admin
    const NavigationItem(
      name: 'platformPharmacies',
      route: '/platform/pharmacies',
      icon: Icons.storefront_outlined,
      platformAdminOnly: true,
    ),
    const NavigationItem(
      name: 'platformLicences',
      route: '/platform/licences',
      icon: Icons.vpn_key_outlined,
      platformAdminOnly: true,
    ),
    const NavigationItem(
      name: 'platformAdmins',
      route: '/platform/admins',
      icon: Icons.manage_accounts_outlined,
      platformAdminOnly: true,
    ),
  ];

  /// Filtre les items selon le role de l'utilisateur
  static List<NavigationItem> filterByRole(String? userRole) {
    if (userRole == null) return [];

    final isPlatformAdmin = userRole.toLowerCase() == 'platform_admin';
    if (isPlatformAdmin) {
      // Platform admin sees strictly the 3 dedicated platform modules
      return items.where((item) => item.platformAdminOnly).toList();
    }

    final isSuperAdmin = userRole.toLowerCase() == 'super_admin';
    final isAdmin = userRole.toLowerCase() == 'admin' || isSuperAdmin;

    if (isSuperAdmin) {
      return items.where((item) => !item.platformAdminOnly).toList();
    }

    if (isAdmin) {
      return items
          .where((item) => !item.superAdminOnly && !item.platformAdminOnly)
          .toList();
    }

    final pharmacistAllowedRoutes = [
      '/pos',
      '/cash-register',
      '/stock',
      '/sales-history',
      '/suppliers',
      '/dashboard',
    ];
    return items
        .where((item) => pharmacistAllowedRoutes.contains(item.route))
        .toList();
  }
}
