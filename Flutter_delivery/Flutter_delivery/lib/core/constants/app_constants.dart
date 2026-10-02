import 'dart:io';

import 'package:food_user_application/features/language/domain/models/language_listing_model.dart';

class AppConstants {
  static const String title = 'Cravioo Delivery';
  static const String appFontFamily = 'Latin';

  static const String apiHost = 'https://cravioo.in';
  static const String baseUrl = '$apiHost/api/v1';

  static String resolveMediaUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:')) {
      return v;
    }
    final path = v.startsWith('/') ? v : '/$v';
    return '$apiHost$path';
  }

  static String firbaseApiKey = (Platform.isAndroid)
      ? "AIzaSyC-y1BzyqQ-LOEicca8cccWKJ4iws2EzAg"
      : "ios firebase api key";

  static String firebaseAppId = (Platform.isAndroid)
      ? "1:43975359947:android:b956e6bfaaa96f0e10ca4e"
      : "ios firebase app id";

  static String firebasemessagingSenderId = (Platform.isAndroid)
      ? "43975359947"
      : "ios firebase sender id";

  static String firebaseProjectId = (Platform.isAndroid)
      ? "cravioo-dc6f2"
      : "ios firebase project id";

  static String mapKey = (Platform.isAndroid)
      ? 'AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc'
      : 'your ios map key';

  static const String stripPublishKey = '';

  static List<LocaleLanguageList> languageList = [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.cravioo.delivery';
  static String signKey = '';

  static const String fontFamily = 'Latin';
}
