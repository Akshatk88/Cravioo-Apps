import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/referral_tracking_service.dart';
import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import '../widgets/auth_widgets.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.phone = ''});

  final String phone;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ------------------------------------------------------------
  // PHONE
  // ------------------------------------------------------------
  // IMPORTANT:
  // Phone ko getter se baar-baar authState se read nahi karna.
  // Registration screen open hote hi ek baar store karenge.
  late String _registrationPhone;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _vehicleNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _licenseController = TextEditingController();
  final _panController = TextEditingController();
  final _aadharController = TextEditingController();
  final _referralController = TextEditingController();

  String _vehicleType = 'bike';

  final _vehicleTypes = const ['bike', 'scooter', 'bicycle', 'car'];

  File? _profilePhoto;
  File? _aadharPhoto;
  File? _panPhoto;
  File? _licensePhoto;
  File? _upiQrCode;

  bool _isSubmitting = false;
  String? _errorText;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // First preference:
    // phone passed from OTP screen.
    String phone = widget.phone.trim();

    // Fallback:
    // phone stored in AuthNeedsRegistration state.
    if (phone.isEmpty) {
      final authState = ref.read(authControllerProvider);

      if (authState is AuthNeedsRegistration) {
        phone = authState.phone.trim();
      }
    }

    // Keep only digits.
    // This makes the value safe even if +91 / spaces were accidentally passed.
    phone = phone.replaceAll(RegExp(r'\D'), '');

    // If country code somehow came in as 91 + 10 digits,
    // remove only the leading 91.
    if (phone.length == 12 && phone.startsWith('91')) {
      phone = phone.substring(2);
    }

    _registrationPhone = phone;

    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    final code = await ReferralTrackingService.getReferralCode();

    if (code != null && code.isNotEmpty && mounted) {
      _referralController.text = code;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _vehicleNameController.dispose();
    _vehicleNumberController.dispose();
    _licenseController.dispose();
    _panController.dispose();
    _aadharController.dispose();
    _referralController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // IMAGE PICKER
  // ------------------------------------------------------------

  Future<void> _pickImage(void Function(File) onPicked) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );

      if (picked == null || !mounted) {
        return;
      }

      setState(() {
        onPicked(File(picked.path));
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = 'Unable to select image. Please try again.';
      });
    }
  }

  // ------------------------------------------------------------
  // SUBMIT
  // ------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    // Clear previous error.
    if (mounted) {
      setState(() {
        _errorText = null;
      });
    }

    // Validate all text fields.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // ----------------------------------------------------------
    // PHONE VALIDATION
    // ----------------------------------------------------------
    final phone = _registrationPhone.trim().replaceAll(RegExp(r'\D'), '');

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() {
        _errorText =
            'Invalid mobile number. Please login again with a valid 10-digit mobile number.';
      });
      return;
    }

    // ----------------------------------------------------------
    // REQUIRED DOCUMENTS
    // ----------------------------------------------------------

    if (_profilePhoto == null) {
      setState(() {
        _errorText = 'Please upload your profile photo.';
      });
      return;
    }

    if (_aadharPhoto == null) {
      setState(() {
        _errorText = 'Please upload your Aadhar card photo.';
      });
      return;
    }

    if (_panPhoto == null) {
      setState(() {
        _errorText = 'Please upload your PAN card photo.';
      });
      return;
    }

    if (_licensePhoto == null) {
      setState(() {
        _errorText = 'Please upload your driving license photo.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // --------------------------------------------------------
      // NORMALIZE VALUES
      // --------------------------------------------------------

      final vehicleNumber = _vehicleNumberController.text
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'\s+'), '');

      final drivingLicenseNumber = _licenseController.text
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[\s-]'), '');

      final panNumber = _panController.text.trim().toUpperCase().replaceAll(
        RegExp(r'\s+'),
        '',
      );

      final aadharNumber = _aadharController.text.trim().replaceAll(
        RegExp(r'\s+'),
        '',
      );

      // --------------------------------------------------------
      // FORM DATA
      // --------------------------------------------------------

      final formData = FormData.fromMap({
        'name': _nameController.text.trim(),

        // IMPORTANT:
        // Always send the saved phone.
        // Do NOT use widget.phone or authState here.
        'phone': phone,

        'countryCode': '+91',

        if (_emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),

        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),

        'vehicleType': _vehicleType,
        'vehicleName': _vehicleNameController.text.trim(),
        'vehicleNumber': vehicleNumber,

        'drivingLicenseNumber': drivingLicenseNumber,
        'panNumber': panNumber,
        'aadharNumber': aadharNumber,

        if (_referralController.text.trim().isNotEmpty)
          'ref': _referralController.text.trim(),

        'platform': 'mobile',

        // Required images.
        'profilePhoto': await MultipartFile.fromFile(
          _profilePhoto!.path,
          filename: 'profile_photo.jpg',
        ),

        'aadharPhoto': await MultipartFile.fromFile(
          _aadharPhoto!.path,
          filename: 'aadhar_photo.jpg',
        ),

        'panPhoto': await MultipartFile.fromFile(
          _panPhoto!.path,
          filename: 'pan_photo.jpg',
        ),

        'drivingLicensePhoto': await MultipartFile.fromFile(
          _licensePhoto!.path,
          filename: 'driving_license_photo.jpg',
        ),

        // Optional UPI QR.
        if (_upiQrCode != null)
          'upiQrCode': await MultipartFile.fromFile(
            _upiQrCode!.path,
            filename: 'upi_qr_code.jpg',
          ),
      });

      // --------------------------------------------------------
      // API CALL
      // --------------------------------------------------------

      final result = await ref
          .read(authControllerProvider.notifier)
          .register(formData);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      result.when(
        success: (_) {
          // AuthController changes state to:
          // AuthPendingApproval / AuthAuthenticated
          //
          // RouterNotifier will automatically move the user
          // to the correct next screen.
        },
        failure: (error) {
          setState(() {
            _errorText = error.message;
          });
        },
      );
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;

        final data = e.response?.data;

        if (data is Map<String, dynamic>) {
          _errorText =
              data['message']?.toString() ??
              data['error']?.toString() ??
              'Registration failed. Please try again.';
        } else {
          _errorText = e.message ?? 'Registration failed. Please try again.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _errorText = 'Registration failed. Please try again.';
      });
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partner Registration')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            children: [
              // ==================================================
              // PERSONAL DETAILS
              // ==================================================

              const AuthSectionTitle('Personal details'),

              _textField(_nameController, 'Full name', required: true),

              SizedBox(height: 12.h),

              // --------------------------------------------------
              // PHONE
              // --------------------------------------------------
              //
              // Controller based field nahi banaya because user
              // ko edit nahi karna hai.
              //
              // Value _registrationPhone se aayegi aur image
              // upload ke baad bhi blank nahi hogi.
              // --------------------------------------------------
              TextFormField(
                key: ValueKey(_registrationPhone),
                initialValue: _registrationPhone.isEmpty
                    ? ''
                    : '+91 $_registrationPhone',
                enabled: false,
                decoration: authInputDecoration(
                  context,
                  label: 'Mobile number',
                ),
                validator: (_) {
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_registrationPhone)) {
                    return 'Invalid mobile number';
                  }
                  return null;
                },
              ),

              SizedBox(height: 12.h),

              _textField(
                _emailController,
                'Email (optional)',
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: 12.h),

              _textField(_addressController, 'Address'),

              SizedBox(height: 12.h),

              Row(
                children: [
                  Expanded(child: _textField(_cityController, 'City')),
                  SizedBox(width: 12.w),
                  Expanded(child: _textField(_stateController, 'State')),
                ],
              ),

              // ==================================================
              // VEHICLE DETAILS
              // ==================================================
              const AuthSectionTitle('Vehicle details'),

              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                decoration: authInputDecoration(context, label: 'Vehicle type'),
                items: _vehicleTypes
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v,
                        child: Text(v[0].toUpperCase() + v.substring(1)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _vehicleType = value;
                  });
                },
              ),

              SizedBox(height: 12.h),

              _textField(_vehicleNameController, 'Vehicle name/model'),

              SizedBox(height: 12.h),

              _textField(
                _vehicleNumberController,
                'Vehicle number',
                required: true,
                textCapitalization: TextCapitalization.characters,
              ),

              // ==================================================
              // KYC DETAILS
              // ==================================================
              const AuthSectionTitle('KYC details'),

              _textField(
                _licenseController,
                'Driving license number',
                required: true,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  final v = (value ?? '').trim().toUpperCase().replaceAll(
                    RegExp(r'[\s-]'),
                    '',
                  );

                  if (v.isEmpty) {
                    return 'Required';
                  }

                  if (!RegExp(r'^[A-Z]{2}[0-9A-Z]{8,16}$').hasMatch(v)) {
                    return 'Enter a valid license number';
                  }

                  return null;
                },
              ),

              SizedBox(height: 12.h),

              _textField(
                _panController,
                'PAN number',
                required: true,
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  final v = (value ?? '').trim().toUpperCase();

                  if (v.isEmpty) {
                    return 'Required';
                  }

                  if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v)) {
                    return 'Enter a valid PAN number';
                  }

                  return null;
                },
              ),

              SizedBox(height: 12.h),

              _textField(
                _aadharController,
                'Aadhar number',
                required: true,
                keyboardType: TextInputType.number,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final v = (value ?? '').trim();

                  if (v.isEmpty) {
                    return 'Required';
                  }

                  if (!RegExp(r'^\d{12}$').hasMatch(v)) {
                    return 'Enter a valid 12-digit Aadhar number';
                  }

                  return null;
                },
              ),

              SizedBox(height: 12.h),

              _textField(_referralController, 'Referral code (optional)'),

              // ==================================================
              // DOCUMENTS
              // ==================================================
              const AuthSectionTitle('Upload documents'),

              _docPickerRow(
                'Profile photo',
                _profilePhoto,
                () => _pickImage((file) => _profilePhoto = file),
              ),

              _docPickerRow(
                'Aadhar card photo',
                _aadharPhoto,
                () => _pickImage((file) => _aadharPhoto = file),
              ),

              _docPickerRow(
                'PAN card photo',
                _panPhoto,
                () => _pickImage((file) => _panPhoto = file),
              ),

              _docPickerRow(
                'Driving license photo',
                _licensePhoto,
                () => _pickImage((file) => _licensePhoto = file),
              ),

              _docPickerRow(
                'UPI QR code (optional)',
                _upiQrCode,
                () => _pickImage((file) => _upiQrCode = file),
              ),

              // ==================================================
              // ERROR
              // ==================================================
              if (_errorText != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    _errorText!,
                    style: TextStyle(color: Colors.redAccent, fontSize: 13.sp),
                  ),
                ),
              ],

              SizedBox(height: 24.h),

              // ==================================================
              // SUBMIT
              // ==================================================
              AuthPrimaryButton(
                label: 'Submit for Review',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TEXT FIELD
  // ------------------------------------------------------------

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      decoration: authInputDecoration(
        context,
        label: label,
      ).copyWith(counterText: maxLength != null ? '' : null),
      validator:
          validator ??
          (required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                }
              : null),
    );
  }

  // ------------------------------------------------------------
  // DOCUMENT PICKER
  // ------------------------------------------------------------

  Widget _docPickerRow(String label, File? file, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: file != null
                    ? Image.file(
                        file,
                        width: 48.w,
                        height: 48.w,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 48.w,
                        height: 48.w,
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.upload_file_rounded,
                          color: AppTheme.primaryColor,
                          size: 22.sp,
                        ),
                      ),
              ),

              SizedBox(width: 12.w),

              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              Text(
                file != null ? 'Change' : 'Upload',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
