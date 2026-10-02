import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
final _pincodeRegex = RegExp(r'^\d{6}$');

/// Single mutable holder for everything collected across the 4-step
/// registration wizard. Owned by [RegistrationController] and mutated
/// in-place by the step widgets — see that controller for why this isn't a
/// `copyWith` immutable model.
class RegistrationFormData {
  // Step 1 — restaurant + owner
  String restaurantName = '';
  bool? pureVegRestaurant;
  String ownerName = '';
  String ownerEmail = '';
  String ownerPhone = '';
  String primaryContactNumber = '';

  // Step 2 — location
  String addressLine1 = '';
  String addressLine2 = '';
  String area = '';
  String city = '';
  String state = '';
  String pincode = '';
  String landmark = '';
  String formattedAddress = '';
  double? latitude;
  double? longitude;
  String zoneId = '';
  String zoneName = '';
  List<String> cuisines = [];
  List<String> openDays = [];
  String openingTime = '09:00';
  String closingTime = '22:00';
  int estimatedDeliveryTime = 30;

  // Step 3 — documents
  XFile? profileImage;
  List<XFile> menuImages = [];
  String panNumber = '';
  String nameOnPan = '';
  XFile? panImage;
  bool gstRegistered = false;
  String gstNumber = '';
  String gstLegalName = '';
  String gstAddress = '';
  XFile? gstImage;
  String fssaiNumber = '';
  String fssaiExpiry = '';
  XFile? fssaiImage;

  // Step 4 — bank
  String accountHolderName = '';
  String accountNumber = '';
  String ifscCode = '';
  String accountType = 'savings';

  bool get isStep1Valid =>
      restaurantName.trim().isNotEmpty &&
      ownerName.trim().isNotEmpty &&
      pureVegRestaurant != null &&
      (ownerEmail.trim().isEmpty || _emailRegex.hasMatch(ownerEmail.trim()));

  bool get isStep2Valid =>
      addressLine1.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      state.trim().isNotEmpty &&
      _pincodeRegex.hasMatch(pincode.trim()) &&
      latitude != null &&
      longitude != null &&
      cuisines.isNotEmpty &&
      openDays.isNotEmpty &&
      zoneId.trim().isNotEmpty;

  bool get isStep3Valid =>
      profileImage != null &&
      (panNumber.trim().isEmpty ||
          _panRegex.hasMatch(panNumber.trim().toUpperCase())) &&
      (!gstRegistered || (gstNumber.trim().isNotEmpty && gstImage != null));

  bool get isStep4Valid =>
      accountNumber.trim().isEmpty ||
      (ifscCode.trim().isNotEmpty && accountHolderName.trim().isNotEmpty);

  /// Plain-English list of what's still missing on [step] (0-indexed) — shown
  /// under the Next button so a disabled state is never a silent mystery.
  List<String> missingFieldsForStep(int step) {
    switch (step) {
      case 0:
        return [
          if (restaurantName.trim().isEmpty) 'Restaurant name',
          if (ownerName.trim().isEmpty) 'Owner full name',
          if (pureVegRestaurant == null) 'Pure veg selection (Yes/No)',
          if (ownerEmail.trim().isNotEmpty &&
              !_emailRegex.hasMatch(ownerEmail.trim()))
            'A validly formatted email address',
        ];
      case 1:
        return [
          if (zoneId.trim().isEmpty) 'Delivery zone (select your operational zone)',
          if (addressLine1.trim().isEmpty) 'Address line 1',
          if (city.trim().isEmpty) 'City',
          if (state.trim().isEmpty) 'State',
          if (!_pincodeRegex.hasMatch(pincode.trim()))
            'A valid 6-digit pincode',
          if (latitude == null || longitude == null)
            'Your location — tap the map or use "Use current location"',
          if (cuisines.isEmpty) 'At least one cuisine',
          if (openDays.isEmpty) 'At least one open day',
        ];
      case 2:
        return [
          if (profileImage == null) 'Restaurant logo photo',
          if (panNumber.trim().isNotEmpty &&
              !_panRegex.hasMatch(panNumber.trim().toUpperCase()))
            'A valid 10-character PAN number (e.g. ABCDE1234F)',
          if (gstRegistered && gstNumber.trim().isEmpty)
            'GST number (since GST is marked as registered)',
          if (gstRegistered && gstImage == null)
            'GST certificate image (since GST is marked as registered)',
        ];
      case 3:
        return [
          if (accountNumber.trim().isNotEmpty && ifscCode.trim().isEmpty)
            'IFSC code',
          if (accountNumber.trim().isNotEmpty &&
              accountHolderName.trim().isEmpty)
            'Account holder name',
        ];
      default:
        return const [];
    }
  }

  Future<MultipartFile> _multipart(XFile file) async {
    final bytes = await file.readAsBytes();
    return MultipartFile.fromBytes(bytes, filename: file.name);
  }

  Future<FormData> toFormData() async {
    final map = <String, dynamic>{
      'restaurantName': restaurantName.trim(),
      'ownerName': ownerName.trim(),
      'ownerEmail': ownerEmail.trim(),
      'ownerPhone': ownerPhone.trim(),
      'primaryContactNumber': primaryContactNumber.trim().isNotEmpty
          ? primaryContactNumber.trim()
          : ownerPhone.trim(),
      'pureVegRestaurant': pureVegRestaurant == true ? 'true' : 'false',
      'addressLine1': addressLine1.trim(),
      'addressLine2': addressLine2.trim(),
      'area': area.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'pincode': pincode.trim(),
      'landmark': landmark.trim(),
      'formattedAddress': formattedAddress.trim(),
      'latitude': latitude?.toString() ?? '',
      'longitude': longitude?.toString() ?? '',
      'zoneId': zoneId.trim(),
      'cuisines': cuisines.join(','),
      'openDays': openDays.join(','),
      'openingTime': openingTime,
      'closingTime': closingTime,
      'estimatedDeliveryTime': estimatedDeliveryTime.toString(),
      'panNumber': panNumber.trim().toUpperCase(),
      'nameOnPan': nameOnPan.trim(),
      'gstRegistered': gstRegistered ? 'true' : 'false',
      'gstNumber': gstNumber.trim(),
      'gstLegalName': gstLegalName.trim(),
      'gstAddress': gstAddress.trim(),
      'fssaiNumber': fssaiNumber.trim(),
      'fssaiExpiry': fssaiExpiry,
      'accountNumber': accountNumber.trim(),
      'ifscCode': ifscCode.trim().toUpperCase(),
      'accountHolderName': accountHolderName.trim(),
      'accountType': accountType,
    };

    if (profileImage != null) {
      map['profileImage'] = await _multipart(profileImage!);
    }
    if (panImage != null) map['panImage'] = await _multipart(panImage!);
    if (gstImage != null) map['gstImage'] = await _multipart(gstImage!);
    if (fssaiImage != null) map['fssaiImage'] = await _multipart(fssaiImage!);
    if (menuImages.isNotEmpty) {
      map['menuImages'] = await Future.wait(menuImages.map(_multipart));
    }

    return FormData.fromMap(map);
  }
}
