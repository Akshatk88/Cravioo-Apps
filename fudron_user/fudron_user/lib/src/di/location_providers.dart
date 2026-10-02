import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/location/location_service.dart';
import '../presentation/address/viewmodels/address_viewmodel.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Where the user is, for anything that only needs coordinates.
///
/// Live GPS is deliberately not used here: it prompts for permission and can
/// block for seconds, which is far too heavy for decorating a screen with a
/// distance. The chain is last-known fix, then the saved delivery address —
/// which for a delivery app is arguably the better origin anyway, since it is
/// where the food is actually going.
///
/// Null when neither is available; callers must treat distance as unknown
/// rather than showing 0.
final userLatLngProvider = FutureProvider<({double lat, double lng})?>((ref) async {
  // Hard time budget. Callers await this before fetching restaurants, so
  // anything that stalls here stalls the whole list behind skeletons — which is
  // what happened when the address fetch sat on a 401 while logged out.
  // Distance is decoration; the menu is not. Never block the list on it.
  try {
    return await _resolveLatLng(ref).timeout(const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
});

Future<({double lat, double lng})?> _resolveLatLng(Ref ref) async {
  final here = await ref.read(locationServiceProvider).lastKnownLatLng();
  if (here != null) return here;

  // AddressViewModel.build() returns an empty list and loads in the background,
  // so defaultAddress is null until that lands.
  final addresses = ref.read(addressViewModelProvider.notifier);
  if (ref.read(addressViewModelProvider).isEmpty) {
    await addresses.load();
  }
  final saved = addresses.defaultAddress;
  final lat = saved?.latitude;
  final lng = saved?.longitude;
  return (lat != null && lng != null) ? (lat: lat, lng: lng) : null;
}
