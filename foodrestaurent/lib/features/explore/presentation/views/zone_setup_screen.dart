import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/features/zones/data/zone_repository.dart';
import 'package:food_user_application/features/zones/domain/zone_model.dart';

const _defaultCenter = LatLng(20.5937, 78.9629); // India

class ZoneSetupScreen extends ConsumerStatefulWidget {
  const ZoneSetupScreen({super.key});

  @override
  ConsumerState<ZoneSetupScreen> createState() => _ZoneSetupScreenState();
}

class _ZoneSetupScreenState extends ConsumerState<ZoneSetupScreen> {
  GoogleMapController? _mapController;
  LatLng? _pin;
  String _formattedAddress = '';
  bool _isLocating = false;
  bool _isSaving = false;
  String? _error;
  bool _initializedFromRestaurant = false;

  void _initializePin(RestaurantModel restaurant) {
    if (_initializedFromRestaurant) return;
    if (restaurant.pendingLatitude != null &&
        restaurant.pendingLongitude != null) {
      _pin = LatLng(restaurant.pendingLatitude!, restaurant.pendingLongitude!);
    } else if (restaurant.latitude != null && restaurant.longitude != null) {
      _pin = LatLng(restaurant.latitude!, restaurant.longitude!);
    }
    _formattedAddress = restaurant.fullAddress;
    _initializedFromRestaurant = true;
  }

  Future<void> _updatePin(LatLng position) async {
    setState(() => _pin = position);
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _formattedAddress = [
            p.street,
            p.locality,
            p.administrativeArea,
            p.postalCode,
          ].where((s) => (s ?? '').isNotEmpty).join(', ');
        });
      }
    } catch (_) {
      // Best-effort — the pin itself is still valid without a resolved address.
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are turned off.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _updatePin(LatLng(position.latitude, position.longitude));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save() async {
    final pin = _pin;
    if (pin == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile({
            'location': {
              'latitude': pin.latitude,
              'longitude': pin.longitude,
              'formattedAddress': _formattedAddress,
            },
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location update submitted.')),
        );
      }
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Failed to save location. Please try again.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);
    final zonesAsync = ref.watch(activeZonesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF191F2C),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Colors.orangeAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zone setup',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Pin your restaurant inside an active zone',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: restaurantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ApiException
                ? error.message
                : 'Failed to load restaurant.',
          ),
        ),
        data: (restaurant) {
          _initializePin(restaurant);
          return SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (restaurant.hasPendingLocationUpdate)
                        _buildPendingCard(context, restaurant),
                      if (restaurant.locationUpdateStatus == 'rejected' &&
                          restaurant.locationRejectionReason.isNotEmpty) ...[
                        _buildRejectedCard(context, restaurant),
                        const SizedBox(height: 16),
                      ],
                      _buildZonesCard(context, zonesAsync),
                      const SizedBox(height: 16),
                      _buildCurrentLocationCard(context, restaurant),
                      const SizedBox(height: 16),
                      _buildPinPanel(context),
                    ],
                  ),
                ),
                SizedBox(
                  height: 320,
                  child: zonesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _buildMap(context, const []),
                    data: (zones) => _buildMap(context, zones),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<ZoneModel> zones) {
    final center = _pin ?? _defaultCenter;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: _pin != null ? 15 : 4,
      ),
      onMapCreated: (c) => _mapController = c,
      onTap: _updatePin,
      markers: {
        if (_pin != null)
          Marker(
            markerId: const MarkerId('pin'),
            position: _pin!,
            draggable: true,
            onDragEnd: _updatePin,
          ),
      },
      polygons: {
        for (final zone in zones)
          if (zone.points.length >= 3)
            Polygon(
              polygonId: PolygonId(zone.id),
              points: zone.points.map((p) => LatLng(p.lat, p.lng)).toList(),
              fillColor: AppColors.primary.withValues(alpha: 0.15),
              strokeColor: AppColors.primary,
              strokeWidth: 2,
            ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildPendingCard(BuildContext context, RestaurantModel restaurant) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF8B4513),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Update pending approval',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF8B4513),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Requested: ${restaurant.pendingLatitude?.toStringAsFixed(5)}, ${restaurant.pendingLongitude?.toStringAsFixed(5)}. '
            'Customers still see your current approved address.',
            style: const TextStyle(
              color: Color(0xFF8B4513),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(BuildContext context, RestaurantModel restaurant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last update rejected: ${restaurant.locationRejectionReason}',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonesCard(
    BuildContext context,
    AsyncValue<List<ZoneModel>> zonesAsync,
  ) {
    final count = zonesAsync.value?.length ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF191F2C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SERVICE ZONES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Icon(
                Icons.near_me_outlined,
                color: Colors.orangeAccent,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count active zone${count == 1 ? '' : 's'} drawn on the map',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF262E3D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Blue shaded areas are admin service zones. Your pin must land inside a zone to save.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationCard(
    BuildContext context,
    RestaurantModel restaurant,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current approved location',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            restaurant.latitude != null
                ? '${restaurant.fullAddress}\n${restaurant.latitude!.toStringAsFixed(5)}, ${restaurant.longitude!.toStringAsFixed(5)}'
                : 'No location set yet.',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF4A5568),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Propose a new location',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Drag the pin on the map below, or use your current location. Saving sends this for admin review.',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF4A5568),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLocating ? null : _useCurrentLocation,
              icon: _isLocating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(_isLocating ? 'Locating...' : 'Use current location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          if (_pin != null) ...[
            const SizedBox(height: 12),
            Text(
              _formattedAddress.isNotEmpty
                  ? _formattedAddress
                  : '${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_pin == null || _isSaving) ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.save_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
              label: const Text(
                'Save location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF191F2C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
