import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

const double _borderRadius = 16.0;
const double _buttonBorderRadius = 30.0;
const double _buttonHeight = 56.0;
const String _fontFamily = 'ManropeVariable';

// ============================================================
// LIGHT THEME — CRAVIOO
// ============================================================

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  fontFamily: _fontFamily,

  scaffoldBackgroundColor: AppColors.backgroundLight,

  primaryColor: AppColors.primary,

  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,

    secondary: AppColors.primaryButton,
    onSecondary: Colors.white,

    surface: AppColors.surfaceLight,
    onSurface: AppColors.textPrimaryLight,

    error: AppColors.error,
    onError: Colors.white,
  ),

  // ==========================================================
  // TYPOGRAPHY
  // ==========================================================
  textTheme:
      const TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ).apply(
        fontFamily: _fontFamily,
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),

  // ==========================================================
  // APP BAR
  // ==========================================================
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.textPrimaryLight,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,

    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),

    iconTheme: IconThemeData(color: AppColors.textPrimaryLight, size: 24),
  ),

  // ==========================================================
  // ELEVATED BUTTON
  // ==========================================================
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButton,
      foregroundColor: Colors.white,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w800,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),

      elevation: 0,
      shadowColor: Colors.transparent,
    ),
  ),

  // ==========================================================
  // OUTLINED BUTTON
  // ==========================================================
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryDark,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      side: const BorderSide(color: AppColors.primary, width: 1.5),

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w800,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
    ),
  ),

  // ==========================================================
  // TEXT BUTTON
  // ==========================================================
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primaryDark,

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w700,
      ),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),

  // ==========================================================
  // PROGRESS INDICATOR
  // ==========================================================
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
    circularTrackColor: AppColors.primaryTint,
  ),

  // ==========================================================
  // CARD
  // ==========================================================
  cardTheme: CardThemeData(
    color: AppColors.cardLight,

    elevation: 0,

    margin: EdgeInsets.zero,

    shadowColor: Colors.black.withOpacity(0.04),

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),

      side: const BorderSide(color: AppColors.borderLight, width: 1),
    ),

    clipBehavior: Clip.antiAlias,
  ),

  // ==========================================================
  // INPUT FIELDS
  // ==========================================================
  inputDecorationTheme: InputDecorationTheme(
    filled: true,

    fillColor: AppColors.surfaceVariantLight,

    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    hintStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryLight,
    ),

    labelStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryLight,
    ),

    floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.primaryDark,
      fontWeight: FontWeight.w700,
    ),

    prefixIconColor: AppColors.textSecondaryLight,
    suffixIconColor: AppColors.textSecondaryLight,
  ),

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceLight,

    selectedItemColor: AppColors.primaryButton,

    unselectedItemColor: AppColors.textSecondaryLight,

    selectedLabelStyle: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),

    unselectedLabelStyle: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 12,
    ),

    type: BottomNavigationBarType.fixed,

    elevation: 8,
  ),

  // ==========================================================
  // CHIP
  // ==========================================================
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.primaryTint,

    labelStyle: AppTextStyles.bodySmall.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.primaryDeep,
      fontWeight: FontWeight.w700,
    ),

    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),

    side: BorderSide.none,
  ),

  // ==========================================================
  // SNACKBAR
  // ==========================================================
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,

    backgroundColor: AppColors.primaryDeep,

    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

    contentTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),

    elevation: 6,

    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),

  // ==========================================================
  // DIVIDER
  // ==========================================================
  dividerTheme: const DividerThemeData(
    color: AppColors.dividerLight,
    thickness: 1,
    space: 1,
  ),
);

// ============================================================
// DARK THEME — CRAVIOO
// ============================================================

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,

  fontFamily: _fontFamily,

  scaffoldBackgroundColor: AppColors.backgroundDark,

  primaryColor: AppColors.primary,

  colorScheme: const ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,

    secondary: AppColors.primaryLight,
    onSecondary: AppColors.backgroundDark,

    surface: AppColors.surfaceDark,
    onSurface: AppColors.textPrimaryDark,

    error: AppColors.error,
    onError: Colors.white,
  ),

  // ==========================================================
  // TYPOGRAPHY
  // ==========================================================
  textTheme:
      const TextTheme(
        displayLarge: AppTextStyles.h1,
        displayMedium: AppTextStyles.h2,
        displaySmall: AppTextStyles.h3,
        headlineMedium: AppTextStyles.h4,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.button,
      ).apply(
        fontFamily: _fontFamily,
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),

  // ==========================================================
  // APP BAR
  // ==========================================================
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundDark,

    foregroundColor: AppColors.textPrimaryDark,

    elevation: 0,

    scrolledUnderElevation: 0,

    surfaceTintColor: Colors.transparent,

    centerTitle: true,

    iconTheme: IconThemeData(color: AppColors.textPrimaryDark, size: 24),

    titleTextStyle: TextStyle(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryDark,
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
  ),

  // ==========================================================
  // ELEVATED BUTTON
  // ==========================================================
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryButton,
      foregroundColor: Colors.white,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w800,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),

      elevation: 0,
      shadowColor: Colors.transparent,
    ),
  ),

  // ==========================================================
  // OUTLINED BUTTON
  // ==========================================================
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryLight,

      minimumSize: const Size(double.infinity, _buttonHeight),

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

      side: const BorderSide(color: AppColors.primary, width: 1.5),

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w800,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonBorderRadius),
      ),
    ),
  ),

  // ==========================================================
  // TEXT BUTTON
  // ==========================================================
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primaryLight,

      textStyle: AppTextStyles.button.copyWith(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w700,
      ),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),

  // ==========================================================
  // PROGRESS INDICATOR
  // ==========================================================
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primary,
    circularTrackColor: AppColors.darkContainer,
  ),

  // ==========================================================
  // CARD
  // ==========================================================
  cardTheme: CardThemeData(
    color: AppColors.cardDark,

    elevation: 0,

    margin: EdgeInsets.zero,

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_borderRadius),

      side: const BorderSide(color: AppColors.borderDark, width: 1),
    ),

    clipBehavior: Clip.antiAlias,
  ),

  // ==========================================================
  // INPUT FIELDS
  // ==========================================================
  inputDecorationTheme: InputDecorationTheme(
    filled: true,

    fillColor: AppColors.surfaceVariantDark,

    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: BorderSide.none,
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),

    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),

    hintStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textSecondaryDark,
    ),

    labelStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.textPrimaryDark,
    ),

    floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.primaryLight,
      fontWeight: FontWeight.w700,
    ),

    prefixIconColor: AppColors.textSecondaryDark,
    suffixIconColor: AppColors.textSecondaryDark,
  ),

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceDark,

    selectedItemColor: AppColors.primary,

    unselectedItemColor: AppColors.textSecondaryDark,

    selectedLabelStyle: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: 12,
    ),

    unselectedLabelStyle: TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 12,
    ),

    type: BottomNavigationBarType.fixed,

    elevation: 8,
  ),

  // ==========================================================
  // CHIP
  // ==========================================================
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkContainer,

    labelStyle: AppTextStyles.bodySmall.copyWith(
      fontFamily: _fontFamily,
      color: AppColors.primaryLight,
      fontWeight: FontWeight.w700,
    ),

    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),

    side: BorderSide.none,
  ),

  // ==========================================================
  // SNACKBAR
  // ==========================================================
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,

    backgroundColor: AppColors.darkContainer,

    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

    contentTextStyle: const TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryDark,
    ),

    elevation: 6,

    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),

  // ==========================================================
  // DIVIDER
  // ==========================================================
  dividerTheme: const DividerThemeData(
    color: AppColors.borderDark,
    thickness: 1,
    space: 1,
  ),
);
