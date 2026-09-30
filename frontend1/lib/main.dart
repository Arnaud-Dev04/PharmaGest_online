import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/theme_provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/providers/cart_provider.dart';
import 'package:frontend1/providers/license_provider.dart';
import 'package:frontend1/providers/inventory_provider.dart';
import 'package:frontend1/screens/auth/login_screen.dart';
import 'package:frontend1/screens/auth/setup_screen.dart';
import 'package:frontend1/screens/auth/change_password_screen.dart';
import 'package:frontend1/screens/layout/main_layout.dart';
import 'package:frontend1/screens/dashboard/dashboard_page.dart';
import 'package:frontend1/screens/stock/stock_page.dart';
import 'package:frontend1/screens/stock/stock_movements_page.dart';
import 'package:frontend1/screens/medicine_pricing/medicine_pricing_page.dart';
import 'package:frontend1/screens/pos/pos_page.dart';
import 'package:frontend1/screens/sales/sales_history_page.dart'; // Import Sales
import 'package:frontend1/screens/reports/reports_page.dart';
import 'package:frontend1/screens/settings/settings_page.dart'; // Import Settings
// Import REAL pages instead of placeholders
import 'package:frontend1/screens/admin/super_admin_page.dart';
import 'package:frontend1/screens/suppliers/suppliers_page.dart';
import 'package:frontend1/screens/users/users_page.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  runApp(const PharmacApp());
}

class PharmacApp extends StatelessWidget {
  const PharmacApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Envelopper l'app avec MultiProvider pour la gestion d'état
    return MultiProvider(
      providers: [
        // AuthProvider pour gérer l'authentification
        ChangeNotifierProvider(create: (_) => AuthProvider()..initAuth()),

        // ThemeProvider pour gérer le thème (clair/sombre)
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // LanguageProvider pour gérer la langue (FR/EN)
        ChangeNotifierProvider(create: (_) => LanguageProvider()),

        // CartProvider pour gérer le panier POS
        ChangeNotifierProvider(create: (_) => CartProvider()),

        // InventoryProvider pour totaux achat/vente
        ChangeNotifierProvider(create: (_) => InventoryProvider()..loadTotals()),

        // LicenseProvider pour gérer la licence
        ChangeNotifierProvider(
          create: (_) => LicenseProvider()..checkLicense(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return MaterialApp(
                title: 'PharmaGest - Gestion de Pharmacie',
                scaffoldMessengerKey: scaffoldMessengerKey,
                debugShowCheckedModeBanner: false,

                // Localization support
                locale: languageProvider.locale,

                // Thème clair (design Pharmac+)
                theme: AppTheme.lightTheme,

                // Thème sombre
                darkTheme: AppTheme.darkTheme,

                // Mode du thème (géré par ThemeProvider)
                themeMode: themeProvider.themeMode,

                // Page initiale basée sur l'état d'authentification
                home: const AuthWrapper(),

                // Routes nommées pour navigation
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/dashboard': (context) =>
                      const MainLayout(child: DashboardPage()),
                  '/stock': (context) =>
                      const MainLayout(child: _StockWrapper()),
                  '/pos': (context) => const MainLayout(child: POSPage(), noPadding: true),
                  '/sales-history': (context) =>
                      const MainLayout(child: SalesHistoryPage()),
                  '/reports': (context) =>
                      const MainLayout(child: ReportsPage()),
                  '/suppliers': (context) =>
                      const MainLayout(child: SuppliersPage()),
                  '/users': (context) => const MainLayout(child: UsersPage()),

                  '/settings': (context) =>
                      const MainLayout(child: SettingsPage()),
                  '/super-admin': (context) =>
                      const MainLayout(child: SuperAdminPage()),
                  '/setup': (context) => const SetupScreen(),
                  '/change-password': (context) =>
                      const ChangePasswordScreen(),
                  '/stock-movements': (context) =>
                      const MainLayout(child: StockMovementsPage()),
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Wrapper pour déterminer l'écran initial selon l'authentification
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Pendant le chargement initial (vérification du token)
        if (authProvider.isLoading) {
          return const SplashScreen();
        }

        // Si authentifié
        if (authProvider.isAuthenticated) {
          // Première installation : wizard de configuration (Super Admin)
          if (authProvider.isFirstSetup && authProvider.user?.isSuperAdmin == true) {
            return const SetupScreen();
          }

          // Utilisateur doit changer son mot de passe (première connexion)
          if (authProvider.mustChangePassword) {
            return const ChangePasswordScreen();
          }

          // Normal : aller au dashboard
          return const MainLayout(child: DashboardPage());
        }

        // Non authentifié : page de login
        return const LoginScreen();
      },
    );
  }
}

/// Écran de chargement pendant l'initialisation
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo avec gradient
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.successColor],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 24),

            // Nom de l'app
            Text(
              'PharmaGest',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // Indicateur de chargement
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper pour afficher MedicinePricingPage comme page Stock par défaut
class _StockWrapper extends StatelessWidget {
  const _StockWrapper();

  @override
  Widget build(BuildContext context) {
    return const MedicinePricingPage();
  }
}
