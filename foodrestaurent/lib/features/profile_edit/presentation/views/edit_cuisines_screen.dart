import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

/// Pick up to 8 cuisines for the outlet. Mirrors web EditCuisines.jsx and
/// saves through `PATCH /food/restaurant/profile { cuisines }`.
class EditCuisinesScreen extends ConsumerStatefulWidget {
  const EditCuisinesScreen({super.key});

  @override
  ConsumerState<EditCuisinesScreen> createState() => _EditCuisinesScreenState();
}

class _EditCuisinesScreenState extends ConsumerState<EditCuisinesScreen> {
  static const int _maxCuisines = 8;

  static const List<String> _allCuisines = [
    'Burger',
    'Chinese',
    'Momos',
    'North Indian',
    'Pizza',
    'Rolls',
    'Sandwich',
    'Shawarma',
    'South Indian',
    'Biryani',
    'Desserts',
    'Ice Cream',
    'Fast Food',
    'Cafe',
    'Italian',
    'Mexican',
    'Thai',
    'Seafood',
    'Salad',
    'Healthy Food',
    'Juices',
    'Beverages',
    'Punjabi',
    'Gujarati',
    'Rajasthani',
    'Mughlai',
    'Street Food',
    'Bakery',
  ];

  static const Set<String> _recommended = {
    'Burger',
    'Chinese',
    'Momos',
    'North Indian',
    'Pizza',
    'Rolls',
    'Sandwich',
    'Shawarma',
  };

  final _search = TextEditingController();
  List<String> _selected = [];
  bool _initialised = false;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    final isSelected = _selected.contains(name);
    if (!isSelected && _selected.length >= _maxCuisines) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('You cannot select more than 8 cuisines'),
          ),
        );
      return;
    }
    setState(() {
      _selected = isSelected
          ? _selected.where((c) => c != name).toList()
          : [..._selected, name];
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile({'cuisines': _selected});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cuisines updated.')));
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Failed to update cuisines.',
          ),
          backgroundColor: AppColors.error,
        ),
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
          'Edit cuisines',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException ? e.message : 'Failed to load cuisines.',
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
          if (!_initialised) {
            _initialised = true;
            _selected = List<String>.from(restaurant.cuisines);
          }
          // Keep cuisines already saved on the outlet that are not in the
          // standard list so they can still be removed.
          final options = [
            ..._allCuisines,
            ..._selected.where((c) => !_allCuisines.contains(c)),
          ];
          final q = _search.text.trim().toLowerCase();
          final filtered = options
              .where((c) => c.toLowerCase().contains(q))
              .toList();
          final recommended = filtered
              .where((c) => _recommended.contains(c))
              .toList();
          final others = filtered
              .where((c) => !_recommended.contains(c))
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search cuisines',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_selected.length}/$_maxCuisines selected',
                        style: TextStyle(color: secondary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (recommended.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Recommended',
                                    style: TextStyle(
                                      color: onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryButton,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PRE APPROVED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'These cuisines will be updated instantly',
                              style: TextStyle(color: secondary, fontSize: 12),
                            ),
                            for (final name in recommended) _row(name, onSurface),
                          ],
                        ),
                      ),
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          children: [for (final name in others) _row(name, onSurface)],
                        ),
                      ),
                    ],
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No cuisines found',
                            style: TextStyle(color: secondary),
                          ),
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
                      onPressed: (_selected.isEmpty || _saving) ? null : _save,
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
                              'Update',
                              style: TextStyle(fontWeight: FontWeight.w800),
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

  Widget _row(String name, Color textColor) {
    final selected = _selected.contains(name);
    return InkWell(
      onTap: _saving ? null : () => _toggle(name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: TextStyle(color: textColor, fontSize: 14)),
            ),
            Icon(
              selected ? Icons.check_box_rounded : Icons.check_box_outline_blank,
              color: selected ? AppColors.primaryButton : textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
