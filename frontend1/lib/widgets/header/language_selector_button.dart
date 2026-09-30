import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Bouton avec dropdown pour sélectionner la langue (FR/EN)
class LanguageSelectorButton extends StatelessWidget {
  const LanguageSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      onSelected: (String languageCode) {
        languageProvider.setLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'fr',
          child: Row(
            children: [
              Text(
                'Français',
                style: TextStyle(
                  color: languageProvider.languageCode == 'fr'
                      ? AppTheme.primaryColor
                      : null,
                  fontWeight: languageProvider.languageCode == 'fr'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (languageProvider.languageCode == 'fr') ...[
                const Spacer(),
                Icon(Icons.check, color: AppTheme.primaryColor, size: 18),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              Text(
                'English',
                style: TextStyle(
                  color: languageProvider.languageCode == 'en'
                      ? AppTheme.primaryColor
                      : null,
                  fontWeight: languageProvider.languageCode == 'en'
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (languageProvider.languageCode == 'en') ...[
                const Spacer(),
                Icon(Icons.check, color: AppTheme.primaryColor, size: 18),
              ],
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              size: 20,
              color: isDark
                  ? AppTheme.darkSidebarText
                  : AppTheme.lightSidebarText,
            ),
            const SizedBox(width: 8),
            Text(
              languageProvider.languageName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppTheme.darkSidebarText
                    : AppTheme.lightSidebarText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
