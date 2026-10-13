import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map marker for the rider: the top-down bike image (assets/image/bike.png,
/// tall 632x1499 with transparent background).
///
/// The old loader resized by *width* in physical pixels without telling the
/// map the image's pixel ratio, so the tall image became a huge marker. This
/// renders it at [logicalWidth] logical px (aspect ratio kept) at the device's
/// pixel density and passes that density to the map, so it is the same
/// on-screen size on every phone.
class RiderMarker {
  RiderMarker._();

  static const String asset = 'assets/image/bike.png';
  static const double logicalWidth = 14;

  static final Map<double, BitmapDescriptor> _cache = {};

  /// The bike image is used for every two-wheeler type (bike, scooter,
  /// motorcycle, cycle, unknown…); only four-wheelers keep the default dot.
  static bool suitsVehicle(String? vehicleType) {
    final v = (vehicleType ?? '').toLowerCase();
    return !(v.contains('car') || v.contains('four') || v.contains('van'));
  }

  static Future<BitmapDescriptor> load(double devicePixelRatio) async {
    final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final cached = _cache[dpr];
    if (cached != null) return cached;

    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: (logicalWidth * dpr).round(), // height follows aspect ratio
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
    _cache[dpr] = descriptor;
    return descriptor;
  }
}

/// Smooths the rider's heading for marker rotation.
///
/// Uses the GPS course (Position.heading) only while actually moving — when
/// stationary Android reports 0, which would snap the bike to face north —
/// otherwise the bearing between consecutive fixes once the rider has moved a
/// few metres; otherwise keeps the last heading.
class RiderHeadingTracker {
  double heading = 0;
  Position? _previous;

  /// Feeds a new fix; returns true when [heading] changed.
  bool update(Position position) {
    double? next;
    final moving = position.speed.isFinite && position.speed > 1.0;
    if (moving && position.heading.isFinite && position.heading >= 0) {
      next = position.heading;
    }

    final prev = _previous;
    if (prev == null) {
      _previous = position;
    } else {
      final moved = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        position.latitude,
        position.longitude,
      );
      if (moved > 3) {
        if (next == null) {
          final bearing = Geolocator.bearingBetween(
            prev.latitude,
            prev.longitude,
            position.latitude,
            position.longitude,
          );
          next = bearing < 0 ? bearing + 360 : bearing;
        }
        _previous = position;
      }
      // Under 3 m: keep the older anchor so GPS jitter accumulates into a
      // real movement instead of spinning the marker.
    }

    if (next == null) return false;
    final changed = (next - heading).abs() > 0.5;
    heading = next;
    return changed;
  }
}
