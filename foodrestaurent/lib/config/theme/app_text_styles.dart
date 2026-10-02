import 'package:flutter/material.dart';

/// ============================================================
/// CRAVIOO — APP TEXT STYLES
/// ============================================================
///
/// Centralized typography for the complete Cravioo application.
/// Font family is applied globally from ThemeData.
///
/// Style direction:
/// - Bold and clean headings
/// - Comfortable body text
/// - Strong CTA/button typography
/// - Good readability on both light and dark themes
/// ============================================================

class AppTextStyles {
  // ============================================================
  // HEADINGS
  // ============================================================

  /// Main page / hero heading
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// Section heading
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Sub-section heading
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Small heading
  static const TextStyle h4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.1,
  );

  // ============================================================
  // BODY TEXT
  // ============================================================

  /// Main readable paragraph text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
  );

  /// Normal application text
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: 0,
  );

  /// Small supporting text
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.05,
  );

  // ============================================================
  // COMPONENTS
  // ============================================================

  /// Primary buttons / CTA
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Small labels
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0.1,
  );

  /// Small metadata / captions
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
  );

  /// Strong caption / status text
  static const TextStyle captionBold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.2,
  );
}
