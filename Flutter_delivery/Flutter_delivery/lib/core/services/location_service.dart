import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'location_disclosure.dart';

/// Streams GPS positions while the partner is online. On Android this runs
/// as a foreground service with a persistent notification (via geolocator's
/// `foregroundNotificationConfig`) so pings keep flowing when the app is
/// backgrounded; on iOS it relies on the `location` background mode.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _positionController = StreamController<Position>.broadcast();
  Position? lastPosition;

  Stream<Position> get positionStream => _positionController.stream;
  bool get isTracking => _positionSubscription != null;

  /// Asked as soon as the app starts (from the splash), so the rider grants
  /// location once, up front, instead of being stopped by permission prompts at
  /// the moment they tap "Go online". Never opens Settings from here and never
  /// throws; [ensurePermissions] still guards going online.
  Future<void> requestAtLaunch() async {
    try {
      var permission = await Geolocator.checkPermission();
      final needsPrompt = permission == LocationPermission.denied ||
          (Platform.isAndroid &&
              permission == LocationPermission.whileInUse &&
              !(await Permission.locationAlways.status).isGranted);
      // Play policy: the in-app disclosure must come before any system
      // location prompt. Declined -> nothing is requested.
      if (needsPrompt) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!await LocationDisclosure.ensure()) return;
      }
      if (permission == LocationPermission.denied) {
        // Give the notification-permission prompt FcmService raises at start
        // a moment to settle: two runtime-permission requests at once make the
        // second one fail or never answer.
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        try {
          permission = await Geolocator.requestPermission()
              .timeout(const Duration(seconds: 60));
        } catch (_) {
          // "Request already running" or no answer: try once more shortly.
          await Future<void>.delayed(const Duration(seconds: 3));
          permission = await Geolocator.requestPermission()
              .timeout(const Duration(seconds: 60));
        }
      }
      // Background location can only be asked for once foreground location is
      // granted; deliveries keep tracking while the app is in the background.
      if (Platform.isAndroid && permission == LocationPermission.whileInUse) {
        final background = await Permission.locationAlways.status;
        if (!background.isGranted && !background.isPermanentlyDenied) {
          await Permission.locationAlways.request()
              .timeout(const Duration(seconds: 60));
        }
      }
    } catch (_) {
      // A failed prompt must never block app start.
    }
  }

  Future<bool> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    // Play policy: show the location disclosure before any system prompt.
    final backgroundGranted =
        !Platform.isAndroid || (await Permission.locationAlways.status).isGranted;
    final disclosureOk = (permission != LocationPermission.denied && backgroundGranted)
        ? true
        : await LocationDisclosure.ensure();

    if (permission == LocationPermission.denied) {
      if (!disclosureOk) return false;
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return false;
      }
    }

    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return false;
    }

    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted && disclosureOk) {
        await Permission.locationAlways.request();
      }
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    return true;
  }

  void startTracking() {
    if (isTracking) return;

    final locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'You are online',
              notificationText: 'Sharing your live location for deliveries',
              enableWakeLock: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((pos) {
              lastPosition = pos;
              _positionController.add(pos);
            });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Injects a synthetic fix into the same stream real GPS updates flow
  /// through, so the map marker, the socket `update-location` broadcast, and
  /// the backend availability ping all react exactly as they would to a real
  /// movement. Backs the debug route simulator on [ActiveTripScreen], which
  /// lets testers exercise customer-side live tracking without physically
  /// travelling the route.
  void emitSimulatedPosition({
    required double latitude,
    required double longitude,
    double heading = 0,
    double speed = 0,
  }) {
    final pos = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: heading,
      headingAccuracy: 1,
      speed: speed,
      speedAccuracy: 0,
      isMocked: true,
    );
    lastPosition = pos;
    _positionController.add(pos);
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});
