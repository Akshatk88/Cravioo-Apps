import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/fssai/data/fssai_repository.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart'
    show pickImageWithSourceSheet;
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

/// Update FSSAI number / expiry / licence image. Mirrors web FssaiUpdate.jsx.
/// For an approved outlet the backend stages the change for admin review.
class FssaiUpdateScreen extends ConsumerStatefulWidget {
  const FssaiUpdateScreen({super.key});

  @override
  ConsumerState<FssaiUpdateScreen> createState() => _FssaiUpdateScreenState();
}

class _FssaiUpdateScreenState extends ConsumerState<FssaiUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  DateTime? _expiry;
  DateTime? _originalExpiry;
  String _existingImageUrl = '';
  XFile? _newImage;
  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _initFrom(String number, String expiryRaw, String imageUrl) {
    if (_initialised) return;
    _initialised = true;
    _number.text = number;
    final parsed = DateTime.tryParse(expiryRaw)?.toLocal();
    if (parsed != null) {
      _expiry = DateTime(parsed.year, parsed.month, parsed.day);
      _originalExpiry = _expiry;
    }
    _existingImageUrl = imageUrl;
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickDate() async {
    final today = _today;
    var first = today;
    if (_originalExpiry != null && _originalExpiry!.isAfter(today)) {
      first = _originalExpiry!;
    }
    var initial = _expiry ?? first;
    if (initial.isBefore(first)) initial = first;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(today.year + 30),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _pickImage() async {
    final file = await pickImageWithSourceSheet(context);
    if (file == null) return;
    final size = await file.length();
    if (size > 5 * 1024 * 1024) {
      _snack('Image size too large. Max 5MB allowed.', error: true);
      return;
    }
    setState(() => _newImage = file);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_expiry == null) {
      _snack('Expiry date is required', error: true);
      return;
    }
    if (_expiry!.isBefore(_today)) {
      _snack('Expiry date must be in the future', error: true);
      return;
    }
    if (_newImage == null && _existingImageUrl.isEmpty) {
      _snack('FSSAI license document is required', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      var imageUrl = _existingImageUrl;
      if (_newImage != null) {
        imageUrl = await ref
            .read(restaurantRepositoryProvider)
            .uploadAttachment(_newImage!, folder: 'fssai');
        if (imageUrl.isEmpty) {
          throw ApiException('Failed to upload the license document.');
        }
      }
      final result = await ref
          .read(fssaiRepositoryProvider)
          .update(
            number: _number.text.trim(),
            expiry: DateFormat('yyyy-MM-dd').format(_expiry!),
            imageUrl: imageUrl,
          );
      await ref.read(restaurantProfileControllerProvider.notifier).refresh();
      if (!mounted) return;
      _snack(
        result.pendingReviewSubmitted
            ? 'FSSAI update submitted for admin review. Customers still see your previous approved details until approved.'
            : 'FSSAI details updated and sent for admin review',
      );
      if (mounted && context.canPop()) context.pop();
    } catch (e) {
      _snack(
        e is ApiException ? e.message : 'Failed to update FSSAI details.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(restaurantProfileControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: onSurface,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          'Update FSSAI',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Failed to load current details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondary),
            ),
          ),
        ),
        data: (restaurant) {
          _initFrom(
            restaurant.fssaiNumber,
            restaurant.fssaiExpiry,
            restaurant.fssaiImage,
          );
          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        'FSSAI registration number',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _number,
                        keyboardType: TextInputType.number,
                        maxLength: 14,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: '14-digit registration number',
                          helperText: 'Exactly 14 digits required',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'FSSAI number is required';
                          if (!RegExp(r'^\d{14}$').hasMatch(value)) {
                            return 'FSSAI number must be exactly 14 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Valid up to',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _expiry == null
                                      ? 'Select expiry date'
                                      : DateFormat(
                                          'd MMMM yyyy',
                                        ).format(_expiry!),
                                  style: TextStyle(
                                    color: _expiry == null
                                        ? secondary
                                        : onSurface,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Upload your FSSAI license',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _saving ? null : _pickImage,
                        child: Container(
                          height: 170,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: _imagePreview(secondary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'JPEG or PNG image, up to 5MB.',
                        style: TextStyle(color: secondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _imagePreview(Color secondary) {
    if (_newImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: kIsWeb
            ? Image.network(_newImage!.path, fit: BoxFit.cover)
            : Image.file(
                File(_newImage!.path),
                fit: BoxFit.cover,
                cacheHeight: 600,
              ),
      );
    }
    if (_existingImageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: _existingImageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tap to replace',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.cloud_upload_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(height: 6),
        Text('Tap to upload', style: TextStyle(color: secondary, fontSize: 12)),
      ],
    );
  }
}
