import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

const double _borderRadius = 22.0;
const double _buttonBorderRadius = 24.0;
const double _buttonHeight = 56.0;

/// Cravioo typography.
/// Poppins is used consistently throughout the app.
TextTheme _poppinsTextTheme(Brightness brightness) {
  final platformDefault =
      (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light())
          .textTheme;

  final base = GoogleFonts.poppinsTextTheme(platformDefault);

  return base.copyWith(
    displayLarge: base.displayLarge?.merge(AppTextStyles.h1),
    displayMedium: base.displayMedium?.merge(AppTextStyles.h2),
    displaySmall: base.displaySmall?.merge(AppTextStyles.h3),
    headlineMedium: base.headlineMedium?.merge(AppTextStyles.h4),
    bodyLarge: base.bodyLarge?.merge(AppTextStyles.bodyLarge),
    bodyMedium: base.bodyMedium?.merge(AppTextStyles.bodyMedium),
    bodySmall: base.bodySmall?.merge(AppTextStyles.bodySmall),
    labelLarge: base.labelLarge?.merge(AppTextStyles.button),
  );
}

/// ============================================================
/// LIGHT THEME — CRAVIOO
/// ============================================================

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // ----------------------------------------------------------
    // BASIC COLORS
    // ----------------------------------------------------------
    scaffoldBackgroundColor: AppColors.backgroundLight,

    primaryColor: AppColors.primary,

    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,

      secondary: AppColors.accent,
      onSecondary: Colors.white,

      tertiary: AppColors.secondary,
      onTertiary: AppColors.textPrimaryLight,

      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,

      error: AppColors.error,
      onError: Colors.white,
    ),

    // ----------------------------------------------------------
    // TEXT
    // ----------------------------------------------------------
    textTheme: _poppinsTextTheme(Brightness.light).apply(
      bodyColor: AppColors.textPrimaryLight,
      displayColor: AppColors.textPrimaryLight,
    ),

    // ----------------------------------------------------------
    // APP BAR
    // ----------------------------------------------------------
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimaryLight,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,

      iconTheme: IconThemeData(color: AppColors.textPrimaryLight),

      titleTextStyle: TextStyle(
        color: AppColors.textPrimaryLight,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ----------------------------------------------------------
    // ELEVATED BUTTON
    // ----------------------------------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: Colors.white,

        minimumSize: const Size(double.infinity, _buttonHeight),

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

        textStyle: AppTextStyles.button,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
        ),

        elevation: 0,

        shadowColor: Colors.transparent,

        overlayColor: AppColors.primary.withValues(alpha: 0.10),
      ),
    ),

    // ----------------------------------------------------------
    // TEXT BUTTON
    // ----------------------------------------------------------
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDeep,

        textStyle: AppTextStyles.button,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

        overlayColor: AppColors.primary.withValues(alpha: 0.08),
      ),
    ),

    // ----------------------------------------------------------
    // OUTLINED BUTTON
    // ----------------------------------------------------------
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDeep,

        minimumSize: const Size(double.infinity, _buttonHeight),

        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.65),
          width: 1.2,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
        ),

        textStyle: AppTextStyles.button,
      ),
    ),

    // ----------------------------------------------------------
    // CARD
    // ----------------------------------------------------------
    cardTheme: CardThemeData(
      color: AppColors.cardLight,

      elevation: 4,

      shadowColor: Colors.black.withValues(alpha: 0.07),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),

        side: const BorderSide(color: AppColors.borderLight, width: 0.6),
      ),

      clipBehavior: Clip.antiAlias,
    ),

    // ----------------------------------------------------------
    // INPUT FIELDS
    // ----------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,

      // White input over cream background
      fillColor: AppColors.surfaceLight,

      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.borderLight),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.borderLight),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: BorderSide(color: AppColors.primary, width: 1.8),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.error, width: 1.8),
      ),

      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondaryLight,
      ),

      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondaryLight,
      ),

      floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.primaryDeep,
        fontWeight: FontWeight.w600,
      ),

      prefixIconColor: AppColors.textSecondaryLight,

      suffixIconColor: AppColors.textSecondaryLight,
    ),

    // ----------------------------------------------------------
    // CHECKBOX
    // ----------------------------------------------------------
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return Colors.transparent;
      }),

      checkColor: WidgetStateProperty.all(Colors.white),

      side: BorderSide(color: AppColors.borderLight, width: 1.5),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),

    // ----------------------------------------------------------
    // SWITCH
    // ----------------------------------------------------------
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }

        return AppColors.neutral400;
      }),

      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return AppColors.neutral200;
      }),
    ),

    // ----------------------------------------------------------
    // RADIO
    // ----------------------------------------------------------
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return AppColors.neutral400;
      }),
    ),

    // ----------------------------------------------------------
    // PROGRESS INDICATOR
    // ----------------------------------------------------------
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),

    // ----------------------------------------------------------
    // BOTTOM NAVIGATION
    // ----------------------------------------------------------
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,

      selectedItemColor: AppColors.primary,

      unselectedItemColor: AppColors.textSecondaryLight,

      type: BottomNavigationBarType.fixed,

      elevation: 8,

      selectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),

      unselectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),

    // ----------------------------------------------------------
    // DIVIDER
    // ----------------------------------------------------------
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 1,
      space: 1,
    ),

    // ----------------------------------------------------------
    // CHIP
    // ----------------------------------------------------------
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.craviooGreenCream,

      selectedColor: AppColors.primaryTintStrong,

      disabledColor: AppColors.neutral100,

      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textPrimaryLight,
      ),

      secondaryLabelStyle: AppTextStyles.bodySmall.copyWith(
        color: AppColors.primaryDeep,
      ),

      side: const BorderSide(color: AppColors.borderSubtle),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ----------------------------------------------------------
    // SNACKBAR
    // ----------------------------------------------------------
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.neutral900,

      contentTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

      behavior: SnackBarBehavior.floating,
    ),

    // ----------------------------------------------------------
    // DIALOG
    // ----------------------------------------------------------
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLight,

      elevation: 8,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      titleTextStyle: GoogleFonts.poppins(
        color: AppColors.textPrimaryLight,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),

      contentTextStyle: GoogleFonts.poppins(
        color: AppColors.textSecondaryLight,
        fontSize: 14,
      ),
    ),
  );
}

/// ============================================================
/// DARK THEME — CRAVIOO
/// ============================================================

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // ----------------------------------------------------------
    // BASIC COLORS
    // ----------------------------------------------------------
    scaffoldBackgroundColor: AppColors.backgroundDark,

    primaryColor: AppColors.primary,

    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,

      secondary: AppColors.accent,
      onSecondary: Colors.white,

      tertiary: AppColors.secondary,
      onTertiary: Colors.white,

      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,

      error: AppColors.error,
      onError: Colors.white,
    ),

    // ----------------------------------------------------------
    // TEXT
    // ----------------------------------------------------------
    textTheme: _poppinsTextTheme(Brightness.dark).apply(
      bodyColor: AppColors.textPrimaryDark,
      displayColor: AppColors.textPrimaryDark,
    ),

    // ----------------------------------------------------------
    // APP BAR
    // ----------------------------------------------------------
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,

      iconTheme: IconThemeData(color: Colors.white),

      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ----------------------------------------------------------
    // BUTTON
    // ----------------------------------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: Colors.white,

        minimumSize: const Size(double.infinity, _buttonHeight),

        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),

        textStyle: AppTextStyles.button,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
        ),

        elevation: 0,

        shadowColor: Colors.transparent,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,

        textStyle: AppTextStyles.button,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,

        minimumSize: const Size(double.infinity, _buttonHeight),

        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.7),
          width: 1.2,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonBorderRadius),
        ),
      ),
    ),

    // ----------------------------------------------------------
    // CARD
    // ----------------------------------------------------------
    cardTheme: CardThemeData(
      color: AppColors.cardDark,

      elevation: 0,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_borderRadius),

        side: const BorderSide(color: AppColors.borderDark, width: 1),
      ),

      clipBehavior: Clip.antiAlias,
    ),

    // ----------------------------------------------------------
    // INPUT
    // ----------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,

      fillColor: AppColors.surfaceDark,

      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.borderDark),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.borderDark),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: BorderSide(color: AppColors.primary, width: 1.8),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),

        borderSide: const BorderSide(color: AppColors.error, width: 1.8),
      ),

      hintStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      ),

      labelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      ),

      floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.primaryLight,
        fontWeight: FontWeight.w600,
      ),

      prefixIconColor: AppColors.textSecondaryDark,

      suffixIconColor: AppColors.textSecondaryDark,
    ),

    // ----------------------------------------------------------
    // CHECKBOX
    // ----------------------------------------------------------
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return Colors.transparent;
      }),

      checkColor: WidgetStateProperty.all(Colors.white),

      side: const BorderSide(color: AppColors.darkBorder, width: 1.5),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),

    // ----------------------------------------------------------
    // SWITCH
    // ----------------------------------------------------------
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }

        return AppColors.neutral400;
      }),

      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryDeep;
        }

        return AppColors.darkContainer;
      }),
    ),

    // ----------------------------------------------------------
    // RADIO
    // ----------------------------------------------------------
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }

        return AppColors.neutral400;
      }),
    ),

    // ----------------------------------------------------------
    // PROGRESS
    // ----------------------------------------------------------
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),

    // ----------------------------------------------------------
    // BOTTOM NAVIGATION
    // ----------------------------------------------------------
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.backgroundDark,

      selectedItemColor: AppColors.primary,

      unselectedItemColor: AppColors.textSecondaryDark,

      type: BottomNavigationBarType.fixed,

      elevation: 8,

      selectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),

      unselectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),

    // ----------------------------------------------------------
    // DIVIDER
    // ----------------------------------------------------------
    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
      space: 1,
    ),

    // ----------------------------------------------------------
    // SNACKBAR
    // ----------------------------------------------------------
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardDark,

      contentTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

      behavior: SnackBarBehavior.floating,
    ),

    // ----------------------------------------------------------
    // DIALOG
    // ----------------------------------------------------------
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardDark,

      elevation: 8,

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

      titleTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),

      contentTextStyle: GoogleFonts.poppins(
        color: AppColors.textSecondaryDark,
        fontSize: 14,
      ),
    ),
  );
}
