import 'package:flutter/material.dart';
import 'package:food_user_application/core/constants/app_constants.dart';

class AppTheme {
  // CRAVIOO COLORS
  static const Color primaryColor = Color(0xFF22C55E);
  static const Color primaryButton = Color(0xFF16A34A);

  static const Color lightBackground = Color(0xFFFFF9F0);
  static const Color darkBackground = Color(0xFF101713);

  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1A241D);

  static const Color lightNavBackground = Color(0xFFFFFFFF);
  static const Color darkNavBackground = Color(0xFF18211B);

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: AppConstants.appFontFamily,
      brightness: Brightness.light,

      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBackground,

      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: primaryButton,
        onSecondary: Colors.white,
        surface: lightCard,
        onSurface: Color(0xFF17251A),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: Color(0xFF17251A),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF17251A)),
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.appFontFamily,
          color: Color(0xFF17251A),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightNavBackground,
        selectedItemColor: primaryButton,
        unselectedItemColor: Color(0xFF6B756D),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      fontFamily: AppConstants.appFontFamily,
      brightness: Brightness.dark,

      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackground,

      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: Color(0xFF4ADE80),
        onSecondary: darkBackground,
        surface: darkCard,
        onSurface: Color(0xFFF4FFF5),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Color(0xFFF4FFF5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF4FFF5)),
        titleTextStyle: TextStyle(
          fontFamily: AppConstants.appFontFamily,
          color: Color(0xFFF4FFF5),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkNavBackground,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFFB7C5BA),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
