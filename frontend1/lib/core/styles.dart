import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/core/constants.dart';

/// Styles de widgets personnalisés reproduisant les classes CSS de index.css
class AppStyles {
  // ============================================================================
  // CARD STYLES (from .card and .card-hover)
  // ============================================================================

  static BoxDecoration cardDecoration(
    BuildContext context, {
    bool hover = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      boxShadow: hover ? AppConstants.cardHoverShadow : AppConstants.cardShadow,
    );
  }

  // ============================================================================
  // BADGE STYLES (from .badge-* classes)
  // ============================================================================

  /// Badge Success (vert)
  static BoxDecoration badgeSuccessDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? AppTheme.successSwatch[900] : AppTheme.successSwatch[100],
      borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
    );
  }

  static TextStyle badgeSuccessTextStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextStyle(
      fontSize: AppConstants.badgeFontSize,
      fontWeight: FontWeight.w500,
      color: isDark ? AppTheme.successSwatch[300] : AppTheme.successSwatch[700],
    );
  }

  /// Badge Warning (orange)
  static BoxDecoration badgeWarningDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? AppTheme.warningSwatch[900] : AppTheme.warningSwatch[100],
      borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
    );
  }

  static TextStyle badgeWarningTextStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextStyle(
      fontSize: AppConstants.badgeFontSize,
      fontWeight: FontWeight.w500,
      color: isDark ? AppTheme.warningSwatch[300] : AppTheme.warningSwatch[700],
    );
  }

  /// Badge Danger (rouge)
  static BoxDecoration badgeDangerDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? AppTheme.dangerSwatch[900] : AppTheme.dangerSwatch[100],
      borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
    );
  }

  static TextStyle badgeDangerTextStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextStyle(
      fontSize: AppConstants.badgeFontSize,
      fontWeight: FontWeight.w500,
      color: isDark ? AppTheme.dangerSwatch[300] : AppTheme.dangerSwatch[700],
    );
  }

  /// Badge Info (bleu)
  static BoxDecoration badgeInfoDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(
      color: isDark ? AppTheme.primarySwatch[900] : AppTheme.primarySwatch[100],
      borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
    );
  }

  static TextStyle badgeInfoTextStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextStyle(
      fontSize: AppConstants.badgeFontSize,
      fontWeight: FontWeight.w500,
      color: isDark ? AppTheme.primarySwatch[300] : AppTheme.primarySwatch[700],
    );
  }

  // ============================================================================
  // BUTTON VARIANTS (from .btn-* classes)
  // ============================================================================

  /// Primary Button Style
  static ButtonStyle primaryButtonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: AppConstants.buttonPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
      ),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppTheme.primarySwatch[700]; // active
        }
        if (states.contains(WidgetState.hovered)) {
          return AppTheme.primarySwatch[600]; // hover
        }
        return AppTheme.primaryColor; // default
      }),
    );
  }

  /// Secondary Button Style (gray)
  static ButtonStyle secondaryButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton.styleFrom(
      backgroundColor: isDark
          ? const Color(0xFF374151)
          : const Color(0xFFE5E7EB), // gray-200/gray-700
      foregroundColor: isDark
          ? const Color(0xFFE5E7EB)
          : const Color(0xFF1F2937), // gray-200/gray-800
      elevation: 0,
      padding: AppConstants.buttonPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
      ),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return isDark
              ? const Color(0xFF4B5563)
              : const Color(0xFFD1D5DB); // gray-600/gray-300
        }
        return isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
      }),
    );
  }

  /// Danger Button Style (rouge)
  static ButtonStyle dangerButtonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.dangerColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: AppConstants.buttonPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
      ),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return AppTheme.dangerSwatch[700]; // active
        }
        if (states.contains(WidgetState.hovered)) {
          return AppTheme.dangerSwatch[600]; // hover
        }
        return AppTheme.dangerColor; // default
      }),
    );
  }

  /// Ghost Button Style (transparent)
  static ButtonStyle ghostButtonStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: isDark
          ? AppTheme.darkForeground
          : AppTheme.lightForeground,
      padding: AppConstants.buttonPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
      ),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return isDark
              ? const Color(0xFF1F2937) // gray-800
              : const Color(0xFFF3F4F6); // gray-100
        }
        return Colors.transparent;
      }),
    );
  }

  // ============================================================================
  // FOCUS RING (from .focus-ring)
  // ============================================================================

  static BoxDecoration focusRingDecoration(
    BuildContext context, {
    required bool hasFocus,
  }) {
    if (!hasFocus) {
      return const BoxDecoration();
    }

    return BoxDecoration(
      border: Border.all(color: AppTheme.primaryColor, width: 2),
      borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
    );
  }

  // ============================================================================
  // INPUT DECORATION
  // ============================================================================

  static InputDecoration inputDecoration({
    required BuildContext context,
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? AppTheme.darkInput : Colors.white,
      contentPadding: AppConstants.inputPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        borderSide: const BorderSide(color: AppTheme.dangerColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
        borderSide: const BorderSide(color: AppTheme.dangerColor, width: 2),
      ),
    );
  }
}
