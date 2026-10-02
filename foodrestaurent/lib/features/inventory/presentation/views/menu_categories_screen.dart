import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/menu_categories/domain/category_model.dart';
import 'package:food_user_application/features/menu_categories/presentation/controllers/category_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class MenuCategoriesScreen extends ConsumerWidget {
  const MenuCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryControllerProvider);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu Categories',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Create categories, track approvals, and resubmit edits safely.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 11,
              ),
              maxLines: 2,
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: AppRefreshIndicator(
        onRefresh: () =>
            ref.read(categoryControllerProvider.notifier).refresh(),
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is ApiException
                      ? error.message
                      : 'Failed to load categories.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          data: (categories) => ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildHowThisWorksCard(context),
              const SizedBox(height: 24),
              _buildAddCategoryButton(context, ref),
              const SizedBox(height: 24),
              if (categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No categories yet. Add your first one above.',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                )
              else
                for (final category in categories) ...[
                  _buildCategoryCard(context, ref, category),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowThisWorksCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How this works',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New categories stay pending until admin approval. Editing an approved category sends it back for review. Only approved categories can be used for food uploads.',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF4A5568),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCategoryButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _showCategorySheet(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Category',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceVariantDark
                  : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: category.image.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: category.image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.fastfood, color: Colors.grey),
                    ),
                  )
                : Center(
                    child: Text(
                      category.name.isNotEmpty
                          ? category.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: category.isPending
                            ? Colors.orange.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: category.isPending
                              ? Colors.orange
                              : AppColors.primary,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.isPending
                                ? Icons.access_time
                                : Icons.check_circle_outline,
                            size: 12,
                            color: category.isPending
                                ? Colors.orange
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            category.isPending
                                ? 'Pending'
                                : (category.isApproved
                                      ? 'Approved'
                                      : 'Rejected'),
                            style: TextStyle(
                              color: category.isPending
                                  ? Colors.orange
                                  : AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        category.foodTypeScope,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${category.itemCount} item(s) linked',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
                if (category.approvalStatus == 'rejected' &&
                    category.rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rejected: ${category.rejectionReason}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _buildIconAction(
                context,
                Icons.edit_outlined,
                AppColors.primary,
                category.canEdit
                    ? () => _showCategorySheet(context, ref, existing: category)
                    : null,
              ),
              const SizedBox(height: 12),
              _buildIconAction(
                context,
                Icons.delete_outline,
                Colors.red,
                category.canDelete
                    ? () => _confirmDelete(context, ref, category)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction(
    BuildContext context,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceVariantDark
              : const Color(0xFFF5F6FA),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? color.withValues(alpha: 0.3) : color,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('This will permanently remove "${category.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(categoryControllerProvider.notifier).delete(category.id);
    } catch (e) {
      if (context.mounted) {
        final message = e is ApiException
            ? e.message
            : 'Failed to delete category.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCategorySheet(
    BuildContext context,
    WidgetRef ref, {
    CategoryModel? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateCategoryBottomSheet(existing: existing),
    );
  }
}

class CreateCategoryBottomSheet extends ConsumerStatefulWidget {
  const CreateCategoryBottomSheet({super.key, this.existing});

  final CategoryModel? existing;

  @override
  ConsumerState<CreateCategoryBottomSheet> createState() =>
      _CreateCategoryBottomSheetState();
}

class _CreateCategoryBottomSheetState
    extends ConsumerState<CreateCategoryBottomSheet> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _typeController = TextEditingController(
    text: widget.existing?.type ?? '',
  );
  late bool _keepActive = widget.existing?.isActive ?? true;
  late String _dietScope = widget.existing?.foodTypeScope ?? 'Veg';
  late String _existingImageUrl = widget.existing?.image ?? '';
  XFile? _pickedImage;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category name is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final restaurant = ref.read(restaurantProfileControllerProvider).value;
    if (restaurant != null &&
        restaurant.pureVegRestaurant &&
        _dietScope != 'Veg') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pure veg restaurants can only create Veg categories.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      var imageUrl = _existingImageUrl;
      if (_pickedImage != null) {
        imageUrl = await ref
            .read(restaurantRepositoryProvider)
            .uploadAttachment(_pickedImage!, folder: 'menu');
      }

      if (_isEditing) {
        await ref
            .read(categoryControllerProvider.notifier)
            .updateCategory(
              widget.existing!.id,
              name: name,
              foodTypeScope: _dietScope,
              type: _typeController.text.trim(),
              image: imageUrl,
              isActive: _keepActive,
            );
      } else {
        await ref
            .read(categoryControllerProvider.notifier)
            .create(
              name: name,
              foodTypeScope: _dietScope,
              type: _typeController.text.trim(),
              image: imageUrl,
              isActive: _keepActive,
            );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Category updated — pending re-approval.'
                  : 'Category submitted for approval.',
            ),
          ),
        );
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
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;
    final isPureVeg = restaurant?.pureVegRestaurant ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Edit Category' : 'Create Category',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEditing
                            ? 'Editing sends this category back for admin approval.'
                            : 'Choose the diet scope carefully before sending it for approval.',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LabeledTextField(
              label: 'Category Name',
              controller: _nameController,
              hint: 'Enter category name',
            ),
            const SizedBox(height: 16),
            const Text(
              'Diet Scope',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildDropdown(context, isPureVeg),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Optional Type Label',
              controller: _typeController,
              hint: 'Examples: Starters, Desserts, Drinks',
            ),
            const SizedBox(height: 16),
            _buildImagePicker(context),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _keepActive,
                    activeColor: Colors.blue,
                    onChanged: (value) =>
                        setState(() => _keepActive = value ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Keep category active',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
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
                          : Text(
                              _isEditing ? 'Save' : 'Create',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    if (_pickedImage != null) {
      return ImagePickerTile(
        label: 'Category image',
        image: _pickedImage,
        height: 120,
        onPick: () async {
          final file = await pickImageWithSourceSheet(context);
          if (file != null) setState(() => _pickedImage = file);
        },
        onRemove: () => setState(() {
          _pickedImage = null;
          _existingImageUrl = '';
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category image',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final file = await pickImageWithSourceSheet(context);
            if (file != null) setState(() => _pickedImage = file);
          },
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: _existingImageUrl.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: _existingImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _imagePlaceholder(),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _existingImageUrl = ''),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _imagePlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
        const SizedBox(height: 6),
        const Text(
          'Tap to upload image',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildDropdown(BuildContext context, bool isPureVeg) {
    final options = isPureVeg ? ['Veg'] : ['Veg', 'Non-Veg', 'Both'];
    if (!options.contains(_dietScope)) _dietScope = options.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _dietScope,
          items: options
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) setState(() => _dietScope = newValue);
          },
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
