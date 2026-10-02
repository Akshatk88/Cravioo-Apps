import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// English + Hindi, the two languages the app ships with.
const List<Locale> supportedLocales = [Locale('en'), Locale('hi')];

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  static const _localeKey = 'app_locale';

  @override
  Locale build() {
    _loadLocale();
    return const Locale('en');
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);
    if (saved != null && supportedLocales.any((l) => l.languageCode == saved)) {
      state = Locale(saved);
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (!supportedLocales.any((l) => l.languageCode == languageCode)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, languageCode);
    state = Locale(languageCode);
  }
}
