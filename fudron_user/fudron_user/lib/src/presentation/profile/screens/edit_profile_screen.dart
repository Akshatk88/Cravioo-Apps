import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/validators.dart';
import '../../../di/auth_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../navigation/route_names.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  DateTime _selectedDob = DateTime(2001, 1, 16);
  String _selectedLanguage = 'English';
  
  File? _pickedImageFile;
  String? _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authViewModelProvider).value;
    // Blank, never a seeded placeholder: these controllers are what _saveChanges
    // sends, so a demo name/phone/email here got written to the real account the
    // moment a new user opened this screen and tapped Save.
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedAvatarUrl = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        Haptics.success();
        setState(() {
          _pickedImageFile = File(image.path);
          _selectedAvatarUrl = image.path;
        });
        if (mounted) {
          AppSnackbar.success(
            context,
            'Profile photo selected! Tap "Save Changes" to apply.',
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not access camera/gallery: $e');
      }
    }
  }

  void _changeProfilePhoto() {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Change Profile Photo 📷',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_camera_rounded, color: AppColors.primary),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Use camera to capture photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select photo from your gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.face_rounded, color: AppColors.primary),
                ),
                title: const Text('3D Character Avatar'),
                subtitle: const Text('Use default high quality 3D avatar'),
                onTap: () {
                  Navigator.pop(ctx);
                  Haptics.success();
                  setState(() {
                    _pickedImageFile = null;
                    _selectedAvatarUrl = 'assets/images/user_avatar_3d.png';
                  });
                  AppSnackbar.success(context, '3D Character Avatar set!');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _editNameDialog() => _editFieldDialog(
        title: 'Edit Full Name ✏️',
        label: 'Full Name',
        hint: 'Enter your full name',
        buttonText: 'Update Name',
        controller: _nameController,
        validate: Validators.name,
      );

  void _editEmailDialog() => _editFieldDialog(
        title: 'Edit Email Address ✉️',
        label: 'Email Address',
        hint: 'name@example.com',
        buttonText: 'Update Email',
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        validate: Validators.email,
      );

  void _editPhoneDialog() => _editFieldDialog(
        title: 'Edit Phone Number 📞',
        label: 'Mobile Number',
        hint: '10-digit mobile number',
        buttonText: 'Update Phone',
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validate: Validators.phone,
      );

  /// One sheet for all three editable profile fields. They were three
  /// near-identical copies, and the copies had drifted: each accepted any
  /// non-empty string, so "x" passed as an email and "1" as a phone number.
  ///
  /// [validate] returns an error message, or null when the value is usable.
  /// A failing value keeps the sheet open with the reason under the field —
  /// a snackbar would be hidden behind the sheet.
  void _editFieldDialog({
    required String title,
    required String label,
    required String hint,
    required String buttonText,
    required TextEditingController controller,
    required String? Function(String) validate,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    Haptics.light();
    final tempController = TextEditingController(text: controller.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void submit() {
              Haptics.light();
              final value = tempController.text.trim();
              final message = validate(value);
              if (message != null) {
                setSheetState(() => error = message);
                return;
              }
              setState(() => controller.text = value);
              Navigator.pop(ctx);
            }

            return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: tempController,
                    keyboardType: keyboardType,
                    inputFormatters: formatters,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: hint,
                      errorText: error,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onChanged: (_) {
                      if (error != null) setSheetState(() => error = null);
                    },
                  ),
                  SizedBox(height: 18.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      onPressed: submit,
                      child: Text(buttonText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  Future<void> _selectDateOfBirth() async {
    Haptics.light();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  void _selectLanguageModal() {
    Haptics.light();
    final languages = ['English', 'Hindi (हिंदी)', 'Hinglish'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Language 🌐', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 12.h),
              ...languages.map((lang) {
                final isSel = _selectedLanguage.contains(lang.split(' ')[0]);
                return ListTile(
                  title: Text(lang, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                  trailing: isSel ? Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    Haptics.light();
                    setState(() => _selectedLanguage = lang.split(' ')[0]);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _saveChanges() async {
    Haptics.success();

    // The per-field sheets validate on the way in, but the controllers start
    // empty for a user who has not filled these yet, so re-check before the
    // values leave the screen.
    final invalid = Validators.name(_nameController.text) ??
        Validators.phone(_phoneController.text) ??
        Validators.email(_emailController.text);
    if (invalid != null) {
      AppSnackbar.error(context, invalid);
      return;
    }

    // A picked image has to be UPLOADED before it can be saved.
    //
    // This previously passed _pickedImageFile.path straight through as the
    // avatar URL — a local device path like /data/user/0/.../cache/img.jpg. The
    // file never left the phone, so the picture looked right until the next
    // refresh, when the profile reloaded from the server and that unloadable
    // path fell back to the bundled placeholder.
    String? avatarUrlToSave = _selectedAvatarUrl;
    if (_pickedImageFile != null) {
      try {
        avatarUrlToSave = await ref
            .read(authRemoteDataSourceProvider)
            .uploadProfileImage(_pickedImageFile!.path);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload your photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Stop rather than silently saving the old avatar — the user asked for
        // a new photo and needs to know it did not happen.
        return;
      }
    }

    final notifier = ref.read(authViewModelProvider.notifier);
    final saved = await notifier.updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          avatarUrl: avatarUrlToSave,
          dateOfBirth: _formatDate(_selectedDob),
        );

    if (!mounted) return;
    // Same reasoning as the avatar upload above: a save the server refused must
    // not be reported as a success, or the values revert on the next refresh
    // with the user believing they were stored.
    if (!saved) {
      AppSnackbar.error(
        context,
        notifier.lastError ?? 'Could not save your profile. Please try again.',
      );
      return;
    }

    AppSnackbar.success(
      context,
      'Profile information updated successfully! 🎉',
      duration: const Duration(seconds: 2),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB);
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final addresses = ref.watch(addressViewModelProvider);
    final homeAddressText = addresses.isNotEmpty
        ? addresses.first.fullAddress
        : '123, Shastri Nagar, Jaipur, Rajasthan 302016, India';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28.sp, color: textColor),
          onPressed: () {
            Haptics.light();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          children: [
            Text(
              'Edit Profile',
              style: TextStyle(
                color: textColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Update your profile information',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. AVATAR & PHOTO CHANGE SECTION
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 96.r,
                          height: 96.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryTintStrong,
                            border: Border.all(
                              color: AppColors.primarySoft,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _pickedImageFile != null
                                ? Image.file(_pickedImageFile!, fit: BoxFit.cover)
                                : (_selectedAvatarUrl != null && _selectedAvatarUrl!.startsWith('/')
                                    ? Image.file(File(_selectedAvatarUrl!), fit: BoxFit.cover)
                                    : Image.asset(
                                        'assets/images/user_avatar_3d.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.person_rounded,
                                          size: 54.sp,
                                          color: AppColors.primary,
                                        ),
                                      )),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _changeProfilePhoto,
                            child: Container(
                              padding: EdgeInsets.all(7.r),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 15.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    GestureDetector(
                      onTap: _changeProfilePhoto,
                      child: Text(
                        'Change Profile Photo',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'JPG, PNG or WEBP. Max size 2MB',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 2. PERSONAL INFORMATION CARD
              _buildSectionTitle('Personal Information', textColor),
              SizedBox(height: 8.h),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    // Full Name (Editable)
                    _buildEditableRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      value: _nameController.text.isEmpty ? 'Not added' : _nameController.text,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Icon(
                        Icons.edit_outlined,
                        size: 18.sp,
                        color: secondaryTextColor,
                      ),
                      onTap: _editNameDialog,
                    ),
                    _buildDivider(isDark),

                    // Mobile Number (Editable)
                    _buildEditableRow(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Mobile Number',
                      value: _phoneController.text.isEmpty ? 'Not added' : _phoneController.text,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVerifiedBadge(),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.edit_outlined,
                            size: 16.sp,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                      onTap: _editPhoneDialog,
                    ),
                    _buildDivider(isDark),

                    // Email Address (Editable!)
                    _buildEditableRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email Address',
                      value: _emailController.text.isEmpty ? 'Not added' : _emailController.text,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildVerifiedBadge(),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.edit_outlined,
                            size: 16.sp,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                      onTap: _editEmailDialog,
                    ),
                    _buildDivider(isDark),

                    // Date of Birth (Editable via DatePicker)
                    _buildEditableRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date of Birth',
                      value: _formatDate(_selectedDob),
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20.sp,
                        color: secondaryTextColor,
                      ),
                      onTap: _selectDateOfBirth,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 3. ADDRESS CARD
              _buildSectionTitle('Address', textColor),
              SizedBox(height: 8.h),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    // Home Address
                    _buildEditableRow(
                      icon: Icons.location_on_outlined,
                      label: 'Home Address',
                      value: homeAddressText,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                      actionWidget: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                      ),
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.addAddress);
                      },
                    ),
                    _buildDivider(isDark),

                    // Add Work Address
                    InkWell(
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.addAddress);
                      },
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.map_outlined,
                                color: AppColors.primary,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Work Address (Optional)',
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Add your work address for better delivery',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20.sp,
                              color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // 4. PREFERENCES CARD
              _buildSectionTitle('Preferences', textColor),
              SizedBox(height: 8.h),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    // Notification Preferences
                    InkWell(
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.notifications);
                      },
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: AppColors.primary,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notification Preferences',
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Manage your notification settings',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20.sp,
                              color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildDivider(isDark),

                    // Language
                    InkWell(
                      onTap: _selectLanguageModal,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.language_rounded,
                                color: AppColors.primary,
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Language',
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    _selectedLanguage,
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20.sp,
                              color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // 5. SAVE CHANGES BUTTON
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      border: Border.all(
        color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 14.w,
      endIndent: 14.w,
      color: isDark ? AppColors.borderDark : const Color(0xFFF2F2F2),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            size: 11.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
    Widget? actionWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (actionWidget != null) ...[
              SizedBox(width: 8.w),
              actionWidget,
            ],
          ],
        ),
      ),
    );
  }
}
