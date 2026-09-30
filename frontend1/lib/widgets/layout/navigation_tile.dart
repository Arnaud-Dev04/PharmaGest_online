import 'package:flutter/material.dart';
import 'package:frontend1/models/navigation_item.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Widget représentant un item cliquable de navigation
class NavigationTile extends StatelessWidget {
  final NavigationItem item;
  final bool isActive;
  final VoidCallback onTap;

  const NavigationTile({
    super.key,
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    languageProvider.translate(item.name),
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
