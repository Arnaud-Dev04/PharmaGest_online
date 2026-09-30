import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend1/core/constants.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/services/sync_service.dart';
import 'package:frontend1/widgets/header/notifications_button.dart';
import 'package:frontend1/widgets/header/theme_toggle_button.dart';
import 'package:frontend1/widgets/header/language_selector_button.dart';
import 'package:frontend1/widgets/header/user_avatar_widget.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Header de l'application avec date, actions, indicateur de sync et infos utilisateur
class AppHeader extends StatefulWidget {
  const AppHeader({super.key});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  SyncStatus _syncStatus = SyncStatus.offline();
  bool _isSyncing = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    // Vérifie le statut toutes les 60 secondes
    _statusTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final status = await SyncService.getStatus();
    if (mounted) setState(() => _syncStatus = status);
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final result = await SyncService.push();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.cloud_done : Icons.cloud_off,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(result.message),
              ],
            ),
            backgroundColor: result.success
                ? const Color(0xFF2E7D32)
                : AppTheme.dangerColor,
            duration: const Duration(seconds: 3),
          ),
        );
        await _refreshStatus();
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Couleur du dot selon le statut
  Color _dotColor() {
    if (!_syncStatus.online) return Colors.red;
    if (_syncStatus.errorCount > 0) return Colors.orange;
    if (_syncStatus.pendingCount > 0) return Colors.amber;
    return const Color(0xFF43A047); // vert
  }

  /// Formate la date actuelle selon la langue
  String _formatDate(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final now = DateTime.now();

    if (languageProvider.languageCode == 'fr') {
      final dayName = languageProvider.translate(_getDayKey(now.weekday));
      final monthName = languageProvider.translate(_getMonthKey(now.month));
      return '$dayName ${now.day} $monthName ${now.year}';
    } else {
      return DateFormat('EEEE, MMMM d, yyyy', 'en_US').format(now);
    }
  }

  String _getDayKey(int weekday) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday',
    ];
    return days[weekday - 1];
  }

  String _getMonthKey(int month) {
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final User? user = authProvider.user;
    final isAdmin = user?.isAdmin ?? false;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Section gauche : Date + Rôle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Date
                Text(
                  _formatDate(context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.darkSidebarText
                        : AppTheme.lightSidebarText,
                    textBaseline: TextBaseline.alphabetic,
                  ),
                ),
                const SizedBox(height: 2),

                // Rôle
                Text(
                  languageProvider.translate(
                    isAdmin ? 'adminMode' : 'pharmacistMode',
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Section droite : Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Indicateur de synchronisation cloud ──
              Tooltip(
                message: '${_syncStatus.statusLabel}\n'
                    '${_syncStatus.pendingCount} en attente · '
                    '${_syncStatus.syncedCount} synchronisée(s)\n'
                    'Cliquer pour synchroniser maintenant',
                child: InkWell(
                  onTap: _triggerSync,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _dotColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _dotColor().withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dot animé si sync en cours
                        _isSyncing
                            ? SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _dotColor(),
                                ),
                              )
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _dotColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                        const SizedBox(width: 6),
                        Text(
                          _syncStatus.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _dotColor(),
                          ),
                        ),
                        if (_syncStatus.pendingCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_syncStatus.pendingCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppConstants.spacingMd),

              // Notifications
              const NotificationsButton(),
              SizedBox(width: AppConstants.spacingMd),

              // Toggle thème
              const ThemeToggleButton(),
              SizedBox(width: AppConstants.spacingMd),

              // Sélecteur langue
              const LanguageSelectorButton(),
              SizedBox(width: AppConstants.spacingMd),

              // Avatar utilisateur
              const UserAvatarWidget(),
            ],
          ),
        ],
      ),
    );
  }
}
