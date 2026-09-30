import 'package:flutter/material.dart';

/// Constantes de l'application Pharmac+
/// Correspond aux configurations de tailwind.config.js et index.css
class AppConstants {
  // ============================================================================
  // API Configuration
  // ============================================================================
  // ── Backend URL ────────────────────────────────────────────────────────────
  // Local (Windows desktop) : http://127.0.0.1:8000
  // Cloud (Render)          : https://pharmagestion.onrender.com
  static const String _localApi  = 'http://127.0.0.1:8000';
  static const String _remoteApi = 'https://pharmagestion.onrender.com';

  // Offline-first : utilise le local si disponible, sinon Render
  // Pour forcer Render en prod, passer _remoteApi directement
  // ── Mode actif ─────────────────────────────────────────────────────────────
  // LOCAL  → _localApi  (backend Python sur ce PC, port 8000)
  // CLOUD  → _remoteApi (backend Render, accès internet requis)
  static const String apiBaseUrl = _localApi;

  // ============================================================================
  // Border Radius (from tailwind.config.js)
  // ============================================================================
  static const double cardBorderRadius = 12.0; // border-radius: 'card'
  static const double buttonBorderRadius = 8.0; // rounded-lg
  static const double inputBorderRadius = 8.0; // rounded-lg
  static const double badgeBorderRadius = 16.0; // rounded-full

  // ============================================================================
  // Spacing
  // ============================================================================
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // ============================================================================
  // Padding (from .btn, .input in index.css)
  // ============================================================================
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: 16.0, // px-4
    vertical: 8.0, // py-2
  );

  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: 16.0, // px-4
    vertical: 12.0, // py-2
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: 10.0, // px-2.5
    vertical: 2.0, // py-0.5
  );

  // ============================================================================
  // Shadows (from tailwind.config.js boxShadow)
  // ============================================================================

  // 'card': '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)'
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      offset: const Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  // 'card-hover': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)'
  static List<BoxShadow> get cardHoverShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      offset: const Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -1,
    ),
  ];

  // ============================================================================
  // Animation Durations
  // ============================================================================
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationNormal = Duration(milliseconds: 200);
  static const Duration animationDurationSlow = Duration(milliseconds: 300);

  // ============================================================================
  // Sidebar Dimensions
  // ============================================================================
  static const double sidebarWidth = 260.0;
  static const double sidebarCollapsedWidth = 80.0;

  // ============================================================================
  // Header Height
  // ============================================================================
  static const double headerHeight = 64.0;

  // ============================================================================
  // Breakpoints (responsive design)
  // ============================================================================
  static const double breakpointMobile = 640.0; // sm
  static const double breakpointTablet = 768.0; // md
  static const double breakpointDesktop = 1024.0; // lg
  static const double breakpointLargeDesktop = 1280.0; // xl

  // ============================================================================
  // Table Configuration
  // ============================================================================
  static const int defaultPageSize = 10;
  static const List<int> pageSizeOptions = [10, 25, 50, 100];

  // ============================================================================
  // Badge Sizes
  // ============================================================================
  static const double badgeFontSize = 12.0; // text-xs

  // ============================================================================
  // Icon Sizes
  // ============================================================================
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
}

/// Extension pour faciliter le responsive design
extension ResponsiveContext on BuildContext {
  bool get isMobile =>
      MediaQuery.of(this).size.width < AppConstants.breakpointMobile;
  bool get isTablet =>
      MediaQuery.of(this).size.width >= AppConstants.breakpointMobile &&
      MediaQuery.of(this).size.width < AppConstants.breakpointDesktop;
  bool get isDesktop =>
      MediaQuery.of(this).size.width >= AppConstants.breakpointDesktop;

  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
}
