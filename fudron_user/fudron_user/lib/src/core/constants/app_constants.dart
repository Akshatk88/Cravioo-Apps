import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocaleLanguageList {
  final String name;
  final String lang;
  final String? flag;

  const LocaleLanguageList({required this.name, required this.lang, this.flag});
}

/// Central App Constants for Fudron User Application.
class AppConstants {
  const AppConstants._();

  static const String title = 'Fudron';
  static const String appName = 'Fudron';

  /// Merchant name shown on the Razorpay checkout sheet.
  ///
  /// Without this Razorpay falls back to the legal entity registered on the
  /// account ("SWITCHEATS PRIVATE LIMITED"), which is not our consumer brand.
  static const String brandName = 'Cravioo';

  /// Public logo URL for the Razorpay sheet. Razorpay fetches this over the
  /// network, so a bundled asset cannot be used — it must be a hosted URL.
  /// Falls back to the backend's configured business logo when set.
  static const String brandLogoUrl = String.fromEnvironment('BRAND_LOGO_URL');
  static const String appVersion = '1.0.0';

  /// Backend REST API host domain.
  static const String hostUrl = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://cravioo.in',
  );

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$hostUrl/api/v1',
  );

  /// Socket.IO server URL.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: hostUrl,
  );

  /// Firebase project configuration for User App (com.cravioo.user).
  static String firebaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyC-y1BzyqQ-LOEicca8cccWKJ4iws2EzAg"
      : "ios firebase api key";

  static String get firbaseApiKey => firebaseApiKey;

  static String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:43975359947:android:c84a8dbd424533c310ca4e"
      : "ios firebase app id";

  static String firebaseMessagingSenderId = (kIsWeb || Platform.isAndroid)
      ? "43975359947"
      : "ios firebase sender id";

  static String get firebasemessagingSenderId => firebaseMessagingSenderId;

  static String firebaseProjectId = (kIsWeb || Platform.isAndroid)
      ? "cravioo-dc6f2"
      : "ios firebase project id";

  static String firebaseDatabaseUrl =
      "https://cravioo-dc6f2-default-rtdb.asia-southeast1.firebasedatabase.app";

  /// Google Maps API key (Maps SDK + Geocoding API).
  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  /// Payment Gateway keys.
  static const String stripePublishKey = '';
  static const String stripPublishKey = stripePublishKey;
  static String razorpayKey = '';

  /// Supported App Languages.
  static List<LocaleLanguageList> languageList = const [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.cravioo.user';
  static String signKey = '';
}
