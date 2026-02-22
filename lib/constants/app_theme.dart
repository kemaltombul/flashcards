import 'package:flutter/material.dart';

/// Centralized theme constants for the app
/// All colors, text styles, and design tokens in one place
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ============ COLORS ============

  // Primary Colors
  static const Color primaryBackground = Color(0xFF0F0F0F); // Soft Black
  static const Color secondaryBackground = Color(0xFF1E1E1E); // Dark Gray
  static const Color accentColor = Color(0xFFD0BCFF); // Soft Lavender

  // UI Colors
  static const Color cardColor = Color(0xFF252525);
  static const Color glassColor = Color(0x14FFFFFF); // White with 8% opacity
  static const Color overlayColor = Color(0xB3000000); // Black with 70% opacity

  // Text Colors
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFFFFFFF);
  static const Color textHint = Color(0x4DFFFFFF); // White with 30% opacity
  static const Color textDisabled = Color(0x66FFFFFF); // White with 40% opacity

  // Semantic Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFEF5350);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  // Game Mode Colors
  static const Color gameModeColor = Color(0xFFFFB74D); // Soft Orange
  static const Color studyModeColor = Color(0xFF64B5F6); // Soft Blue

  // Border Colors
  static const Color borderLight = Color(0x33FFFFFF); // White with 20% opacity
  static const Color borderMedium = Color(0x1AFFFFFF); // White with 10% opacity

  // ============ TEXT STYLES ============

  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textSecondary,
    letterSpacing: 0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.5,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: textSecondary,
    letterSpacing: 1.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: accentColor,
    letterSpacing: 1.5,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // ============ SPACING ============

  static const double spacingXs = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // ============ BORDER RADIUS ============

  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 15.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 28.0;
  static const double radiusPill = 30.0;

  // ============ ELEVATION / BLUR ============

  static const double blurHeavy = 10.0;
  static const double blurMedium = 6.0;
  static const double blurLight = 4.0;

  // ============ ANIMATION DURATIONS ============

  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // ============ HELPER METHODS ============

  /// Returns a glassmorphic decoration
  static BoxDecoration glassDecoration({
    double borderRadius = radiusXl,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? glassColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? borderLight, width: 1),
    );
  }

  /// Returns a card decoration
  static BoxDecoration cardDecoration({double borderRadius = radiusXxl}) {
    return BoxDecoration(
      color: glassColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
