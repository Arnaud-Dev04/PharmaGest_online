import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/user.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// Widget affichant l'avatar et les informations de l'utilisateur
class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final User? user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return const SizedBox.shrink();
    }

    // Initiale de l'utilisateur
    final initial = user.username.isNotEmpty
        ? user.username.substring(0, 1).toUpperCase()
        : 'A';

    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          // Nom et email (texte à droite)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.username,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppTheme.darkForeground
                      : AppTheme.lightForeground,
                ),
              ),
              if (user.email.isNotEmpty)
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppTheme.darkSidebarText
                        : AppTheme.lightSidebarText,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Avatar circulaire
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
