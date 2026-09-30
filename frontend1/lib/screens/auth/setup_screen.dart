import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/services/user_service.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/core/error_helper.dart';

/// Écran de configuration initiale (première installation)
/// Wizard en 2 étapes pour le Super Admin
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  final UserService _userService = UserService();

  // Step 1 - Create users
  final _userFormKey = GlobalKey<FormState>();
  final _newUsernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  String _selectedRole = 'pharmacist';
  bool _showNewPassword = false;
  bool _isCreatingUser = false;
  final List<User> _createdUsers = [];

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _newUsernameController.dispose();
    _newPasswordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _animateToStep(int step) {
    _slideController.reset();
    _fadeController.reset();
    setState(() {
      _currentStep = step;
    });
    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _createUser() async {
    if (!_userFormKey.currentState!.validate()) return;

    setState(() => _isCreatingUser = true);

    try {
      final newUser = await _userService.createUser({
        'username': _newUsernameController.text.trim(),
        'password': _newPasswordController.text,
        'role': _selectedRole,
        'is_active': true,
      });

      setState(() {
        _createdUsers.add(newUser);
        _newUsernameController.clear();
        _newPasswordController.clear();
        _selectedRole = 'pharmacist';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utilisateur "${newUser.username}" créé avec succès'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${ErrorHelper.extractErrorMessage(e).replaceFirst("Exception: ", "")}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() => _isCreatingUser = false);
    }
  }

  Future<void> _deleteCreatedUser(User user) async {
    try {
      await _userService.deleteUser(user.id);
      setState(() {
        _createdUsers.removeWhere((u) => u.id == user.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: ${ErrorHelper.extractErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeSetup() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.completeSetup();

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    const Color(0xFF0F172A),
                  ]
                : [
                    AppTheme.primaryColor.withValues(alpha: 0.03),
                    Colors.white,
                    AppTheme.successColor.withValues(alpha: 0.03),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Header with logo
                        _buildHeader(isDark),
                        const SizedBox(height: 32),

                        // Stepper indicator
                        _buildStepperIndicator(isDark),
                        const SizedBox(height: 32),

                        // Content
                        if (_currentStep == 0) _buildStep1CreateUsers(isDark),
                        if (_currentStep == 1) _buildStep2Summary(isDark),
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

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        // Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.successColor],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset('assets/logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Configuration Initiale',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bienvenue ! Configurez les utilisateurs de votre pharmacie.',
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

  Widget _buildStepperIndicator(bool isDark) {
    return Row(
      children: [
        _buildStepDot(0, 'Utilisateurs', isDark),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1
                ? AppTheme.primaryColor
                : (isDark ? Colors.white12 : Colors.grey[300]),
          ),
        ),
        _buildStepDot(1, 'Résumé', isDark),
      ],
    );
  }

  Widget _buildStepDot(int step, String label, bool isDark) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 44 : 36,
          height: isCurrent ? 44 : 36,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.successColor],
                  )
                : null,
            color: isActive ? null : (isDark ? Colors.white10 : Colors.grey[200]),
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isActive && step < _currentStep
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.grey),
                      fontWeight: FontWeight.bold,
                      fontSize: isCurrent ? 16 : 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.white38 : Colors.grey),
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 1 - Create Users
  // ============================================================
  Widget _buildStep1CreateUsers(bool isDark) {
    return Card(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_outline, color: AppTheme.primaryColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Créer les utilisateurs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ajoutez les comptes pour votre équipe',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Les utilisateurs créés devront changer leur mot de passe à leur première connexion.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User creation form
            Form(
              key: _userFormKey,
              child: Column(
                children: [
                  // Username
                  TextFormField(
                    controller: _newUsernameController,
                    decoration: InputDecoration(
                      labelText: 'Nom d\'utilisateur',
                      hintText: 'Ex: pharmacien1',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: isDark ? AppTheme.darkSidebarText.withValues(alpha: 0.6) : Colors.grey[600],
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom d\'utilisateur est requis';
                      }
                      if (value.trim().length < 3) {
                        return 'Minimum 3 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: !_showNewPassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      hintText: 'Mot de passe temporaire',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: isDark ? AppTheme.darkSidebarText.withValues(alpha: 0.6) : Colors.grey[600],
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword ? Icons.visibility_off : Icons.visibility,
                          color: isDark ? AppTheme.darkSidebarText.withValues(alpha: 0.6) : Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() => _showNewPassword = !_showNewPassword);
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

                  // Role dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Rôle',
                      prefixIcon: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: isDark ? AppTheme.darkSidebarText.withValues(alpha: 0.6) : Colors.grey[600],
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pharmacist',
                        child: Row(
                          children: [
                            Icon(Icons.local_pharmacy, size: 18, color: AppTheme.successColor),
                            SizedBox(width: 8),
                            Text('Pharmacien'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: AppTheme.warningColor),
                            SizedBox(width: 8),
                            Text('Administrateur'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedRole = value ?? 'pharmacist');
                    },
                  ),
                  const SizedBox(height: 20),

                  // Add user button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingUser ? null : _createUser,
                      icon: _isCreatingUser
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.person_add, size: 20),
                      label: Text(_isCreatingUser ? 'Création...' : 'Ajouter l\'utilisateur'),
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

            // Created users list
            if (_createdUsers.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Utilisateurs créés (${_createdUsers.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ..._createdUsers.map((user) => _buildCreatedUserTile(user, isDark)),
            ],

            const SizedBox(height: 28),

            // Navigation buttons
            Row(
              children: [
                if (_createdUsers.isEmpty)
                  TextButton(
                    onPressed: () => _animateToStep(1),
                    child: const Text('Passer cette étape →'),
                  ),
                const Spacer(),
                if (_createdUsers.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _animateToStep(1),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Continuer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatedUserTile(User user, bool isDark) {
    final roleLabel = user.role == 'admin' ? 'Administrateur' : 'Pharmacien';
    final roleColor = user.role == 'admin' ? AppTheme.warningColor : AppTheme.successColor;
    final roleIcon = user.role == 'admin' ? Icons.shield_outlined : Icons.local_pharmacy;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Icon(roleIcon, size: 18, color: roleColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  roleLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: roleColor,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: () => _deleteCreatedUser(user),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2 - Summary
  // ============================================================
  Widget _buildStep2Summary(bool isDark) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Card(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résumé de la configuration',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vérifiez avant de commencer',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Super Admin info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    AppTheme.successColor.withValues(alpha: isDark ? 0.1 : 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Administrateur',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        authProvider.user?.username ?? 'arnaud',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 14, color: AppTheme.successColor),
                        SizedBox(width: 4),
                        Text(
                          'Actif',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Created users
            Text(
              'Utilisateurs créés (${_createdUsers.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            if (_createdUsers.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Aucun utilisateur supplémentaire créé.\nVous pourrez en créer plus tard depuis le menu Utilisateurs.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
                        ),
                  ),
                ),
              )
            else
              ..._createdUsers.map((user) => _buildSummaryUserTile(user, isDark)),

            if (_createdUsers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.key, size: 18, color: AppTheme.warningColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ces utilisateurs devront changer leur mot de passe à leur première connexion.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.warningColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Navigation
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _animateToStep(0),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Retour'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _completeSetup,
                  icon: const Icon(Icons.rocket_launch, size: 20),
                  label: const Text('Commencer à utiliser PharmaGestion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryUserTile(User user, bool isDark) {
    final roleLabel = user.role == 'admin' ? 'Administrateur' : 'Pharmacien';
    final roleColor = user.role == 'admin' ? AppTheme.warningColor : AppTheme.successColor;
    final roleIcon = user.role == 'admin' ? Icons.shield_outlined : Icons.local_pharmacy;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Icon(roleIcon, size: 18, color: roleColor),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.username,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(roleLabel, style: TextStyle(fontSize: 12, color: roleColor)),
            ],
          ),
          const Spacer(),
          Icon(Icons.check_circle, size: 20, color: AppTheme.successColor),
        ],
      ),
    );
  }
}
