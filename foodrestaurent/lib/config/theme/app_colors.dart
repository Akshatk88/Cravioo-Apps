import 'package:flutter/material.dart';

/// Centralized color palette for Cravioo brand identity.

class AppColors {
  // ==================== BRAND COLORS ====================

  /// Main Cravioo green
  static const Color primary = Color(0xFF22C55E);

  /// Main button green
  static const Color primaryButton = Color(0xFF16A34A);

  /// Light green accent
  static const Color primaryLight = Color(0xFF4ADE80);

  /// Deep green
  static const Color primaryDark = Color(0xFF15803D);

  /// Very deep green for strong text
  static const Color primaryDeep = Color(0xFF166534);

  /// Soft green tint
  static const Color primaryTint = Color(0xFFDCFCE7);

  /// Strong green tint
  static const Color primaryTintStrong = Color(0xFFBBF7D0);

  // ==================== LIGHT THEME ====================

  /// Warm Cravioo cream background
  static const Color backgroundLight = Color(0xFFFFF9F0);

  /// White cards and surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Soft green-tinted input background
  static const Color surfaceVariantLight = Color(0xFFF7FBEF);

  /// Card background
  static const Color cardLight = Color(0xFFFFFFFF);

  /// Main text
  static const Color textPrimaryLight = Color(0xFF17251A);

  /// Secondary text
  static const Color textSecondaryLight = Color(0xFF6B756D);

  /// Light border
  static const Color borderLight = Color(0xFFE5EDE6);

  /// Subtle border
  static const Color borderSubtle = Color(0xFFDDE8DF);

  /// Divider
  static const Color dividerLight = Color(0xFFE8EEE9);

  // ==================== DARK THEME ====================

  /// Deep green-black background
  static const Color backgroundDark = Color(0xFF101713);

  /// Dark surface
  static const Color surfaceDark = Color(0xFF18211B);

  /// Dark input / secondary surface
  static const Color surfaceVariantDark = Color(0xFF222D25);

  /// Dark card
  static const Color cardDark = Color(0xFF1A241D);

  /// Main dark text
  static const Color textPrimaryDark = Color(0xFFF4FFF5);

  /// Secondary dark text
  static const Color textSecondaryDark = Color(0xFFB7C5BA);

  /// Dark border
  static const Color borderDark = Color(0xFF344138);

  /// Dark container
  static const Color darkContainer = Color(0xFF29352D);

  /// Strong dark border
  static const Color darkBorder = Color(0xFF3B493F);

  // ==================== NEUTRALS ====================

  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF4F5F4);
  static const Color neutral200 = Color(0xFFE5E7E6);
  static const Color neutral300 = Color(0xFFD1D5D2);
  static const Color neutral400 = Color(0xFF9CA3A0);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);

  // ==================== STATUS COLORS ====================

  static const Color success = Color(0xFF22C55E);

  static const Color successLight = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFF59E0B);

  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFEF4444);

  static const Color errorLight = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF3B82F6);

  static const Color infoLight = Color(0xFFDBEAFE);

  // ==================== RATING ====================

  static const Color rating = Color(0xFFF59E0B);

  // ==================== ALPHA HELPERS ====================

  static Color primaryAlpha(double alpha) {
    return primary.withOpacity(alpha);
  }

  static Color primaryButtonAlpha(double alpha) {
    return primaryButton.withOpacity(alpha);
  }

  static Color successAlpha(double alpha) {
    return success.withOpacity(alpha);
  }

  static Color errorAlpha(double alpha) {
    return error.withOpacity(alpha);
  }
}
