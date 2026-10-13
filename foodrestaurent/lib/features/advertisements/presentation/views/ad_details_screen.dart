import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/advertisements/domain/advertisement_model.dart';
import 'package:food_user_application/features/advertisements/presentation/controllers/advertisement_controller.dart';
import 'package:food_user_application/features/advertisements/presentation/widgets/ad_widgets.dart';

class AdDetailsScreen extends ConsumerWidget {
  const AdDetailsScreen({super.key, required this.adId});

  final String adId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(advertisementDetailProvider(adId));

    return Scaffold(
      backgroundColor: adBackground(context),
      appBar: AppBar(
        title: const Text('Ads Details'),
        backgroundColor: adCard(context),
        foregroundColor: adTextPrimary(context),
        elevation: 0,
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
                  adErrorText(e, 'Failed to load advertisement'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: adTextSecondary(context)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(advertisementDetailProvider(adId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (ad) => _Body(ad: ad),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.ad});

  final AdvertisementModel ad;

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryButton),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: adTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: adTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: adTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(fontSize: 14, color: adTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Ads ID #${ad.adsId}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: adTextPrimary(context),
                  ),
                ),
              ),
              AdStatusBadge(status: ad.status),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdCard(
          child: Column(
            children: [
              _row(context, Icons.event_outlined, 'Ads Created', ad.adsPlaced),
              _row(
                context,
                Icons.date_range_outlined,
                'Duration',
                '${ad.durationStart} - ${ad.durationEnd}',
              ),
              _row(context, Icons.campaign_outlined, 'Ads Details', ad.adsType),
              if (ad.paymentStatus.isNotEmpty)
                _row(
                  context,
                  Icons.payments_outlined,
                  'Payment Status',
                  ad.paymentStatus,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(context, 'Title', ad.title),
              _section(context, 'Description', ad.description),
              _section(context, 'Pause Note', ad.pauseNote),
              if (ad.imageUrl.isNotEmpty || ad.videoUrl.isNotEmpty)
                Text(
                  'Media',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: adTextPrimary(context),
                  ),
                ),
              if (ad.imageUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                AdNetworkImage(url: ad.imageUrl, height: 200),
              ],
              if (ad.videoUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined,
                        color: AppColors.primaryButton),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ad.videoDescription.isNotEmpty
                            ? ad.videoDescription
                            : 'Video attached',
                        style: TextStyle(color: adTextSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryButton,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => context.push('/advertisements/${ad.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit Advertisement'),
          ),
        ),
      ],
    );
  }
}
