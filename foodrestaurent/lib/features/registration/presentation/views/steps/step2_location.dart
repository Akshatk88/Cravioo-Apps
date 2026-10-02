import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/registration/presentation/controllers/registration_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/chip_multi_select.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/zones/data/zone_repository.dart';
import 'package:food_user_application/features/zones/domain/zone_model.dart';

const _cuisineOptions = [
  'North Indian',
  'South Indian',
  'Chinese',
  'Italian',
  'Continental',
  'Fast Food',
  'Bakery',
  'Desserts',
  'Beverages',
  'Mughlai',
  'Street Food',
  'Thai',
];

const _dayOptions = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _defaultCenter = LatLng(20.5937, 78.9629); // India

class Step2Location extends ConsumerStatefulWidget {
  const Step2Location({super.key, required this.onValidityChanged});

  final ValueChanged<bool> onValidityChanged;

  @override
  ConsumerState<Step2Location> createState() => _Step2LocationState();
}

class _Step2LocationState extends ConsumerState<Step2Location> {
  late final form = ref.read(registrationControllerProvider.notifier).form;

  late final _addressLine1 = TextEditingController(text: form.addressLine1);
  late final _addressLine2 = TextEditingController(text: form.addressLine2);
  late final _area = TextEditingController(text: form.area);
  late final _city = TextEditingController(text: form.city);
  late final _state = TextEditingController(text: form.state);
  late final _pincode = TextEditingController(text: form.pincode);
  late final _landmark = TextEditingController(text: form.landmark);

  GoogleMapController? _mapController;
  bool _isLocating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() => widget.onValidityChanged(form.isStep2Valid);

  @override
  void dispose() {
    _addressLine1.dispose();
    _addressLine2.dispose();
    _area.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    _landmark.dispose();
    super.dispose();
  }

  LatLng get _pin => (form.latitude != null && form.longitude != null)
      ? LatLng(form.latitude!, form.longitude!)
      : _defaultCenter;

  Future<void> _updatePin(LatLng position) async {
    setState(() {
      form.latitude = position.latitude;
      form.longitude = position.longitude;
    });
    _notify();
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are turned off. Please enable them and try again.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission denied. Please allow location access to continue.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      await _updatePin(latLng);

      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          latLng.latitude,
          latLng.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            _addressLine1.text = [
              p.street,
              p.subLocality,
            ].where((s) => (s ?? '').isNotEmpty).join(', ');
            _area.text = p.subLocality?.isNotEmpty == true
                ? p.subLocality!
                : (p.locality ?? '');
            _city.text = p.locality ?? '';
            _state.text = p.administrativeArea ?? '';
            _pincode.text = p.postalCode ?? '';
            form.addressLine1 = _addressLine1.text;
            form.area = _area.text;
            form.city = _city.text;
            form.state = _state.text;
            form.pincode = _pincode.text;
            form.formattedAddress = [
              p.street,
              p.locality,
              p.administrativeArea,
              p.postalCode,
            ].where((s) => (s ?? '').isNotEmpty).join(', ');
          });
        }
      } catch (_) {
        // Reverse geocoding is best-effort — the pin itself is still saved.
      }
      _notify();
    } catch (e) {
      setState(
        () => _locationError = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pickTime({required bool isOpening}) async {
    final current = isOpening ? form.openingTime : form.closingTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isOpening) {
        form.openingTime = formatted;
      } else {
        form.closingTime = formatted;
      }
    });
  }

  String _formatTimeLabel(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(activeZonesProvider);

    zonesAsync.whenData((zones) {
      if (form.zoneId.isEmpty && zones.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || form.zoneId.isNotEmpty) return;
          ZoneModel? match;
          if (form.city.isNotEmpty) {
            match = zones.cast<ZoneModel?>().firstWhere(
              (z) =>
                  z != null &&
                  z.name.toLowerCase().contains(form.city.toLowerCase().trim()),
              orElse: () => null,
            );
          }
          final selected = match ?? zones.first;
          setState(() {
            form.zoneId = selected.id;
            form.zoneName = selected.name;
          });
          _notify();
        });
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        _sectionCard(
          title: 'Delivery Zone',
          subtitle: 'Select the operational zone where your restaurant delivers.',
          children: [
            zonesAsync.when(
              data: (zones) {
                if (zones.isEmpty) {
                  return const Text(
                    'No active delivery zones found. Please contact support.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  );
                }
                final selectedId =
                    form.zoneId.isNotEmpty && zones.any((z) => z.id == form.zoneId)
                        ? form.zoneId
                        : (zones.isNotEmpty ? zones.first.id : null);
                if (form.zoneId.isEmpty && selectedId != null) {
                  form.zoneId = selectedId;
                  form.zoneName = zones.firstWhere((z) => z.id == selectedId).name;
                }
                return DropdownButtonFormField<String>(
                  value: selectedId,
                  decoration: InputDecoration(
                    labelText: 'Operational Zone',
                    labelStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.location_city, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  items: zones.map((zone) {
                    return DropdownMenuItem<String>(
                      value: zone.id,
                      child: Text(
                        zone.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newZoneId) {
                    if (newZoneId == null) return;
                    final zone = zones.firstWhere((z) => z.id == newZoneId);
                    setState(() {
                      form.zoneId = zone.id;
                      form.zoneName = zone.name;
                    });
                    _notify();
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Loading available zones...', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              error: (err, _) => Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to load zones: $err',
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Pin your location',
          subtitle:
              'Drag the pin or tap the map to set your restaurant\'s exact spot.',
          children: [
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pin,
                    zoom: form.latitude != null ? 16 : 4,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onTap: _updatePin,
                  markers: {
                    Marker(
                      markerId: const MarkerId('pin'),
                      position: _pin,
                      draggable: true,
                      onDragEnd: _updatePin,
                    ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                    : Icon(
                        Icons.my_location,
                        color: AppColors.primary,
                        size: 18,
                      ),
                label: Text(
                  _isLocating ? 'Locating...' : 'Use current location',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _locationError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            if (form.latitude != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pinned: ${form.latitude!.toStringAsFixed(5)}, ${form.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Address',
          children: [
            LabeledTextField(
              label: 'Address line 1',
              controller: _addressLine1,
              required: true,
              onChanged: (v) {
                form.addressLine1 = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Address line 2',
              controller: _addressLine2,
              onChanged: (v) => form.addressLine2 = v,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Area',
                    controller: _area,
                    onChanged: (v) => form.area = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledTextField(
                    label: 'City',
                    controller: _city,
                    required: true,
                    onChanged: (v) {
                      form.city = v;
                      _notify();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'State',
                    controller: _state,
                    required: true,
                    onChanged: (v) {
                      form.state = v;
                      _notify();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledTextField(
                    label: 'Pincode',
                    controller: _pincode,
                    required: true,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      form.pincode = v;
                      _notify();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Landmark',
              controller: _landmark,
              onChanged: (v) => form.landmark = v,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Cuisines',
          subtitle: 'Select all that apply.',
          children: [
            ChipMultiSelect(
              options: _cuisineOptions,
              selected: form.cuisines,
              onToggle: (option) {
                setState(() {
                  if (form.cuisines.contains(option)) {
                    form.cuisines.remove(option);
                  } else {
                    form.cuisines.add(option);
                  }
                });
                _notify();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Working hours',
          children: [
            const Text(
              'Open days *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ChipMultiSelect(
              options: _dayOptions,
              selected: form.openDays,
              onToggle: (option) {
                setState(() {
                  if (form.openDays.contains(option)) {
                    form.openDays.remove(option);
                  } else {
                    form.openDays.add(option);
                  }
                });
                _notify();
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Opening time',
                    controller: TextEditingController(
                      text: _formatTimeLabel(form.openingTime),
                    ),
                    readOnly: true,
                    onTap: () => _pickTime(isOpening: true),
                    suffixIcon: const Icon(Icons.access_time, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledTextField(
                    label: 'Closing time',
                    controller: TextEditingController(
                      text: _formatTimeLabel(form.closingTime),
                    ),
                    readOnly: true,
                    onTap: () => _pickTime(isOpening: false),
                    suffixIcon: const Icon(Icons.access_time, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Estimated delivery time',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _stepperButton(Icons.remove, () {
                  if (form.estimatedDeliveryTime > 10) {
                    setState(() => form.estimatedDeliveryTime -= 5);
                  }
                }),
                Expanded(
                  child: Center(
                    child: Text(
                      '${form.estimatedDeliveryTime} mins',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _stepperButton(Icons.add, () {
                  if (form.estimatedDeliveryTime < 90) {
                    setState(() => form.estimatedDeliveryTime += 5);
                  }
                }),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
