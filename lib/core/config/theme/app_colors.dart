import 'package:flutter/material.dart';

/// Professional color scheme for food platform app
/// Inspired by modern food delivery apps
class AppColors {
  // Primary Colors - Warm and inviting
  static const Color primary = Color(0xFFFF6B35); // Vibrant Orange
  static const Color primaryDark = Color(0xFFE85A2A);
  static const Color primaryLight = Color(0xFFFF8C66);

  // Secondary Colors
  static const Color secondary = Color(0xFFF7931E); // Golden Orange
  static const Color secondaryDark = Color(0xFFE07F0F);
  static const Color secondaryLight = Color(0xFFFFA647);

  // Accent Colors
  static const Color accent = Color(0xFF4CAF50); // Fresh Green
  static const Color accentDark = Color(0xFF388E3C);
  static const Color accentLight = Color(0xFF81C784);

  // Neutral Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // UI Element Colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);
  static const Color overlay = Color(0x80000000);

  // Filter and Search Colors
  static const Color filterBackground = Color(0xFFFFF3E0); // Light orange tint
  static const Color filterBorder = Color(0xFFFFE0B2);
  static const Color chipBackground = Color(0xFFFFECB3);
  static const Color chipDeleteIcon = Color(0xFFE85A2A);

  // Card Colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x0D000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Rating Stars
  static const Color starActive = Color(0xFFFFC107);
  static const Color starInactive = Color(0xFFE0E0E0);

  // Category Colors (for different food categories)
  static const Color categoryRed = Color(0xFFFF5252);
  static const Color categoryOrange = Color(0xFFFF9800);
  static const Color categoryGreen = Color(0xFF4CAF50);
  static const Color categoryBlue = Color(0xFF2196F3);
  static const Color categoryPurple = Color(0xFF9C27B0);
  static const Color categoryPink = Color(0xFFE91E63);
}
