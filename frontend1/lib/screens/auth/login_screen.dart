import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/core/constants.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/language_provider.dart';

/// Écran de connexion reproduisant exactement le design React
/// Design split-screen : Logo/Brand à gauche, Formulaire à droite
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _rememberMe = false;
  bool _isPlatformAdmin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.pharmacyCode != null && auth.pharmacyCode!.isNotEmpty) {
        _pharmacyCodeController.text = auth.pharmacyCode!;
      }
    });
  }

  @override
  void dispose() {
    _pharmacyCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final pharmacyCode = _isPlatformAdmin ? null : _pharmacyCodeController.text.trim();

    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
      pharmacyCode: pharmacyCode,
    );

    if (success && mounted) {
      // Redirection selon le rôle
      if (authProvider.user?.role == 'platform_admin' || _isPlatformAdmin) {
        Navigator.of(context).pushReplacementNamed('/platform-admin');
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Row(
        children: [
          // ============================================================
          // Panel Gauche - Brand (caché sur mobile)
          // ============================================================
          if (context.isDesktop)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Contenu centré
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo Pharmac+
                            _buildLogo(context, isDark),

                            const SizedBox(height: 64),

                            // Texte de bienvenue
                            _buildWelcomeText(context, isDark),
                          ],
                        ),
                      ),
                    ),

                    // Gradient décoratif en bas
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 256,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              isDark
                                  ? AppTheme.darkSidebarBg
                                  : AppTheme.lightSidebarBg,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ============================================================
          // Panel Droit - Formulaire de connexion
          // ============================================================
          Expanded(
            child: Container(
              color: isDark
                  ? AppTheme.darkBackground
                  : AppTheme.lightBackground,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo mobile (seulement sur petits écrans)
                        if (!context.isDesktop) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.primaryColor,
                                          AppTheme.successColor,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'PharmaGest',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              _buildThemeToggle(context),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Toggle thème desktop
                        if (context.isDesktop) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildThemeToggle(context),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Titre
                        Text(
                          Provider.of<LanguageProvider>(
                            context,
                          ).translate('login'),
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Provider.of<LanguageProvider>(
                            context,
                          ).translate('loginSubtitle'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDark
                                    ? AppTheme.darkSidebarText
                                    : AppTheme.lightSidebarText,
                              ),
                        ),
                        const SizedBox(height: 32),

                        // Alerte d'erreur
                        if (authProvider.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.dangerSwatch[900]!.withValues(
                                      alpha: 0.2,
                                    )
                                  : AppTheme.dangerSwatch[50],
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.dangerSwatch[800]!
                                    : AppTheme.dangerSwatch[200]!,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConstants.inputBorderRadius,
                              ),
                            ),
                            child: Text(
                              authProvider.errorMessage!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? AppTheme.dangerSwatch[300]
                                        : AppTheme.dangerSwatch[700],
                                  ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Formulaire
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Champ Code Pharmacie (masqué si connexion Admin Plateforme)
                              if (!_isPlatformAdmin) ...[
                                _buildPharmacyCodeField(context, isDark),
                                const SizedBox(height: 20),
                              ],

                              // Champ Username
                              _buildUsernameField(context, isDark),
                              const SizedBox(height: 20),

                              // Champ Password
                              _buildPasswordField(context, isDark),
                              const SizedBox(height: 20),

                              // Remember me & Toggle Admin Plateforme
                              _buildOptionsRow(context, isDark),
                              const SizedBox(height: 24),

                              // Bouton de connexion
                              _buildLoginButton(context, authProvider),
                            ],
                          ),
                        ),

                        // Footer
                        const SizedBox(height: 64),
                        Center(
                          child: Text(
                            'Version 1.0.0 • © 2025 Developped by ArnaudDev',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppTheme.darkSidebarText.withValues(
                                          alpha: 0.7,
                                        )
                                      : AppTheme.lightSidebarText.withValues(
                                          alpha: 0.7,
                                        ),
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Widgets Helpers
  // ============================================================

  Widget _buildLogo(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Icône avec gradient
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 24),

        // Texte Pharmac+
        Text(
          'PharmaGest',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          Provider.of<LanguageProvider>(context).translate('adminMode'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppTheme.darkSidebarText
                : AppTheme.lightSidebarText,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText(BuildContext context, bool isDark) {
    return Column(
      children: [
        Text(
          'Bienvenue sur votre plateforme de gestion',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Gérez votre pharmacie efficacement avec un système moderne et intuitif. '
          'Suivez vos stocks, vos ventes et vos fournisseurs en temps réel.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppTheme.darkSidebarText
                : AppTheme.lightSidebarText,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      onPressed: () {
        // Toggle theme (à implémenter avec ThemeProvider)
        // Pour l'instant, pas d'action
      },
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
      ),
      tooltip: isDark
          ? Provider.of<LanguageProvider>(context).translate('lightMode')
          : Provider.of<LanguageProvider>(context).translate('darkMode'),
    );
  }

  Widget _buildPharmacyCodeField(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Provider.of<LanguageProvider>(context).translate('platformCode'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            Text(
              'Officine',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                    : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _pharmacyCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Ex: PHARM-001',
            prefixIcon: Icon(
              Icons.local_pharmacy_outlined,
              color: isDark
                  ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                  : Colors.grey[600],
            ),
          ),
          validator: (value) {
            if (!_isPlatformAdmin && (value == null || value.trim().isEmpty)) {
              return 'Code pharmacie requis';
            }
            return null;
          },
          enabled: !Provider.of<AuthProvider>(context).isLoading,
        ),
      ],
    );
  }

  Widget _buildUsernameField(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Provider.of<LanguageProvider>(context).translate('username'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: Provider.of<LanguageProvider>(
              context,
            ).translate('username'),
            prefixIcon: Icon(
              Icons.person_outline,
              color: isDark
                  ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                  : Colors.grey[600],
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).translate('nameRequired');
            }
            return null;
          },
          enabled: !Provider.of<AuthProvider>(context).isLoading,
        ),
      ],
    );
  }

  Widget _buildPasswordField(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Provider.of<LanguageProvider>(context).translate('password'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            hintText: Provider.of<LanguageProvider>(
              context,
            ).translate('password'),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: isDark
                  ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                  : Colors.grey[600],
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: isDark
                    ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                    : Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).translate('nameRequired');
            }
            return null;
          },
          enabled: !Provider.of<AuthProvider>(context).isLoading,
        ),
      ],
    );
  }

  Widget _buildRememberMe(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: _rememberMe,
            onChanged: Provider.of<AuthProvider>(context).isLoading
                ? null
                : (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
            activeColor: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Se souvenir de moi',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppTheme.darkSidebarText
                : AppTheme.lightSidebarText,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsRow(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRememberMe(context, isDark),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: Provider.of<AuthProvider>(context).isLoading
              ? null
              : () {
                  setState(() {
                    _isPlatformAdmin = !_isPlatformAdmin;
                  });
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlatformAdmin
                      ? Icons.check_circle_rounded
                      : Icons.admin_panel_settings_outlined,
                  size: 16,
                  color: _isPlatformAdmin
                      ? AppTheme.primaryColor
                      : (isDark
                          ? AppTheme.darkSidebarText.withValues(alpha: 0.7)
                          : Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPlatformAdmin ? 'Admin Plateforme' : 'Plateforme',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: _isPlatformAdmin ? FontWeight.w600 : FontWeight.normal,
                    color: _isPlatformAdmin
                        ? AppTheme.primaryColor
                        : (isDark
                            ? AppTheme.darkSidebarText.withValues(alpha: 0.7)
                            : Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context, AuthProvider authProvider) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _handleLogin,
        child: authProvider.isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Provider.of<LanguageProvider>(
                      context,
                      listen: false,
                    ).translate('loggingIn'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                Provider.of<LanguageProvider>(
                  context,
                  listen: false,
                ).translate('loginButton'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
