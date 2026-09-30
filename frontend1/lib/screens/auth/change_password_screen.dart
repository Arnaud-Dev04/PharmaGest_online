import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/providers/auth_provider.dart';

/// Écran de changement de mot de passe obligatoire (première connexion)
/// Affiché pour les utilisateurs créés par le Super Admin
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.changeInitialPassword(
      _newPasswordController.text,
      _confirmPasswordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mot de passe modifié avec succès !'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ]
                : [
                    AppTheme.primaryColor.withValues(alpha: 0.03),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        // Logo
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.successColor],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Card
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isDark ? Colors.white10 : Colors.grey[200]!,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Icon + Title
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lock_reset,
                                      color: AppTheme.warningColor,
                                      size: 32,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Text(
                                  'Changement de mot de passe requis',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Bonjour ${authProvider.user?.username ?? ""}. Pour sécuriser votre compte, veuillez créer un nouveau mot de passe.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isDark
                                            ? AppTheme.darkSidebarText
                                            : AppTheme.lightSidebarText,
                                      ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 28),

                                // Error message
                                if (authProvider.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            authProvider.errorMessage!,
                                            style: const TextStyle(color: Colors.red, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Form
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // New password
                                      TextFormField(
                                        controller: _newPasswordController,
                                        obscureText: !_showNewPassword,
                                        decoration: InputDecoration(
                                          labelText: 'Nouveau mot de passe',
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: isDark
                                                ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                                                : Colors.grey[600],
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showNewPassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: isDark
                                                  ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                                                  : Colors.grey[600],
                                            ),
                                            onPressed: () {
                                              setState(
                                                () => _showNewPassword = !_showNewPassword,
                                              );
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Le mot de passe est requis';
                                          }
                                          if (value.length < 4) {
                                            return 'Minimum 4 caractères';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Confirm password
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: !_showConfirmPassword,
                                        decoration: InputDecoration(
                                          labelText: 'Confirmer le mot de passe',
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: isDark
                                                ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                                                : Colors.grey[600],
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _showConfirmPassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: isDark
                                                  ? AppTheme.darkSidebarText.withValues(alpha: 0.6)
                                                  : Colors.grey[600],
                                            ),
                                            onPressed: () {
                                              setState(
                                                () => _showConfirmPassword = !_showConfirmPassword,
                                              );
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'La confirmation est requise';
                                          }
                                          if (value != _newPasswordController.text) {
                                            return 'Les mots de passe ne correspondent pas';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 28),

                                      // Submit button
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          onPressed: authProvider.isLoading
                                              ? null
                                              : _handleChangePassword,
                                          icon: authProvider.isLoading
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.check, size: 20),
                                          label: Text(
                                            authProvider.isLoading
                                                ? 'Modification...'
                                                : 'Modifier le mot de passe',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Footer
                        Text(
                          'Version 1.0.0 • © 2025 Developped by ArnaudDev',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppTheme.darkSidebarText.withValues(alpha: 0.5)
                                    : AppTheme.lightSidebarText.withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
