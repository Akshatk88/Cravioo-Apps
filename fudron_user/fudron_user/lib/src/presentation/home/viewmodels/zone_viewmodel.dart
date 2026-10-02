import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/zone_model.dart';
import '../../../di/catalog_providers.dart';
import '../../address/viewmodels/address_viewmodel.dart';

/// Detects the serviceable zone for the user's location.
///
/// Scopes all listings, restaurants, banners and search to the active zone.
/// If user is outside any active zone, [ZoneModel.isInService] is false.
final zoneViewModelProvider =
    AsyncNotifierProvider<ZoneViewModel, ZoneModel>(ZoneViewModel.new);

class ZoneViewModel extends AsyncNotifier<ZoneModel> {
  @override
  FutureOr<ZoneModel> build() {
    // Listen for changes in saved addresses (e.g. user adds address or changes default)
    ref.listen(addressViewModelProvider, (previous, next) {
      final prevDefault = (previous == null || previous.isEmpty)
          ? null
          : previous.firstWhere((a) => a.isDefault, orElse: () => previous.first);
      final nextDefault = next.isEmpty
          ? null
          : next.firstWhere((a) => a.isDefault, orElse: () => next.first);

      if (prevDefault?.id != nextDefault?.id ||
          prevDefault?.latitude != nextDefault?.latitude ||
          prevDefault?.longitude != nextDefault?.longitude) {
        unawaited(refresh());
      }
    });

    return _detect();
  }

  Future<ZoneModel> _detect() async {
    double? lat;
    double? lng;

    // 1. First priority: Check saved address coordinates
    final addresses = ref.read(addressViewModelProvider);
    final savedAddress = addresses.isEmpty
        ? null
        : addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);

    if (savedAddress != null &&
        savedAddress.latitude != null &&
        savedAddress.longitude != null &&
        savedAddress.latitude != 0 &&
        savedAddress.longitude != 0) {
      lat = savedAddress.latitude;
      lng = savedAddress.longitude;
    }

    // 2. Second priority: If no address coordinates, use live device GPS
    if (lat == null || lng == null) {
      final position = await _currentPosition();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    }

    // 3. If neither GPS nor saved address coordinates are available, mark out of service
    if (lat == null || lng == null) {
      return const ZoneModel(status: 'OUT_OF_SERVICE');
    }

    final repo = ref.read(catalogRemoteDataSourceProvider);
    try {
      return await repo.detectZone(lat: lat, lng: lng);
    } catch (_) {
      return const ZoneModel(status: 'OUT_OF_SERVICE');
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _detect());
  }
}

/// The zone id to scope catalog calls with, or null when undetected or out of service.
final currentZoneIdProvider = Provider<String?>((ref) {
  final zone = ref.watch(zoneViewModelProvider).value;
  if (zone != null && zone.isInService) {
    return zone.zoneId;
  }
  return null;
});
