import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';

/// Barre d'onglets moderne reprenant le design segmented pill du Dashboard.
/// Compatible directement avec [DefaultTabController] et [TabBarView].
class ModernPillTabBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> tabs;
  final TabController? controller;
  final bool isScrollable;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double height;
  final ValueChanged<int>? onTap;

  const ModernPillTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(4),
    this.height = 46,
    this.onTap,
  });

  @override
  Size get preferredSize => Size.fromHeight(height + margin.vertical);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkInput : AppTheme.lightInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
        onTap: onTap,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor:
            isDark ? AppTheme.darkSidebarText : AppTheme.lightSidebarText,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: tabs,
      ),
    );
  }
}

/// Helper pour créer un onglet avec icône moderne arrondie/outlined et badge optionnel
class ModernTab extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Widget? badge;

  const ModernTab({
    super.key,
    this.icon,
    required this.text,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            badge!,
          ],
        ],
      ),
    );
  }
}

