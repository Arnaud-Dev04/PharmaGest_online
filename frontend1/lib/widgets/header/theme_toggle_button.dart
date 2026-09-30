import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Bouton pour toggle entre thème clair et sombre
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
        size: 20,
      ),
      tooltip: isDark ? 'Passer en mode clair' : 'Passer en mode sombre',
      onPressed: () {
        Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
      },
    );
  }
}
