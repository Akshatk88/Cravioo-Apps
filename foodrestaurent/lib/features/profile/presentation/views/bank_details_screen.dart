import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _accountHolderName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _confirmAccountNumber = TextEditingController();
  final _ifscCode = TextEditingController();
  final _upiId = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  XFile? _upiQrImage;
  String _existingUpiQrImageUrl = '';

  void _initializeFromRestaurant(RestaurantModel restaurant) {
    if (_initialized) return;
    _accountHolderName.text = restaurant.accountHolderName;
    _accountNumber.text = restaurant.accountNumber;
    _confirmAccountNumber.text = restaurant.accountNumber;
    _ifscCode.text = restaurant.ifscCode;
    _upiId.text = restaurant.upiId;
    _existingUpiQrImageUrl = restaurant.upiQrImage;
    _initialized = true;
  }

  @override
  void dispose() {
    _accountHolderName.dispose();
    _accountNumber.dispose();
    _confirmAccountNumber.dispose();
    _ifscCode.dispose();
    _upiId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_accountNumber.text.trim() != _confirmAccountNumber.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account numbers do not match.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final patch = <String, dynamic>{
        'accountHolderName': _accountHolderName.text.trim(),
        'accountNumber': _accountNumber.text.trim(),
        'ifscCode': _ifscCode.text.trim(),
        'upiId': _upiId.text.trim(),
      };
      if (_upiQrImage != null) {
        final url = await ref
            .read(restaurantRepositoryProvider)
            .uploadAttachment(_upiQrImage!, folder: 'others');
        patch['upiQrImage'] = url;
      }
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bank details saved.')));
        context.pop();
      }
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Something went wrong. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

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
        title: Text(
          'Bank & UPI Details',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: restaurantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            error is ApiException
                ? error.message
                : 'Failed to load bank details.',
          ),
        ),
        data: (restaurant) {
          _initializeFromRestaurant(restaurant);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel(context, 'Account holder name'),
                _buildTextField(context, _accountHolderName),
                const SizedBox(height: 16),
                _buildLabel(context, 'Account number'),
                _buildTextField(
                  context,
                  _accountNumber,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildLabel(context, 'Confirm account number'),
                _buildTextField(
                  context,
                  _confirmAccountNumber,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildLabel(context, 'IFSC code'),
                _buildTextField(context, _ifscCode),
                const SizedBox(height: 32),
                Container(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 32),
                Text(
                  'UPI details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _buildLabel(context, 'UPI ID'),
                _buildTextField(context, _upiId),
                const SizedBox(height: 16),
                _buildLabel(context, 'UPI QR image'),
                const SizedBox(height: 8),
                _buildQrPicker(context),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQrPicker(BuildContext context) {
    if (_upiQrImage != null) {
      return ImagePickerTile(
        label: '',
        image: _upiQrImage,
        height: 140,
        onPick: () async {
          final file = await pickImageWithSourceSheet(context);
          if (file != null) setState(() => _upiQrImage = file);
        },
        onRemove: () => setState(() => _upiQrImage = null),
      );
    }

    return GestureDetector(
      onTap: () async {
        final file = await pickImageWithSourceSheet(context);
        if (file != null) setState(() => _upiQrImage = file);
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceVariantDark
              : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: _existingUpiQrImageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: _existingUpiQrImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _qrPlaceholder(context),
                ),
              )
            : _qrPlaceholder(context),
      ),
    );
  }

  Widget _qrPlaceholder(BuildContext context) {
    return Center(
      child: Text(
        'Tap to upload QR',
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : const Color(0xFF9CA3AF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: const InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      ),
    );
  }
}
