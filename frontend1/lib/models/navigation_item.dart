import 'package:flutter/material.dart';

/// Modèle représentant un item de navigation dans la sidebar
class NavigationItem {
  /// Nom de l'item (clé de traduction)
  final String name;

  /// Route de navigation
  final String route;

  /// Icône à afficher
  final IconData icon;

  /// Si true, visible seulement pour les admins et super admins
  final bool adminOnly;

  /// Si true, visible seulement pour les super admins
  final bool superAdminOnly;

  const NavigationItem({
    required this.name,
    required this.route,
    required this.icon,
    this.adminOnly = false,
    this.superAdminOnly = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationItem &&
        other.name == name &&
        other.route == route &&
        other.icon == icon &&
        other.adminOnly == adminOnly &&
        other.superAdminOnly == superAdminOnly;
  }

  @override
  int get hashCode {
    return Object.hash(name, route, icon, adminOnly, superAdminOnly);
  }
}

/// Liste des items de navigation (correspond au menu React)
class NavigationItems {
  static final List<NavigationItem> items = [
    const NavigationItem(
      name: 'dashboard',
      route: '/dashboard',
      icon: Icons.dashboard,
    ),
    const NavigationItem(
      name: 'stock',
      route: '/stock',
      icon: Icons.inventory_2,
    ),
    const NavigationItem(name: 'pos', route: '/pos', icon: Icons.shopping_cart),
    const NavigationItem(
      name: 'salesHistory',
      route: '/sales-history',
      icon: Icons.history,
    ),
    const NavigationItem(
      name: 'suppliers',
      route: '/suppliers',
      icon: Icons.local_shipping,
    ),
    const NavigationItem(
      name: 'users',
      route: '/users',
      icon: Icons.people,
      adminOnly: true,
    ),
    const NavigationItem(
      name: 'reports',
      route: '/reports',
      icon: Icons.description,
    ),
    const NavigationItem(
      name: 'settings',
      route: '/settings',
      icon: Icons.settings,
    ),
    const NavigationItem(
      name: 'superAdmin',
      route: '/super-admin',
      icon: Icons.admin_panel_settings,
      superAdminOnly: true,
    ),
  ];

  /// Filtre les items selon le rôle de l'utilisateur
  static List<NavigationItem> filterByRole(String? userRole) {
    if (userRole == null) return [];

    final isSuperAdmin = userRole.toLowerCase() == 'super_admin';
    final isAdmin = userRole.toLowerCase() == 'admin' || isSuperAdmin;

    if (isSuperAdmin) {
      // Super admin voit tout
      return items;
    }

    if (isAdmin) {
      // Admin voit tout sauf super admin
      return items.where((item) => !item.superAdminOnly).toList();
    }

    // Pharmacien voit seulement : POS, Stock, Sales History, Suppliers, Dashboard
    final pharmacistAllowedRoutes = ['/pos', '/stock', '/sales-history', '/suppliers', '/dashboard'];
    return items
        .where((item) => pharmacistAllowedRoutes.contains(item.route))
        .toList();
  }
}
