import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pharmac+ Design System - Theme Configuration
/// Reproduit exactement le design du frontend React avec Tailwind CSS
class AppTheme {
  // ============================================================================
  // COLORS - Correspondance exacte avec tailwind.config.js
  // ============================================================================

  // Primary Color - #2d9cdb (Blue)
  static const Color primaryColor = Color(0xFF2D9CDB);
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF2D9CDB,
    <int, Color>{
      50: Color(0xFFE6F4FB),
      100: Color(0xFFCCE9F7),
      200: Color(0xFF99D3EF),
      300: Color(0xFF66BDE7),
      400: Color(0xFF33A7DF),
      500: Color(0xFF2D9CDB), // DEFAULT
      600: Color(0xFF247DB0),
      700: Color(0xFF1B5E84),
      800: Color(0xFF123E58),
      900: Color(0xFF091F2C),
    },
  );

  // Success Color - #10b981 (Green)
  static const Color successColor = Color(0xFF10B981);
  static const MaterialColor successSwatch = MaterialColor(
    0xFF10B981,
    <int, Color>{
      50: Color(0xFFD1FAE5),
      100: Color(0xFFA7F3D0),
      200: Color(0xFF6EE7B7),
      300: Color(0xFF34D399),
      400: Color(0xFF10B981), // DEFAULT
      500: Color(0xFF059669),
      600: Color(0xFF047857),
      700: Color(0xFF065F46),
      800: Color(0xFF064E3B),
      900: Color(0xFF022C22),
    },
  );

  // Danger/Error Color - #ef4444 (Red)
  static const Color dangerColor = Color(0xFFEF4444);
  static const MaterialColor dangerSwatch = MaterialColor(
    0xFFEF4444,
    <int, Color>{
      50: Color(0xFFFEE2E2),
      100: Color(0xFFFECACA),
      200: Color(0xFFFCA5A5),
      300: Color(0xFFF87171),
      400: Color(0xFFEF4444), // DEFAULT
      500: Color(0xFFDC2626),
      600: Color(0xFFB91C1C),
      700: Color(0xFF991B1B),
      800: Color(0xFF7F1D1D),
      900: Color(0xFF450A0A),
    },
  );

  // Warning Color - #f59e0b (Orange)
  static const Color warningColor = Color(0xFFF59E0B);
  static const MaterialColor warningSwatch = MaterialColor(
    0xFFF59E0B,
    <int, Color>{
      50: Color(0xFFFEF3C7),
      100: Color(0xFFFEF08A),
      200: Color(0xFFFDE047),
      300: Color(0xFFFACC15),
      400: Color(0xFFF59E0B), // DEFAULT
      500: Color(0xFFD97706),
      600: Color(0xFFB45309),
      700: Color(0xFF92400E),
      800: Color(0xFF78350F),
      900: Color(0xFF451A03),
    },
  );

  // ============================================================================
  // LIGHT MODE COLORS (from index.css :root)
  // ============================================================================

  static const Color lightBackground = Color(
    0xFFF8F9FA,
  ); // --background: 248 249 250
  static const Color lightForeground = Color(
    0xFF212529,
  ); // --foreground: 33 37 41
  static const Color lightCard = Color(0xFFFFFFFF); // --card: 255 255 255
  static const Color lightCardForeground = Color(0xFF212529);
  static const Color lightBorder = Color(0xFFDEE2E6); // --border: 222 226 230
  static const Color lightInput = Color(0xFFE9ECEF); // --input: 233 236 239
  static const Color lightSidebarBg = Color(0xFFFFFFFF);
  static const Color lightSidebarText = Color(0xFF495057); // 73 80 87
  static const Color lightSidebarHover = Color(0xFFF3F4F6);
  static const Color lightSidebarActive = primaryColor;
  static const Color lightSidebarActiveText = Color(0xFFFFFFFF);

  // ============================================================================
  // DARK MODE COLORS (from index.css .dark)
  // ============================================================================

  static const Color darkBackground = Color(
    0xFF0F1225,
  ); // --background: 15 18 37
  static const Color darkForeground = Color(
    0xFFF9FAFB,
  ); // --foreground: 249 250 251
  static const Color darkCard = Color(0xFF1A1F37); // --card: 26 31 55
  static const Color darkCardForeground = Color(0xFFF9FAFB);
  static const Color darkBorder = Color(0xFF374151); // 55 65 81
  static const Color darkInput = Color(0xFF374151);
  static const Color darkSidebarBg = Color(0xFF1A1F37);
  static const Color darkSidebarText = Color(0xFFD1D5DB); // 209 213 219
  static const Color darkSidebarHover = Color(0xFF1F2937); // 31 41 55
  static const Color darkSidebarActive = primaryColor;
  static const Color darkSidebarActiveText = Color(0xFFFFFFFF);

  // ============================================================================
  // TYPOGRAPHY - Font: Inter (from tailwind.config.js)
  // ============================================================================

  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: textColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: textColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
    );
  }

  // ============================================================================
  // LIGHT THEME
  // ============================================================================

  static ThemeData get lightTheme {
    final base = ThemeData.light();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primarySwatch[600]!,
        onSecondary: Colors.white,
        error: dangerColor,
        onError: Colors.white,
        surface: lightCard,
        onSurface: lightCardForeground,

      ),

      // Scaffold
      scaffoldBackgroundColor: lightBackground,

      // Typography
      textTheme: _buildTextTheme(base.textTheme, lightForeground),

      // AppBar - Style moderne sans ombre
      appBarTheme: AppBarTheme(
        backgroundColor: lightCard,
        foregroundColor: lightForeground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: lightForeground,
        ),
      ),

      // Card - border-radius: 12px (from tailwind.config.js)
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),

      // Buttons - rounded-lg = 8px
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightForeground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: lightBorder),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: lightSidebarText),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: lightSidebarText.withValues(alpha: 0.6),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: lightSidebarText, size: 24),
    );
  }

  // ============================================================================
  // DARK THEME
  // ============================================================================

  static ThemeData get darkTheme {
    final base = ThemeData.dark();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primarySwatch[600]!,
        onSecondary: Colors.white,
        error: dangerColor,
        onError: Colors.white,
        surface: darkCard,
        onSurface: darkCardForeground,

      ),

      // Scaffold
      scaffoldBackgroundColor: darkBackground,

      // Typography
      textTheme: _buildTextTheme(base.textTheme, darkForeground),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkForeground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkForeground,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkForeground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: darkBorder),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: dangerColor, width: 2),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: darkSidebarText),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: darkSidebarText.withValues(alpha: 0.6),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(color: darkBorder, thickness: 1, space: 1),

      // Icon Theme
      iconTheme: IconThemeData(color: darkSidebarText, size: 24),
    );
  }
}
