import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String title = 'Cravioo Restaurant';

  /// Backend REST API base URL (all endpoints are mounted under `/api/v1`).
  static const String baseUrl = 'https://cravioo.in/api/v1';

  /// Socket.IO server base (same host, root path — see `Backend/socket-server.js`).
  static const String socketUrl = 'https://cravioo.in';

  static String firbaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyC-y1BzyqQ-LOEicca8cccWKJ4iws2EzAg"
      : "ios firebase api key";
  static String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:43975359947:android:142fc3e4f64bc01610ca4e"
      : "ios firebase app id";
  static String firebasemessagingSenderId = (kIsWeb || Platform.isAndroid)
      ? "43975359947"
      : "ios firebase sender id";
  static String firebaseProjectId = (kIsWeb || Platform.isAndroid)
      ? "cravioo-dc6f2"
      : "ios firebase project id";

  /// Google Maps API key (Maps SDK for Android/iOS + Geocoding API enabled).
  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  static const String stripPublishKey = '';

  static String packageName = 'com.cravioo.restaurant';
  static String signKey = '';
}
