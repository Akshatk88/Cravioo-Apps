import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class MapLauncher {
  MapLauncher._();

  static const _mapsPackage = 'com.google.android.apps.maps';

  /// Whether [lat]/[lng] look like a real destination (not missing / 0,0).
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat == 0 && lng == 0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Opens Google Maps turn-by-turn driving navigation to [lat],[lng].
  ///
  /// Android: `google.navigation:q=lat,lng&mode=d` straight into the Maps app
  /// (no canLaunchUrl gate — that returns false on Android 11+ whenever the
  /// scheme isn't declared in the manifest `<queries>`, which is why the button used to do
  /// nothing). Falls back to the Maps directions URL in any browser/Maps.
  ///
  /// Returns false when nothing could be opened so callers can tell the rider.
  static Future<bool> launchGoogleMaps(double lat, double lng) async {
    if (!isValidCoordinate(lat, lng)) return false;
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (Platform.isAndroid) {
      final navUri = 'google.navigation:q=$lat,$lng&mode=d';
      // 1. Google Maps app, turn-by-turn. 2. Any app handling the navigation
      // scheme. 3. Directions URL (Maps app or browser).
      for (final intent in [
        AndroidIntent(action: 'action_view', data: navUri, package: _mapsPackage),
        AndroidIntent(action: 'action_view', data: navUri),
      ]) {
        if (await _tryLaunch(intent)) return true;
      }
      try {
        if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) return true;
      } catch (e) {
        if (kDebugMode) debugPrint('[MapLauncher] web fallback failed: $e');
      }
      return _tryLaunch(AndroidIntent(action: 'action_view', data: webUri.toString()));
    }

    if (Platform.isIOS) {
      final appUri = Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving');
      try {
        if (await canLaunchUrl(appUri) &&
            await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {}
    }

    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryLaunch(AndroidIntent intent) async {
    try {
      if (await intent.canResolveActivity() != true) return false;
      await intent.launch();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[MapLauncher] intent ${intent.data} failed: $e');
      return false;
    }
  }
}
