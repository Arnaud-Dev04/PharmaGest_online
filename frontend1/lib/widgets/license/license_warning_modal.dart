import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';

/// Modal d'avertissement de licence
/// Affiche un message personnalisé pendant 30 secondes
/// Si la licence est expirée, bloque l'application
class LicenseWarningModal extends StatefulWidget {
  final bool isExpired;
  final int daysRemaining;
  final String message;
  final VoidCallback? onDismiss;

  const LicenseWarningModal({
    super.key,
    required this.isExpired,
    required this.daysRemaining,
    required this.message,
    this.onDismiss,
  });

  @override
  State<LicenseWarningModal> createState() => _LicenseWarningModalState();
}

class _LicenseWarningModalState extends State<LicenseWarningModal> {
  int _remainingSeconds = 30;
  Timer? _timer;
  bool _showSuspendedScreen = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isExpired) {
      // Si pas expiré, démarrer le compte à rebours de 30 secondes
      _startCountdown();
    } else {
      // Si expiré, afficher directement l'écran de suspension
      _showSuspendedScreen = true;
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuspendedScreen) {
      return _buildSuspendedScreen();
    }

    return _buildWarningDialog();
  }

  Widget _buildWarningDialog() {
    return PopScope(
      canPop: false, // Empêcher la fermeture
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'avertissement
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(height: 24),

              // Titre
              Text(
                widget.isExpired
                    ? 'LICENCE EXPIRÉE'
                    : 'AVERTISSEMENT DE LICENCE',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message personnalisé du SuperAdmin
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.message.isNotEmpty
                      ? widget.message
                      : 'Votre licence expire dans ${widget.daysRemaining} jours.',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              // Compte à rebours
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fermeture automatique dans $_remainingSeconds secondes',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuspendedScreen() {
    return PopScope(
      canPop: false, // Empêcher la fermeture
      child: Material(
        color: Colors.black.withValues(alpha: 0.95),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône de blocage
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    size: 72,
                    color: AppTheme.dangerColor,
                  ),
                ),
                const SizedBox(height: 32),

                // Titre
                const Text(
                  'APPLICATION SUSPENDUE',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.dangerColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Message
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.dangerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.message.isNotEmpty
                        ? widget.message
                        : 'Votre licence a expiré. L\'application est maintenant suspendue.\n\nVeuillez contacter votre administrateur pour renouveler la licence.',
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Contact info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.support_agent,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Contactez le support technique',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
