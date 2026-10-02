import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/back_navigation.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/address_model.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/utils/map_styles.dart';

import '../../../di/location_providers.dart';
import '../../../platform/location/location_service.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/address_viewmodel.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../home/viewmodels/near_you_viewmodel.dart';
import '../../home/viewmodels/zone_viewmodel.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  bool _useAccountDetails = true;
  String get _accountName => ref.read(authViewModelProvider).value?.displayName ?? '';
  String get _accountPhone => ref.read(authViewModelProvider).value?.phone ?? '';

  String _selectedType = 'Home'; // 'Home', 'Office', 'Other'
  bool _isDetectingLocation = false;
  bool _isSaving = false;
  String? _editingAddressId;

  double? _latitude;
  double? _longitude;

  GoogleMapController? _mapController;
  CameraPosition? _lastCameraPosition;

  final _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = const [];
  bool _isSearching = false;

  /// Debounces keystrokes so a search fires per pause, not per character.
  Timer? _searchDebounce;

  /// True while a camera move is being reverse-geocoded, so the card can say so
  /// instead of showing a stale address under a pin that has already moved.
  bool _isResolvingPin = false;

  /// Guards against reverse-geocoding our own programmatic camera moves — after
  /// "use current location" we already have the address and re-resolving it would
  /// overwrite fields the user may have just corrected by hand.
  bool _suppressNextIdle = false;

  /// Whether the map has been pointed at somewhere real — a GPS fix, a search
  /// result, or an address being edited — rather than still sitting on the
  /// zoomed-out starting view. Until then a settled pin means nothing.
  bool _hasRealMapPosition = false;

  /// Only used until the first real fix arrives, so the map has something to open
  /// on. Deliberately zoomed out: it is a starting view, not a claim about where
  /// the user is.
  static const _initialCamera = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );

  final _buildingController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _saveAsController = TextEditingController(text: 'Home');
  final _instructionsController = TextEditingController();
  String _latestFetchedFullAddress = '';

  @override
  void initState() {
    super.initState();
    _buildingController.addListener(() => setState(() {}));
    _areaController.addListener(() => setState(() {}));
    _saveAsController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _stateController.addListener(() => setState(() {}));
    _pincodeController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final existing = ref.read(addressViewModelProvider);
      final hasHome = existing.any((a) => a.type.toLowerCase() == 'home');
      final hasOffice = existing.any((a) => a.type.toLowerCase() == 'office' || a.type.toLowerCase() == 'work');

      if (hasHome && !hasOffice) {
        setState(() {
          _selectedType = 'Office';
          _saveAsController.text = 'Office';
        });
      } else if (hasHome && hasOffice) {
        setState(() {
          _selectedType = 'Other';
          _saveAsController.text = existing.length >= 2 ? 'Other ${existing.length + 1}' : 'Other';
        });
      }
    });
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _saveAsController.dispose();
    _instructionsController.dispose();
    _mapController?.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    Haptics.medium();
    setState(() => _isDetectingLocation = true);

    final locationService = ref.read(locationServiceProvider);
    final result = await locationService.getCurrentLocationAndAddress();

    if (!mounted) return;
    setState(() => _isDetectingLocation = false);

    if (result.isServiceDisabled) {
      _showPermissionDialog(
        title: 'Location Services Disabled',
        message: result.error ?? 'Please turn on GPS location services on your device.',
        onOpenSettings: Geolocator.openLocationSettings,
      );
      return;
    }

    if (result.isPermanentlyDenied) {
      _showPermissionDialog(
        title: 'Location Permission Needed',
        message: 'Location access is permanently denied. Please enable location permissions in App Settings.',
        onOpenSettings: Geolocator.openAppSettings,
      );
      return;
    }

    if (result.isPermissionDenied || !result.isSuccess) {
      AppSnackbar.error(
        context,
        result.error ?? 'Could not detect current location. Please try again.',
      );
      return;
    }

    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _latestFetchedFullAddress = result.fullAddress;
      if (result.building.isNotEmpty) _buildingController.text = result.building;
      if (result.street.isNotEmpty) _streetController.text = result.street;
      if (result.area.isNotEmpty) _areaController.text = result.area;
      if (result.city.isNotEmpty) _cityController.text = result.city;
      if (result.state.isNotEmpty) _stateController.text = result.state;
      if (result.pincode.isNotEmpty) _pincodeController.text = result.pincode;
    });

    // The fields are already filled from this fix, so skip the idle handler that
    // would otherwise re-resolve the very same point.
    final lat = result.latitude;
    final lng = result.longitude;
    if (lat != null && lng != null) {
      _suppressNextIdle = true;
      await _moveCameraTo(lat, lng);
    }

    Haptics.success();
    if (!mounted) return;
    AppSnackbar.success(
      context,
      'Current location detected!',
      duration: const Duration(seconds: 1),
    );

    // Automatically save address card (without duplicates) and return to home screen
    await _saveDetectedLocationAndGoHome();
  }

  static String buildDeduplicatedAddress({
    String? fullFetchedAddress,
    required String building,
    required String street,
    required String area,
    required String city,
    required String state,
    required String zipCode,
  }) {
    if (fullFetchedAddress != null && fullFetchedAddress.trim().isNotEmpty) {
      final base = fullFetchedAddress.trim();
      final bldg = building.trim();
      if (bldg.isNotEmpty &&
          !base.toLowerCase().startsWith(bldg.toLowerCase()) &&
          !base.toLowerCase().contains(bldg.toLowerCase())) {
        return '$bldg, $base';
      }
      return base;
    }

    final rawList = [building, street, area, city, state, zipCode];
    final cleanSegments = <String>[];

    for (final raw in rawList) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;

      final tokens = trimmed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
      for (final token in tokens) {
        final lower = token.toLowerCase();
        final exists = cleanSegments.any((s) {
          final sLower = s.toLowerCase();
          return sLower == lower;
        });
        if (!exists) {
          cleanSegments.add(token);
        }
      }
    }

    return cleanSegments.isNotEmpty ? cleanSegments.join(', ') : 'Delivery Address';
  }

  Future<void> _saveDetectedLocationAndGoHome() async {
    final isLoggedIn = ref.read(authViewModelProvider).value != null;
    if (!isLoggedIn) {
      if (!mounted) return;
      await ref.read(zoneViewModelProvider.notifier).refresh();
      ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants();
      ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
      if (!mounted) return;
      AppSnackbar.success(context, 'Location set to current position!');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteNames.home);
      }
      return;
    }

    final buildingText = _buildingController.text.trim();
    final streetText = _streetController.text.trim();
    final areaText = _areaController.text.trim();
    final cityText = _cityController.text.trim();
    final stateText = _stateController.text.trim();
    final zipText = _pincodeController.text.trim();

    final fullAddress = buildDeduplicatedAddress(
      fullFetchedAddress: _latestFetchedFullAddress,
      building: buildingText,
      street: streetText,
      area: areaText,
      city: cityText,
      state: stateText,
      zipCode: zipText,
    );

    final effectiveStreet = streetText.isNotEmpty
        ? streetText
        : (buildingText.isNotEmpty
            ? buildingText
            : (areaText.isNotEmpty ? areaText : 'Current Location'));

    final effectiveCity = cityText.isNotEmpty ? cityText : 'Indore';
    final effectiveState = stateText.isNotEmpty ? stateText : 'Madhya Pradesh';

    final currentLat = _latitude ?? 22.7196;
    final currentLng = _longitude ?? 75.8577;

    // DEDUPLICATION: Check if this address already exists
    final existingList = ref.read(addressViewModelProvider);
    AddressModel? duplicate;
    for (final addr in existingList) {
      if (addr.latitude != null && addr.longitude != null) {
        final dLat = (addr.latitude! - currentLat).abs();
        final dLng = (addr.longitude! - currentLng).abs();
        if (dLat < 0.0005 && dLng < 0.0005) {
          duplicate = addr;
          break;
        }
      }
      if (addr.fullAddress.trim().isNotEmpty &&
          addr.fullAddress.trim().toLowerCase() == fullAddress.trim().toLowerCase()) {
        duplicate = addr;
        break;
      }
      if (streetText.isNotEmpty &&
          cityText.isNotEmpty &&
          addr.street.trim().toLowerCase() == streetText.toLowerCase() &&
          addr.city.trim().toLowerCase() == cityText.toLowerCase()) {
        duplicate = addr;
        break;
      }
    }

    setState(() => _isSaving = true);
    try {
      if (duplicate != null) {
        // Already exists: Set as default active address without adding duplicate card
        await ref.read(addressViewModelProvider.notifier).setDefaultAddress(duplicate.id);
      } else {
        final hasHome = existingList.any((a) => a.type.toLowerCase() == 'home');
        final hasWork = existingList.any((a) => a.type.toLowerCase() == 'office' || a.type.toLowerCase() == 'work');
        String chosenType = 'Home';
        if (hasHome && !hasWork) {
          chosenType = 'Office';
        } else if (hasHome && hasWork) {
          chosenType = 'Other';
        }

        final title = chosenType == 'Other'
            ? (areaText.isNotEmpty ? areaText : 'Current Location')
            : chosenType;

        final newAddress = AddressModel(
          id: '',
          title: title,
          fullAddress: fullAddress,
          type: chosenType,
          building: buildingText,
          street: effectiveStreet,
          city: effectiveCity,
          state: effectiveState,
          zipCode: zipText,
          latitude: currentLat,
          longitude: currentLng,
          contactName: _useAccountDetails ? _accountName : null,
          contactPhone: _useAccountDetails ? _accountPhone : null,
        );

        final added = await ref.read(addressViewModelProvider.notifier).addAddress(newAddress);
        if (added) {
          final updatedList = ref.read(addressViewModelProvider);
          if (updatedList.isNotEmpty) {
            final created = updatedList.firstWhere(
              (a) => a.latitude == currentLat && a.longitude == currentLng,
              orElse: () => updatedList.last,
            );
            await ref.read(addressViewModelProvider.notifier).setDefaultAddress(created.id);
          }
        }
      }

      await ref.read(addressViewModelProvider.notifier).load();
      await ref.read(zoneViewModelProvider.notifier).refresh();
      ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants();
      ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);

      Haptics.success();
      if (!mounted) return;
      AppSnackbar.success(
        context,
        duplicate != null
            ? 'Existing address selected as current location!'
            : 'Location saved and selected!',
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteNames.home);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Keeps the clear button in step with the field; the branches below only
    // rebuild after the debounce fires, which is too late to feel responsive.
    setState(() {});
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await ref.read(locationServiceProvider).searchPlaces(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    Haptics.light();
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _searchController.text = suggestion.description;
    });
    // Let the camera settle and the idle handler reverse-geocode it, so the
    // fields are filled from the same point the pin ends on rather than from the
    // search string.
    await _moveCameraTo(suggestion.latitude, suggestion.longitude);
  }

  /// The single funnel for pointing the map at a real place — GPS fix, search
  /// result, or an address being edited. Marking the flag here rather than at
  /// each caller means a new way of moving the map cannot forget to.
  Future<void> _moveCameraTo(double lat, double lng) async {
    final controller = _mapController;
    if (controller == null) return;
    _hasRealMapPosition = true;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 17),
      ),
    );
  }

  /// Reverse-geocodes wherever the pin now sits and refills the address fields.
  ///
  /// The pin is fixed to the centre of the map and the map moves underneath it —
  /// the same interaction Zomato and Swiggy use. It is far steadier on a phone
  /// than dragging a small marker with a thumb that covers it.
  Future<void> _onPinSettled(CameraPosition position) async {
    if (_suppressNextIdle) {
      _suppressNextIdle = false;
      return;
    }

    // The map fires an idle event the moment it finishes loading, before any GPS
    // fix or search has moved it — so this handler used to run against
    // _initialCamera, the centre of India. It saved (20.5937, 78.9629) as the
    // delivery point and reverse-geocoded it, filling city/state with a village
    // in Maharashtra that the customer had never heard of. The order then
    // measured ~500 km from the restaurant, and riders were offered it with that
    // distance attached.
    //
    // The starting view is a view, not a choice. Nothing is recorded until the
    // map has been moved somewhere real.
    if (!_hasRealMapPosition) return;

    final lat = position.target.latitude;
    final lng = position.target.longitude;
    setState(() {
      _latitude = lat;
      _longitude = lng;
      _isResolvingPin = true;
    });

    final result = await ref.read(locationServiceProvider).reverseGeocode(lat, lng);
    if (!mounted) return;

    setState(() {
      _isResolvingPin = false;
      _latestFetchedFullAddress = result.fullAddress;
      // Only overwrite what the lookup actually resolved, so a field the user
      // typed by hand is not blanked by a sparse result.
      if (result.building.isNotEmpty) _buildingController.text = result.building;
      if (result.street.isNotEmpty) _streetController.text = result.street;
      if (result.area.isNotEmpty) _areaController.text = result.area;
      if (result.city.isNotEmpty) _cityController.text = result.city;
      if (result.state.isNotEmpty) _stateController.text = result.state;
      if (result.pincode.isNotEmpty) _pincodeController.text = result.pincode;
    });
  }

  void _showPermissionDialog({
    required String title,
    required String message,
    required Future<bool> Function() onOpenSettings,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onOpenSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _validateAndSave() {
    final buildingText = _buildingController.text.trim();
    final streetText = _streetController.text.trim();
    final areaText = _areaController.text.trim();
    final cityText = _cityController.text.trim();
    final stateText = _stateController.text.trim();
    final zipText = _pincodeController.text.trim();

    if (buildingText.isEmpty && areaText.isEmpty && streetText.isEmpty) {
      AppSnackbar.error(context, 'Please enter building name, street or area');
      return;
    }
    if (cityText.isEmpty) {
      AppSnackbar.error(context, 'Please enter your city');
      return;
    }
    if (stateText.isEmpty) {
      AppSnackbar.error(context, 'Please enter your state');
      return;
    }
    final pincodeErr = Validators.pincode(zipText);
    if (pincodeErr != null) {
      AppSnackbar.error(context, pincodeErr);
      return;
    }

    _saveAddress();
  }

  Future<void> _saveAddress() async {
    Haptics.light();
    final isLoggedIn = ref.read(authViewModelProvider).value != null;
    if (!isLoggedIn) {
      AppSnackbar.info(context, 'Please log in to save your address');
      context.push('${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.addAddress)}');
      return;
    }

    final savedName = _saveAsController.text.trim().isNotEmpty
        ? _saveAsController.text.trim()
        : _selectedType;

    final buildingText = _buildingController.text.trim();
    final streetText = _streetController.text.trim();
    final areaText = _areaController.text.trim();
    final cityText = _cityController.text.trim();
    final stateText = _stateController.text.trim();
    final zipText = _pincodeController.text.trim();

    if (buildingText.isEmpty && areaText.isEmpty && streetText.isEmpty) {
      AppSnackbar.error(context, 'Please enter building name, street or area');
      return;
    }
    if (cityText.isEmpty) {
      AppSnackbar.error(context, 'Please enter your city');
      return;
    }
    if (stateText.isEmpty) {
      AppSnackbar.error(context, 'Please enter your state');
      return;
    }
    final invalid = Validators.pincode(zipText);
    if (invalid != null) {
      AppSnackbar.error(context, invalid);
      return;
    }

    final fullAddress = buildDeduplicatedAddress(
      fullFetchedAddress: _latestFetchedFullAddress,
      building: buildingText,
      street: streetText,
      area: areaText,
      city: cityText,
      state: stateText,
      zipCode: zipText,
    );

    setState(() => _isSaving = true);

    var latitude = _latitude;
    var longitude = _longitude;

    // Multi-tier geocoding fallback to ensure coordinates are never null.
    if ((latitude == null || longitude == null) && fullAddress.isNotEmpty) {
      final locService = ref.read(locationServiceProvider);
      // 1. Try resolving full address
      var geocoded = await locService.geocodeAddress(fullAddress);
      // 2. Try resolving area + city + state
      if (geocoded == null && areaText.isNotEmpty) {
        geocoded = await locService.geocodeAddress('$areaText, $cityText, $stateText, $zipText');
      }
      // 3. Try resolving city + state
      geocoded ??= await locService.geocodeAddress('$cityText, $stateText, India');
      // 4. Try resolving pincode
      if (geocoded == null && zipText.isNotEmpty) {
        geocoded = await locService.geocodeAddress('$zipText, India');
      }

      if (geocoded != null) {
        latitude = geocoded.latitude;
        longitude = geocoded.longitude;
      } else {
        // 5. Fallback to device's last known or current GPS position
        try {
          final lastKnown = await locService.lastKnownLatLng();
          if (lastKnown != null) {
            latitude = lastKnown.lat;
            longitude = lastKnown.lng;
          } else {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                timeLimit: Duration(seconds: 3),
              ),
            );
            latitude = pos.latitude;
            longitude = pos.longitude;
          }
        } catch (_) {
          // 6. Safe central fallback coordinates (Indore/Central India)
          latitude = 22.7196;
          longitude = 75.8577;
        }
      }
    }

    final effectiveStreet = streetText.isNotEmpty
        ? streetText
        : (buildingText.isNotEmpty
            ? buildingText
            : (areaText.isNotEmpty ? areaText : 'Address'));

    final isEditing = _editingAddressId != null && _editingAddressId!.isNotEmpty;

    // Safeguard: when adding a new address, if the user leaves the type as 'Home' or 'Office'
    // but an address with that label already exists in the user's account, set type to 'Other'
    // so that the backend does not overwrite their existing Home or Office address!
    String effectiveType = _selectedType;
    if (!isEditing) {
      final currentList = ref.read(addressViewModelProvider);
      final hasSameType = currentList.any((a) => a.type.toLowerCase() == _selectedType.toLowerCase());
      if (hasSameType && _selectedType.toLowerCase() != 'other') {
        effectiveType = 'Other';
      }
    }

    final addressModel = AddressModel(
      id: _editingAddressId ?? '',
      title: savedName,
      fullAddress: fullAddress.isNotEmpty ? fullAddress : 'Delivery Address',
      type: effectiveType,
      building: buildingText,
      street: streetText.isNotEmpty ? streetText : effectiveStreet,
      city: cityText,
      state: stateText,
      zipCode: zipText,
      latitude: latitude ?? 22.7196,
      longitude: longitude ?? 75.8577,
      contactName: _useAccountDetails ? _accountName : null,
      contactPhone: _useAccountDetails ? _accountPhone : null,
    );

    bool success;
    if (isEditing) {
      success = await ref.read(addressViewModelProvider.notifier).editAddress(addressModel);
    } else {
      // DEDUPLICATION: check if the exact same address already exists!
      final currentList = ref.read(addressViewModelProvider);
      AddressModel? duplicate;
      for (final a in currentList) {
        if (a.latitude != null && a.longitude != null && latitude != null && longitude != null) {
          if ((a.latitude! - latitude).abs() < 0.0005 && (a.longitude! - longitude).abs() < 0.0005) {
            duplicate = a;
            break;
          }
        }
        if (a.fullAddress.trim().isNotEmpty && a.fullAddress.trim().toLowerCase() == fullAddress.trim().toLowerCase()) {
          duplicate = a;
          break;
        }
      }

      if (duplicate != null) {
        // Do NOT create duplicate card; set existing as default
        await ref.read(addressViewModelProvider.notifier).setDefaultAddress(duplicate.id);
        success = true;
      } else {
        success = await ref.read(addressViewModelProvider.notifier).addAddress(addressModel);
        if (success) {
          final updated = ref.read(addressViewModelProvider);
          if (updated.isNotEmpty) {
            final created = updated.firstWhere(
              (a) => a.latitude == latitude && a.longitude == longitude,
              orElse: () => updated.last,
            );
            await ref.read(addressViewModelProvider.notifier).setDefaultAddress(created.id);
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Haptics.success();
      AppSnackbar.success(
        context,
        isEditing ? 'Address updated successfully!' : 'Address saved successfully!',
      );
      _editingAddressId = null;
      // Reload address list so any listeners update immediately
      await ref.read(addressViewModelProvider.notifier).load();
      await ref.read(zoneViewModelProvider.notifier).refresh();
      ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants();
      ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);

      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteNames.home);
      }
    } else {
      final err = ref.read(addressViewModelProvider.notifier).error;
      AppSnackbar.error(context, err ?? 'Could not save address. Please try again.');
    }
  }

  void _startNewAddress() {
    final existing = ref.read(addressViewModelProvider);
    final hasHome = existing.any((a) => a.type.toLowerCase() == 'home');
    final hasOffice = existing.any((a) => a.type.toLowerCase() == 'office' || a.type.toLowerCase() == 'work');

    String defaultType = 'Home';
    if (hasHome && !hasOffice) {
      defaultType = 'Office';
    } else if (hasHome && hasOffice) {
      defaultType = 'Other';
    }

    final defaultTitle = defaultType == 'Other'
        ? (existing.length >= 2 ? 'Other ${existing.length + 1}' : 'Other')
        : defaultType;

    setState(() {
      _editingAddressId = null;
      _buildingController.clear();
      _streetController.clear();
      _areaController.clear();
      _cityController.clear();
      _stateController.clear();
      _pincodeController.clear();
      _saveAsController.text = defaultTitle;
      _selectedType = defaultType;
      _instructionsController.clear();
      _latitude = null;
      _longitude = null;
      _hasRealMapPosition = false;
    });
  }

  void _fillFormWithAddress(AddressModel address) {
    setState(() {
      _editingAddressId = address.id.isNotEmpty ? address.id : null;
      _selectedType = ['Home', 'Office', 'Other'].contains(address.type) ? address.type : 'Other';
      _saveAsController.text = address.title.isNotEmpty ? address.title : _selectedType;
      _buildingController.text = address.building;
      _streetController.text = address.street;
      _cityController.text = address.city;
      _stateController.text = address.state;
      _pincodeController.text = address.zipCode;
      if (address.latitude != null && address.longitude != null) {
        _latitude = address.latitude;
        _longitude = address.longitude;
        _hasRealMapPosition = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(address.latitude!, address.longitude!),
            16,
          ),
        );
      }
    });
  }

  Future<void> _selectAddress(AddressModel address) async {
    Haptics.medium();
    if (address.id.isNotEmpty) {
      await ref.read(addressViewModelProvider.notifier).setDefaultAddress(address.id);
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss sheet
    context.pop<Map<String, String>>({
      'type': address.type,
      'title': address.title,
      'subtitle': address.fullAddress,
    });
  }

  void _showSavedAddressesSheet(BuildContext context) {
    Haptics.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

        return Consumer(
          builder: (ctx, ref, _) {
            final savedAddresses = ref.watch(addressViewModelProvider);
            final isLoggedIn = ref.watch(authViewModelProvider).value != null;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Saved Addresses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            if (savedAddresses.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${savedAddresses.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: secondaryColor),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Content
                  Flexible(
                    child: !isLoggedIn
                        ? Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 48, color: secondaryColor),
                                const SizedBox(height: 12),
                                Text(
                                  'Log in to view saved addresses',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    context.push('${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.addAddress)}');
                                  },
                                  child: const Text('Log In', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : savedAddresses.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_off_outlined,
                                        size: 40,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Saved Addresses Yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Fill the address form and tap Save Address to save your favorite locations.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: secondaryColor),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(sheetContext),
                                      child: const Text('Add Address Now', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shrinkWrap: true,
                                itemCount: savedAddresses.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (ctx, index) {
                                  final addr = savedAddresses[index];
                                  final isHome = addr.type.toLowerCase() == 'home';
                                  final isWork = addr.type.toLowerCase() == 'office' || addr.type.toLowerCase() == 'work';
                                  final typeIcon = isHome
                                      ? Icons.home_rounded
                                      : (isWork ? Icons.work_rounded : Icons.location_on_rounded);
                                  final iconColor = isHome
                                      ? const Color(0xFFFF6D00)
                                      : (isWork ? const Color(0xFF2979FF) : const Color(0xFF00C853));

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF282828) : const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: addr.isDefault
                                            ? AppColors.primary
                                            : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                                        width: addr.isDefault ? 1.5 : 1.0,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: iconColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(typeIcon, color: iconColor, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        addr.title.isNotEmpty ? addr.title : addr.type,
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: textColor,
                                                        ),
                                                      ),
                                                      if (addr.isDefault) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.primary.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'DEFAULT',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    addr.fullAddress,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: secondaryColor,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Delete button
                                            IconButton(
                                              icon: Icon(Icons.delete_outline, size: 20, color: Colors.red[300]),
                                              tooltip: 'Delete address',
                                              onPressed: () async {
                                                Haptics.light();
                                                final deleted = await ref.read(addressViewModelProvider.notifier).deleteAddress(addr.id);
                                                if (deleted && sheetContext.mounted) {
                                                  AppSnackbar.success(sheetContext, 'Address removed');
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            // Fill form button
                                            Expanded(
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  side: BorderSide(
                                                    color: isDark ? Colors.white24 : Colors.black12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Haptics.light();
                                                  Navigator.pop(sheetContext);
                                                  _fillFormWithAddress(addr);
                                                  AppSnackbar.info(context, 'Address loaded into form');
                                                },
                                                child: Text(
                                                  'Edit in Form',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: textColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Select / Deliver here
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => _selectAddress(addr),
                                                child: const Text(
                                                  'Deliver Here',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Bottom padding button
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _startNewAddress();
                            AppSnackbar.info(context, 'Fill details above to create a new address card');
                          },
                          icon: const Icon(Icons.add_location_alt_rounded, size: 20, color: Colors.white),
                          label: const Text(
                            '+ Add New Address Card',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final savedAddressesCount = ref.watch(addressViewModelProvider).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.backOr(),
        ),
        title: Builder(
          builder: (context) {
            final title = _areaController.text.isNotEmpty
                ? _areaController.text
                : (_cityController.text.isNotEmpty ? _cityController.text : 'Set Delivery Address');
            final subtitle = _streetController.text.isNotEmpty
                ? _streetController.text
                : (_stateController.text.isNotEmpty ? '${_cityController.text}, ${_stateController.text}' : '');

            return RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    TextSpan(
                      text: '| $subtitle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: secondaryColor,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showSavedAddressesSheet(context),
            icon: Icon(Icons.bookmark_outline_rounded, color: AppColors.primary, size: 18),
            label: Text(
              'Saved ($savedAddressesCount)',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  if (_editingAddressId != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Editing address: ${_saveAsController.text}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Saving will update this card. Tap button to add a new card instead.',
                                  style: TextStyle(fontSize: 11.5, color: secondaryColor),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _startNewAddress,
                            child: const Text(
                              '+ New Card',
                              style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Section 0: Search, then pin the exact spot on the map
                  _buildLocationSearch(isDark, textColor, secondaryColor),

                  const SizedBox(height: 10),

                  _buildMapPicker(isDark, textColor, secondaryColor),

                  const SizedBox(height: 12),

                  // Section 0b: Use Current Location Prompt Card
                  _buildUseCurrentLocationCard(isDark, textColor, secondaryColor),

                  // Section 1: Receiver Details
                  _buildSectionHeader('Receiver Details', textColor),
                  const SizedBox(height: 10),
                  _buildCard(
                    isDark: isDark,
                    child: InkWell(
                      onTap: () {
                        Haptics.light();
                        setState(() => _useAccountDetails = !_useAccountDetails);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _useAccountDetails
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _useAccountDetails
                                      ? AppColors.primary
                                      : secondaryColor,
                                  width: 1.5,
                                ),
                              ),
                              child: _useAccountDetails
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Use my account details',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_accountName, $_accountPhone',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: secondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Location Details
                  _buildSectionHeader('Location Details', textColor),
                  const SizedBox(height: 10),
                  _buildCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        // Custom Segmented Selector (Home, Office, Other)
                        _SlidingSegmentedControl(
                          selectedType: _selectedType,
                          isDark: isDark,
                          onSelected: (type) {
                            Haptics.light();
                            setState(() {
                              _selectedType = type;
                              if (_saveAsController.text.trim().isEmpty ||
                                  _saveAsController.text.trim() == 'Home' ||
                                  _saveAsController.text.trim() == 'Office' ||
                                  _saveAsController.text.trim() == 'Other') {
                                _saveAsController.text = type;
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        _AnimatedFocusPillField(
                          controller: _buildingController,
                          hintText: 'Building / Floor / Flat *',
                          isDark: isDark,
                        ),

                        const SizedBox(height: 12),

                        _AnimatedFocusPillField(
                          controller: _streetController,
                          hintText: 'Street / Landmark',
                          isDark: isDark,
                        ),

                        const SizedBox(height: 12),

                        // Area/Locality Input Box + Map Thumbnail Card
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _AnimatedFocusPillField(
                                controller: _areaController,
                                hintText: 'Area / Locality *',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Map Box
                            InkWell(
                              onTap: _isDetectingLocation ? null : _detectCurrentLocation,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.primaryTintDark : AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.primary.withValues(alpha: 0.4)
                                        : AppColors.primarySoft,
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.my_location_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isDetectingLocation ? 'Detecting' : 'GPS Fix',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _AnimatedFocusPillField(
                                controller: _cityController,
                                hintText: 'City',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AnimatedFocusPillField(
                                controller: _stateController,
                                hintText: 'State',
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _AnimatedFocusPillField(
                          controller: _pincodeController,
                          hintText: 'Pincode',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _AnimatedFocusPillField(
                          controller: _saveAsController,
                          hintText: 'Save address as *',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 3: Delivery Instructions
                  _buildSectionHeader('Delivery Instructions (optional)', textColor),
                  const SizedBox(height: 10),
                  _buildDeliveryInstructionsCard(isDark, textColor, secondaryColor),

                  const SizedBox(height: 24),

                  // Save Address Button
                  _AnimatedSaveButton(
                    isEnabled: !_isSaving,
                    isDark: isDark,
                    buttonText: _editingAddressId != null ? 'Update Address' : 'Save Address',
                    onPressed: _validateAndSave,
                  ),

                  const SizedBox(height: 12),

                  // Button to view all saved addresses
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: Icon(Icons.bookmarks_rounded, color: AppColors.primary, size: 20),
                    label: Text(
                      'View Saved Addresses ($savedAddressesCount)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () => _showSavedAddressesSheet(context),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: AppColors.primary, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  icon: Icon(Icons.bookmark_outline_rounded, color: AppColors.primary, size: 19),
                  label: Text(
                    'Saved ($savedAddressesCount)',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () => _showSavedAddressesSheet(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _validateAndSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          _editingAddressId != null ? 'Update Address' : 'Save Address',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSearch(bool isDark, Color textColor, Color secondaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: 'Search for area, street or landmark',
            hintStyle: TextStyle(fontSize: 13.5, color: secondaryColor),
            prefixIcon: Icon(Icons.search, size: 20, color: secondaryColor),
            suffixIcon: _isSearching
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  )
                : (_searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, size: 18, color: secondaryColor),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _suggestions = const []);
                        },
                      )),
            filled: true,
            fillColor: isDark ? AppColors.cardDark : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        // Only rendered when there is something to choose — no empty dropdown.
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.borderDark : const Color(0xFFEFF1F4),
                    ),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: secondaryColor,
                    ),
                    title: Text(
                      _suggestions[i].description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: textColor),
                    ),
                    onTap: () => _selectSuggestion(_suggestions[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMapPicker(bool isDark, Color textColor, Color secondaryColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                style: MapStyles.mutedGrey,
                initialCameraPosition: _initialCamera,
                // The map sits inside a ListView, which claims vertical drags for
                // scrolling — so without this the pin could not be moved at all.
                // Eagerly winning the gesture arena hands panning to the map.
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                onMapCreated: (controller) {
                  _mapController = controller;
                  // Open on the saved point when editing, so the pin starts where
                  // the address already is instead of jumping there later.
                  final lat = _latitude;
                  final lng = _longitude;
                  if (lat != null && lng != null) {
                    _suppressNextIdle = true;
                    _moveCameraTo(lat, lng);
                  }
                },
                // Fires whenever the camera actually starts moving, including a
                // finger drag, and never on the initial load. That makes it the
                // signal that the map is no longer showing its placeholder
                // view — without it, a customer who simply pans to their street
                // without using GPS or search would have their pin ignored.
                onCameraMoveStarted: () => _hasRealMapPosition = true,
                onCameraIdle: () {
                  // onCameraIdle carries no position, so read the last one the
                  // move reported.
                  final position = _lastCameraPosition;
                  if (position != null) _onPinSettled(position);
                },
                onCameraMove: (position) => _lastCameraPosition = position,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                // No marker layer: the pin is drawn on top and the map slides
                // beneath it.
                markers: const {},
              ),
            ),

            // The pin itself. Offset up by half its height so the point sits on
            // the map centre rather than the icon's middle.
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isResolvingPin) ...[
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _isResolvingPin ? 'Finding address...' : 'Move map to set location',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: isDark ? AppColors.cardDark : Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isDetectingLocation ? null : _detectCurrentLocation,
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: _isDetectingLocation
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.primary),
                            ),
                          )
                        : Icon(Icons.my_location, size: 20, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUseCurrentLocationCard(bool isDark, Color textColor, Color secondaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.primaryTintDark, AppColors.primaryTintDark]
              : [AppColors.primaryTint, AppColors.primaryTintStrong],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isDetectingLocation ? null : _detectCurrentLocation,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isDetectingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Use Current Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'GPS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isDetectingLocation
                            ? 'Detecting your GPS position & reverse geocoding...'
                            : (_latitude != null && _longitude != null
                                ? 'GPS coordinates detected: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                                : 'Tap to automatically detect & fill address via GPS'),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildDeliveryInstructionsCard(bool isDark, Color textColor, Color secondaryColor) {
    final presets = [
      {'icon': '🔕', 'text': 'Avoid ringing bell'},
      {'icon': '🚪', 'text': 'Leave at door'},
      {'icon': '📞', 'text': 'Call upon arrival'},
      {'icon': '🐕', 'text': 'Beware of pets'},
    ];

    return _buildCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Preset Quick Instruction Chips
          Text(
            'Quick Suggestions:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              final chipText = preset['text']!;
              final isSelected = _instructionsController.text.contains(chipText);

              return InkWell(
                onTap: () {
                  Haptics.light();
                  setState(() {
                    if (isSelected) {
                      _instructionsController.text = _instructionsController.text
                          .replaceAll(chipText, '')
                          .replaceAll(RegExp(r',\s*,'), ',')
                          .replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '')
                          .trim();
                    } else {
                      final current = _instructionsController.text.trim();
                      if (current.isEmpty) {
                        _instructionsController.text = chipText;
                      } else {
                        _instructionsController.text = '$current, $chipText';
                      }
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark ? AppColors.primaryTintDark : const Color(0xFFF4F5F8)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset['icon']!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        chipText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // 2. Custom Directions Input Component (Integrated Icon + TextField)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primaryTintDark : AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _instructionsController,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 200,
                    style: TextStyle(fontSize: 13.5, color: textColor, fontWeight: FontWeight.w500),
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Add directions to reach location, landmark, gate code...',
                      hintStyle: TextStyle(fontSize: 13, color: secondaryColor.withValues(alpha: 0.65)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_instructionsController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Haptics.light();
                      _instructionsController.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.close_rounded, size: 18, color: secondaryColor),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Save Address CTA — smooth enabled/disabled color crossfade
/// (AnimatedContainer) plus a subtle press-scale, on top of the ripple
/// InkWell already gives for free.
class _AnimatedSaveButton extends StatefulWidget {
  final bool isEnabled;
  final bool isDark;
  final VoidCallback onPressed;
  final String buttonText;

  const _AnimatedSaveButton({
    required this.isEnabled,
    required this.isDark,
    required this.onPressed,
    this.buttonText = 'Save Address',
  });

  @override
  State<_AnimatedSaveButton> createState() => _AnimatedSaveButtonState();
}

class _AnimatedSaveButtonState extends State<_AnimatedSaveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final backgroundColor = widget.isEnabled
        ? AppColors.primary
        : (isDark ? Colors.grey[800]! : const Color(0xFFE2E4E8));
    final textColor = widget.isEnabled
        ? Colors.white
        : (isDark ? Colors.white38 : const Color(0xFF9E9E9E));

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTapDown: widget.isEnabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.isEnabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: widget.isEnabled ? () => setState(() => _isPressed = false) : null,
          onTap: widget.isEnabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: double.infinity,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              child: Text(widget.buttonText),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Equal-Sized Segmented Control for Home / Office / Other
class _SlidingSegmentedControl extends StatelessWidget {
  final String selectedType;
  final bool isDark;
  final ValueChanged<String> onSelected;

  const _SlidingSegmentedControl({
    required this.selectedType,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final types = const ['Home', 'Office', 'Other'];
    final selectedIndex = types.indexOf(selectedType);

    final double alignX = selectedIndex == 0
        ? -1.0
        : (selectedIndex == 1 ? 0.0 : 1.0);

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth) / 3;

          return Stack(
            children: [
              // Smooth Sliding Active Pill Background
              AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment(alignX, 0),
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Option Items Row with Clean Alignment
              Row(
                children: [
                  _buildTabItem(
                    type: 'Home',
                    icon: Icons.home_outlined,
                    isSelected: selectedType == 'Home',
                  ),
                  _buildTabItem(
                    type: 'Office',
                    icon: Icons.work_outline,
                    isSelected: selectedType == 'Office',
                  ),
                  _buildTabItem(
                    type: 'Other',
                    // location_on_outlined read as "generic location pin" on a
                    // screen where every option is already a location — it
                    // didn't distinguish "other" from Home/Office at a glance.
                    icon: Icons.more_horiz_outlined,
                    isSelected: selectedType == 'Other',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabItem({
    required String type,
    required IconData icon,
    required bool isSelected,
  }) {
    final activeTextColor = isDark ? Colors.black : Colors.white;
    final inactiveTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(type),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                type,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeTextColor : inactiveTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated Focus Text Field
class _AnimatedFocusPillField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isDark;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;

  const _AnimatedFocusPillField({
    required this.controller,
    required this.hintText,
    required this.isDark,
    this.keyboardType,
    this.formatters,
  });

  @override
  State<_AnimatedFocusPillField> createState() => _AnimatedFocusPillFieldState();
}

class _AnimatedFocusPillFieldState extends State<_AnimatedFocusPillField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final defaultBorderColor = isDark ? AppColors.borderDark : const Color(0xFFDCDFE4);

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.formatters,
      style: TextStyle(
        fontSize: 13.5,
        color: isDark ? Colors.white : AppColors.textPrimaryLight,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9EA3AE),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: defaultBorderColor,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}