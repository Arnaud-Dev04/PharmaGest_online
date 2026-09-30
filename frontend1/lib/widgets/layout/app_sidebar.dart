import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/navigation_item.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/widgets/layout/navigation_tile.dart';

/// Sidebar de navigation de l'application
/// Affiche le logo Pharmac+, les items de navigation filtrés par rôle, et le bouton logout
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final User? user = authProvider.user;
    final isSuperAdmin = user?.role.toLowerCase() == 'super_admin';
    final isAdmin = user?.role.toLowerCase() == 'admin' || isSuperAdmin;

    // Filtrer la navigation selon le rôle
    final filteredNavItems = NavigationItems.filterByRole(user?.role);

    // Route actuelle
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/dashboard';

    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        border: Border(
          right: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & Brand
          _buildLogoSection(context, isDark, isAdmin, languageProvider),

          // Navigation Items
          _buildNavigationSection(context, filteredNavItems, currentRoute),

          // Logout Button
          _buildLogoutSection(context, isDark, authProvider, languageProvider),
        ],
      ),
    );
  }

  /// Section logo Pharmac+
  Widget _buildLogoSection(
    BuildContext context,
    bool isDark,
    bool isAdmin,
    LanguageProvider languageProvider,
  ) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icône Pill dans carré bleu
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),

          // Texte Pharmac+ et sous-texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'PharmaGest',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  languageProvider.translate(
                    isAdmin ? 'adminMode' : 'pharmacistMode',
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkSidebarText
                        : AppTheme.lightSidebarText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section de navigation
  Widget _buildNavigationSection(
    BuildContext context,
    List<NavigationItem> items,
    String currentRoute,
  ) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: items.map((item) {
          final isActive = currentRoute == item.route;

          return NavigationTile(
            item: item,
            isActive: isActive,
            onTap: () {
              // Fermer le drawer si mobile
              if (Scaffold.of(context).hasDrawer) {
                Navigator.of(context).pop();
              }

              // Naviguer vers la route
              if (currentRoute != item.route) {
                Navigator.of(context).pushReplacementNamed(item.route);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  /// Section logout
  Widget _buildLogoutSection(
    BuildContext context,
    bool isDark,
    AuthProvider authProvider,
    LanguageProvider languageProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            await authProvider.logout();
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.dangerColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, size: 20),
              const SizedBox(width: 8),
              Text(
                languageProvider.translate('logout'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
