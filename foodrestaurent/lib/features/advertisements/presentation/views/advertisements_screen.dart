import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/advertisements/domain/advertisement_model.dart';
import 'package:food_user_application/features/advertisements/presentation/controllers/advertisement_controller.dart';
import 'package:food_user_application/features/advertisements/presentation/widgets/ad_widgets.dart';

class AdvertisementsScreen extends ConsumerStatefulWidget {
  const AdvertisementsScreen({super.key});

  @override
  ConsumerState<AdvertisementsScreen> createState() =>
      _AdvertisementsScreenState();
}

class _AdvertisementsScreenState extends ConsumerState<AdvertisementsScreen> {
  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
    ('paused', 'Paused'),
    ('expired', 'Expired'),
  ];

  String _filter = 'all';

  bool _matches(AdvertisementModel ad, String filter) {
    switch (filter) {
      case 'pending':
        return ad.status == 'Pending';
      case 'approved':
        return ad.isApproved;
      case 'rejected':
        return ad.status == 'Rejected';
      case 'paused':
        return ad.isPaused;
      case 'expired':
        return ad.status == 'Expired';
      default:
        return true;
    }
  }

  Future<void> _togglePause(AdvertisementModel ad) async {
    try {
      await ref.read(advertisementControllerProvider.notifier).togglePause(ad.id);
      if (mounted) adShowSnack(context, 'Advertisement status updated');
    } catch (e) {
      if (mounted) {
        adShowSnack(
          context,
          adErrorText(e, 'Failed to update advertisement'),
          error: true,
        );
      }
    }
  }

  Future<void> _delete(AdvertisementModel ad) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete advertisement?'),
        content: Text('Ads ID # ${ad.adsId} will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(advertisementControllerProvider.notifier).delete(ad.id);
      if (mounted) adShowSnack(context, 'Advertisement deleted');
    } catch (e) {
      if (mounted) {
        adShowSnack(
          context,
          adErrorText(e, 'Failed to delete advertisement'),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(advertisementControllerProvider);
    final ads = async.value ?? const <AdvertisementModel>[];

    return Scaffold(
      backgroundColor: adBackground(context),
      appBar: AppBar(
        title: const Text('Advertisements'),
        backgroundColor: adCard(context),
        foregroundColor: adTextPrimary(context),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/advertisements/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (id, label) = _filters[i];
                final count = ads.where((a) => _matches(a, id)).length;
                final selected = _filter == id;
                return ChoiceChip(
                  label: Text('$label ($count)'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryButton,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : adTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _filter = id),
                );
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: adErrorText(e, 'Failed to load advertisements'),
                onRetry: () =>
                    ref.read(advertisementControllerProvider.notifier).refresh(),
              ),
              data: (list) {
                final filtered = list.where((a) => _matches(a, _filter)).toList();
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(advertisementControllerProvider.notifier).refresh(),
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 300,
                              child: Center(
                                child: Text(
                                  'No advertisements found',
                                  style: TextStyle(
                                    color: adTextSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _AdTile(
                            ad: filtered[i],
                            onPause: () => _togglePause(filtered[i]),
                            onDelete: () => _delete(filtered[i]),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdTile extends StatelessWidget {
  const _AdTile({
    required this.ad,
    required this.onPause,
    required this.onDelete,
  });

  final AdvertisementModel ad;
  final VoidCallback onPause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AdCard(
      onTap: () => context.push('/advertisements/${ad.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Ads ID # ${ad.adsId}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: adTextPrimary(context),
                      ),
                    ),
                    AdStatusBadge(status: ad.status),
                  ],
                ),
                const SizedBox(height: 6),
                if (ad.title.isNotEmpty)
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: adTextPrimary(context),
                    ),
                  ),
                Text(
                  ad.adsType,
                  style: TextStyle(
                    fontSize: 13,
                    color: adTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ads Placed: ${ad.adsPlaced}',
                  style: TextStyle(
                    fontSize: 12,
                    color: adTextSecondary(context),
                  ),
                ),
                Text(
                  'Duration: ${ad.durationStart} - ${ad.durationEnd}',
                  style: TextStyle(
                    fontSize: 12,
                    color: adTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: adTextSecondary(context)),
            onSelected: (v) {
              switch (v) {
                case 'view':
                  context.push('/advertisements/${ad.id}');
                case 'edit':
                  context.push('/advertisements/${ad.id}/edit');
                case 'pause':
                  onPause();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'view', child: Text('View Ads')),
              const PopupMenuItem(value: 'edit', child: Text('Edit Ads')),
              PopupMenuItem(
                value: 'pause',
                child: Text(ad.isPaused ? 'Resume Ads' : 'Pause Ads'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete Ads',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: adTextSecondary(context)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
