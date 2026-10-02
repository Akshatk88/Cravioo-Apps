import 'package:flutter/material.dart';

/// Cravioo design tokens.
/// Fresh green + warm cream food-app theme.
class AppColors {
  // ==================== BRAND COLORS ====================

  // Main Cravioo green
  static Color primary = const Color(0xFF22C55E);

  // Darker green for buttons / important actions
  static Color primaryButton = const Color(0xFF16A34A);

  /// Secondary green accent
  static const Color secondary = Color(0xFF4ADE80);
  static const Color secondaryLight = Color(0xFF86EFAC);
  static const Color secondaryTint = Color(0xFFEAF9EF);

  /// Supporting accent
  static const Color accent = Color(0xFF10B981);
  static const Color accentBright = Color(0xFF34D399);
  static const Color accentLight = Color(0xFF6EE7B7);
  static const Color accentDeep = Color(0xFF059669);
  static const Color accentDark = Color(0xFF047857);

  static const Color accentTint = Color(0xFFE8F8F1);
  static const Color accentTintStrong = Color(0xFFCFF3E2);
  static const Color accentTintDark = Color(0xFF0B3025);

  /// Neutral brand color
  static const Color brandNeutral = Color(0xFF58585B);

  // ==================== CRAVIOO BRAND GRADIENT ====================

  static const List<Color> brandGradient = [
    Color(0xFF34D399),
    Color(0xFF22C55E),
    Color(0xFF16A34A),
  ];

  /// Two-stop green ramp
  static const List<Color> brandGradientShort = [
    Color(0xFF22C55E),
    Color(0xFF16A34A),
  ];

  // ==================== DERIVED BRAND SHADES ====================

  static HSLColor get _hsl => HSLColor.fromColor(primary);

  static Color _shade(double lightness, double saturation) =>
      _hsl.withLightness(lightness).withSaturation(saturation).toColor();

  static Color get primaryLight => _shade(0.62, _hsl.saturation);

  static Color get primaryDeep => _shade(0.42, _hsl.saturation);

  static Color get primaryDeepText =>
      _shade(0.30, (_hsl.saturation * 0.85).clamp(0.0, 0.9));

  static Color get primaryTint =>
      _shade(0.96, (_hsl.saturation * 0.9).clamp(0.0, 1.0));

  static Color get primaryTintStrong =>
      _shade(0.91, (_hsl.saturation * 0.9).clamp(0.0, 1.0));

  static Color get primarySoft =>
      _shade(0.80, (_hsl.saturation * 0.9).clamp(0.0, 1.0));

  static Color get primaryTintDark =>
      _shade(0.12, (_hsl.saturation * 0.35).clamp(0.0, 0.45));

  static Color get primaryTintDarkStrong =>
      _shade(0.20, (_hsl.saturation * 0.4).clamp(0.0, 0.5));

  static Color primaryAlpha(double alpha) => primary.withValues(alpha: alpha);

  // ==================== NEUTRAL SCALE ====================

  static const Color neutral50 = Color(0xFFFAFAF8);
  static const Color neutral100 = Color(0xFFF5F5F0);
  static const Color neutral200 = Color(0xFFE7E7DF);
  static const Color neutral300 = Color(0xFFD6D6CC);
  static const Color neutral400 = Color(0xFFA5A59A);
  static const Color neutral500 = Color(0xFF73736A);
  static const Color neutral600 = Color(0xFF55554E);
  static const Color neutral700 = Color(0xFF3F3F39);
  static const Color neutral900 = Color(0xFF171713);

  // ==================== CRAVIOO CREAM COLORS ====================

  /// Main cream background matching the Cravioo splash/login artwork.
  static const Color craviooCream = Color(0xFFFFF8E8);

  /// Slightly darker cream
  static const Color craviooCreamDark = Color(0xFFFFF1D6);

  /// Very soft green-cream surface
  static const Color craviooGreenCream = Color(0xFFF2F8DF);

  /// Soft botanical background
  static const Color craviooSoftGreen = Color(0xFFEAF4D4);

  // ==================== DARK THEME COLORS ====================

  static const Color backgroundDark = Color(0xFF101812);
  static const Color surfaceDark = Color(0xFF172019);
  static const Color cardDark = Color(0xFF202A21);
  static const Color darkContainer = Color(0xFF283329);
  static const Color darkBorder = Color(0xFF3B473D);

  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA7B0A8);
  static const Color borderDark = Color(0xFF303B32);

  // ==================== LIGHT THEME COLORS ====================

  /// Cravioo cream instead of plain grey/white.
  static const Color backgroundLight = craviooCream;

  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color secondarySurfaceLight = Color(0xFFF5F8F0);

  static const Color lightContainer = Color(0xFFFFFBF2);

  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color lightGreyBg = Color(0xFFF5F5EF);

  static const Color textPrimaryLight = neutral900;

  static const Color textDark = neutral900;

  static const Color textSecondaryLight = neutral500;

  static const Color textTertiaryLight = neutral400;

  static const Color borderLight = Color(0xFFE5E7DF);

  static const Color borderSubtle = Color(0xFFE7E9E0);

  static const Color borderExtraSubtle = Color(0xFFF0F1EB);

  static const Color dividerLight = Color(0xFFEDEFE8);

  static const Color disabled = neutral300;

  static const Color onDisabled = neutral500;

  static const Color shadow1 = Color(0x14000000);

  static const Color shadow2 = Color(0x0A000000);

  // ==================== STATUS COLORS ====================

  static const Color success = Color(0xFF16A34A);
  static const Color successDeep = Color(0xFF0F7A37);
  static const Color successSoft = Color(0xFFE7F7EE);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF4E3);

  static const Color error = Color(0xFFE11D48);
  static const Color errorDeep = Color(0xFFBE123C);
  static const Color errorSoft = Color(0xFFFDE9EE);

  static const Color rating = Color(0xFFFFB01D);
  static const Color ratingStar = Color(0xFFFFB01D);

  static const Color veg = Color(0xFF16A34A);
  static const Color nonVeg = Color(0xFFDC2626);

  // ==================== COMPATIBILITY ACCENTS ====================

  static const Color accentPurple = secondary;
  static const Color accentPink = Color(0xFF22C55E);
  static const Color accentBlue = accent;
}
