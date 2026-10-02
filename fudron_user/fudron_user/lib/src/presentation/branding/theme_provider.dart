import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      if (savedTheme == 'Light') {
        state = ThemeMode.light;
      } else if (savedTheme == 'Dark') {
        state = ThemeMode.dark;
      } else {
        state = ThemeMode.system;
      }
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final String themeStr;
    switch (mode) {
      case ThemeMode.light:
        themeStr = 'Light';
        break;
      case ThemeMode.dark:
        themeStr = 'Dark';
        break;
      case ThemeMode.system:
        themeStr = 'System';
        break;
    }
    await prefs.setString(_themeKey, themeStr);
  }
}
