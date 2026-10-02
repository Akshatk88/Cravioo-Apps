import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/utils/multipart_utils.dart';
import 'package:food_user_application/features/dining/domain/dining_profile_model.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_profile_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

class DiningRequestScreen extends ConsumerStatefulWidget {
  const DiningRequestScreen({super.key});

  @override
  ConsumerState<DiningRequestScreen> createState() => _DiningRequestScreenState();
}

class _DiningRequestScreenState extends ConsumerState<DiningRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _aboutCtrl = TextEditingController();
  final _costForTwoCtrl = TextEditingController();
  final _seatingCapacityCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _cuisinesCtrl = TextEditingController();
  final _amenitiesCtrl = TextEditingController();

  final List<String> _selectedCategoryIds = [];
  List<DiningCategoryOption> _directCategories = [];
  bool _loadingCategories = false;
  XFile? _coverImage;
  final List<XFile> _galleryFiles = [];

  bool _initialized = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchDirectCategories();
  }

  Future<void> _fetchDirectCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final dio = Dio(BaseOptions(baseUrl: 'https://cravioo.in/api/v1'));
      final res = await dio.get('/food/dining/categories');
      final data = Map<String, dynamic>.from(res.data as Map);
      final inner = Map<String, dynamic>.from(data['data'] as Map? ?? {});
      final items = (inner['items'] as List? ?? []);
      final list = items
          .map((c) => DiningCategoryOption.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _directCategories = list;
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  @override
  void dispose() {
    _aboutCtrl.dispose();
    _costForTwoCtrl.dispose();
    _seatingCapacityCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _cuisinesCtrl.dispose();
    _amenitiesCtrl.dispose();
    super.dispose();
  }

  void _populateExisting(DiningProfileModel profile) {
    if (_initialized) return;
    _initialized = true;

    _aboutCtrl.text = profile.about;
    _costForTwoCtrl.text = profile.costForTwo > 0 ? profile.costForTwo.toStringAsFixed(0) : '';
    _seatingCapacityCtrl.text = profile.seatingCapacity > 0 ? profile.seatingCapacity.toString() : '';
    _contactNameCtrl.text = profile.contactName;
    _contactPhoneCtrl.text = profile.contactPhone;
    _cuisinesCtrl.text = profile.cuisines.join(', ');
    _amenitiesCtrl.text = profile.amenities.join(', ');

    _selectedCategoryIds.clear();
    for (final c in profile.categories) {
      _selectedCategoryIds.add(c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diningProfileControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dining-bookings');
            }
          },
        ),
        title: const Text(
          'Dining Request & Setup',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              _fetchDirectCategories();
              ref.read(diningProfileControllerProvider.notifier).refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_restaurant_rounded),
            tooltip: 'View Bookings',
            onPressed: () => context.push('/dining-bookings'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(diningProfileControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final profile = data.profile;
          if (profile != null) {
            _populateExisting(profile);
          } else if (!_initialized) {
            final restaurant = ref.read(restaurantProfileControllerProvider).value;
            if (restaurant != null) {
              _contactNameCtrl.text = restaurant.restaurantName;
              _contactPhoneCtrl.text = restaurant.primaryContactNumber.replaceAll('+91', '').trim();
            }
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile != null) ...[
                    _buildStatusBanner(profile),
                    const SizedBox(height: 16),
                  ],

                  // Intro card
                  _buildIntroCard(),
                  const SizedBox(height: 20),

                  // Section 1: Basic Dining Info
                  _buildSectionTitle('1. BASIC DINING DETAILS'),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildTextField(
                        controller: _aboutCtrl,
                        label: 'About Dining & Ambience *',
                        hint: 'Describe your dining experience, seating vibe, specialties (min 20 chars)',
                        maxLines: 3,
                        validator: (v) {
                          if (v == null || v.trim().length < 20) {
                            return 'Please enter at least 20 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _costForTwoCtrl,
                              label: 'Cost for Two (₹) *',
                              hint: 'e.g. 800',
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildTextField(
                              controller: _seatingCapacityCtrl,
                              label: 'Seating Capacity *',
                              hint: 'e.g. 50',
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Categories
                  _buildSectionTitle('2. DINING CATEGORIES *'),
                  const SizedBox(height: 10),
                  _buildCategoriesSection(data.availableCategories),
                  const SizedBox(height: 20),

                  // Section 3: Cuisines & Amenities
                  _buildSectionTitle('3. CUISINES & AMENITIES'),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildTextField(
                        controller: _cuisinesCtrl,
                        label: 'Cuisines (Comma separated)',
                        hint: 'e.g. North Indian, Chinese, Italian, Continental',
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _amenitiesCtrl,
                        label: 'Amenities (Comma separated)',
                        hint: 'e.g. AC, Valet Parking, Rooftop, Live Music, Wifi',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Contact details
                  _buildSectionTitle('4. DINING MANAGER CONTACT'),
                  const SizedBox(height: 10),
                  _buildCard(
                    children: [
                      _buildTextField(
                        controller: _contactNameCtrl,
                        label: 'Contact Person Name *',
                        hint: 'Manager / Owner name',
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _contactPhoneCtrl,
                        label: '10-Digit Contact Phone *',
                        hint: 'e.g. 9876543210',
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          final clean = v?.replaceAll('+91', '').replaceAll(' ', '').trim() ?? '';
                          if (clean.length != 10) return 'Must be 10 digits';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 5: Photos (Cover & Gallery)
                  _buildSectionTitle('5. DINING PHOTOS'),
                  const SizedBox(height: 10),
                  _buildPhotosSection(profile),
                  const SizedBox(height: 30),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : () => _submit(profile),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              profile != null && profile.isApproved
                                  ? 'Update Dining Details'
                                  : 'Submit Dining Request',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(DiningProfileModel profile) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String title;
    String desc;

    if (profile.isApproved) {
      bg = AppColors.primaryTint;
      border = AppColors.primary;
      text = AppColors.primaryDark;
      icon = Icons.verified_rounded;
      title = 'Dining Request Approved & Active';
      desc = 'Your restaurant is live for table booking. Customers can reserve tables anytime.';
    } else if (profile.isPending) {
      bg = const Color(0xFFFEF3C7);
      border = const Color(0xFFD97706);
      text = const Color(0xFF92400E);
      icon = Icons.hourglass_top_rounded;
      title = 'Dining Request Under Review';
      desc = 'Your dining application has been submitted to Cravioo Admin for approval.';
    } else if (profile.isRejected) {
      bg = const Color(0xFFFEE2E2);
      border = const Color(0xFFDC2626);
      text = const Color(0xFF991B1B);
      icon = Icons.cancel_rounded;
      title = 'Dining Request Rejected';
      desc = profile.rejectionReason.isNotEmpty
          ? 'Reason: ${profile.rejectionReason}. Please make corrections and re-submit.'
          : 'Please correct details and re-submit.';
    } else {
      bg = Colors.grey[200]!;
      border = Colors.grey;
      text = Colors.black87;
      icon = Icons.pause_circle_rounded;
      title = 'Dining Suspended';
      desc = 'Dining is temporarily paused. Contact support for assistance.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: text, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: text.withValues(alpha: 0.9), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTint.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.table_restaurant_rounded, color: AppColors.primaryDark, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Apply for Cravioo Dining to accept table reservations from nearby customers directly in your restaurant app.',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildCategoriesSection(List<DiningCategoryOption> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveCategories = categories.isNotEmpty ? categories : _directCategories;

    if (_loadingCategories && effectiveCategories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (effectiveCategories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No dining categories created by Admin yet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Please add at least one Dining Category from Admin Panel (Dining Management -> Dining Categories). Then click refresh below.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _fetchDirectCategories();
                ref.read(diningProfileControllerProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Categories'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: effectiveCategories.map((cat) {
          final isSelected = _selectedCategoryIds.contains(cat.id);
          return FilterChip(
            label: Text(cat.name),
            selected: isSelected,
            onSelected: (val) {
              setState(() {
                if (val) {
                  _selectedCategoryIds.add(cat.id);
                } else {
                  _selectedCategoryIds.remove(cat.id);
                }
              });
            },
            selectedColor: AppColors.primaryTint,
            checkmarkColor: AppColors.primaryDark,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primaryDark : (isDark ? Colors.white : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPhotosSection(DiningProfileModel? profile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picker = ImagePicker();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          const Text('Cover Image *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (picked != null) setState(() => _coverImage = picked);
            },
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isDark ? Colors.grey[900] : const Color(0xFFF3F4F6),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: _coverImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_coverImage!.path), fit: BoxFit.cover),
                    )
                  : profile?.coverImage.isNotEmpty == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: profile!.coverImage,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 36, color: AppColors.primary),
                              SizedBox(height: 6),
                              Text('Tap to pick cover image', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
            ),
          ),

          const SizedBox(height: 18),

          // Gallery Images
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gallery / Ambience Photos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  try {
                    final list = await picker.pickMultiImage(imageQuality: 85);
                    if (list.isNotEmpty) {
                      setState(() => _galleryFiles.addAll(list));
                      return;
                    }
                  } catch (_) {}
                  // Fallback for devices where pickMultiImage doesn't trigger or returns empty
                  try {
                    final single = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (single != null) {
                      setState(() => _galleryFiles.add(single));
                    }
                  } catch (_) {}
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Add Photos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_galleryFiles.isNotEmpty || (profile?.gallery.isNotEmpty ?? false))
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._galleryFiles.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(f.path), width: 80, height: 80, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  if (profile != null)
                    ...profile.gallery.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            const Text('No gallery photos selected yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _submit(DiningProfileModel? existing) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one dining category')),
      );
      return;
    }
    if (existing == null && _coverImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cover image')),
      );
      return;
    }
    // If no gallery images picked yet, auto fallback to cover image so the user is never blocked
    if (_galleryFiles.isEmpty && (existing == null || existing.gallery.isEmpty)) {
      if (_coverImage != null) {
        _galleryFiles.add(_coverImage!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one gallery image')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final formData = FormData();
      formData.fields.add(MapEntry('about', _aboutCtrl.text.trim()));
      formData.fields.add(MapEntry('costForTwo', _costForTwoCtrl.text.trim()));
      formData.fields.add(MapEntry('seatingCapacity', _seatingCapacityCtrl.text.trim()));
      formData.fields.add(MapEntry('contactName', _contactNameCtrl.text.trim()));
      final cleanPhone = _contactPhoneCtrl.text.replaceAll('+91', '').replaceAll(' ', '').trim();
      formData.fields.add(MapEntry('contactPhone', cleanPhone));

      // Categories
      for (final catId in _selectedCategoryIds) {
        formData.fields.add(MapEntry('categories[]', catId));
      }

      // Cuisines
      final cuisines = _cuisinesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .filter((e) => e.isNotEmpty)
          .toList();
      for (final c in cuisines) {
        formData.fields.add(MapEntry('cuisines[]', c));
      }

      // Amenities
      final amenities = _amenitiesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .filter((e) => e.isNotEmpty)
          .toList();
      for (final a in amenities) {
        formData.fields.add(MapEntry('amenities[]', a));
      }

      // Upload Cover
      if (_coverImage != null) {
        formData.files.add(MapEntry('coverImage', await xFileToMultipart(_coverImage!)));
      }

      // Upload Gallery
      for (final g in _galleryFiles) {
        formData.files.add(MapEntry('gallery', await xFileToMultipart(g)));
      }

      final res = await ref.read(diningProfileControllerProvider.notifier).submitProfile(formData);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dining request submitted successfully!'),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

extension _IterableFilter<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E element) test) => where(test);
}
