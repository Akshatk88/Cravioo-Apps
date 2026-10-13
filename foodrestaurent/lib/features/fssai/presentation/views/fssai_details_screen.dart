import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

/// Read-only view of the restaurant's FSSAI licence, with a button to the
/// update screen. Mirrors web FssaiDetails.jsx.
class FssaiDetailsScreen extends ConsumerWidget {
  const FssaiDetailsScreen({super.key});

  static const String updateRoute = '/fssai/update';

  static String formatExpiry(String raw) {
    if (raw.trim().isEmpty) return 'Not available';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('d MMMM yyyy').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restaurantProfileControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

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
          'FSSAI details',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException
                      ? e.message
                      : 'Failed to load FSSAI details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref
                      .read(restaurantProfileControllerProvider.notifier)
                      .refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (restaurant) {
          final hasFssai = restaurant.fssaiNumber.trim().isNotEmpty;
          final hasImage = restaurant.fssaiImage.trim().isNotEmpty;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      hasFssai
                          ? 'Manage your restaurant license data.'
                          : 'No live restaurant license data available.',
                      style: TextStyle(color: secondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    if (!hasFssai)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FSSAI details are not available',
                                    style: TextStyle(
                                      color: onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Upload your license information to manage compliance here.',
                                    style: TextStyle(
                                      color: secondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('FSSAI registration number', secondary),
                          _value(
                            hasFssai ? restaurant.fssaiNumber : 'Not available',
                            hasFssai ? onSurface : secondary,
                          ),
                          const Divider(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Document', secondary),
                                    _value(
                                      hasImage
                                          ? 'FSSAI License Document'
                                          : 'No document uploaded',
                                      hasImage ? onSurface : secondary,
                                    ),
                                  ],
                                ),
                              ),
                              if (hasImage)
                                OutlinedButton.icon(
                                  onPressed: () => _viewDocument(
                                    context,
                                    restaurant.fssaiImage,
                                  ),
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('View'),
                                ),
                            ],
                          ),
                          const Divider(height: 28),
                          _label('Valid up to', secondary),
                          _value(
                            formatExpiry(restaurant.fssaiExpiry),
                            restaurant.fssaiExpiry.isNotEmpty
                                ? onSurface
                                : secondary,
                          ),
                        ],
                      ),
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
                      onPressed: () => context.push(updateRoute),
                      child: Text(
                        hasFssai ? 'Update FSSAI license' : 'Add FSSAI license',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _label(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TextStyle(color: color, fontSize: 12)),
  );

  Widget _value(String text, Color color) => Text(
    text,
    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
  );

  void _viewDocument(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('FSSAI License Document'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) => const CircularProgressIndicator(),
                errorWidget: (_, _, _) => const Text(
                  'Could not load document.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
