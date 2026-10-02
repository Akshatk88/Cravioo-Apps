import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/promo_banner_model.dart';
import '../../../di/catalog_providers.dart';

/// Hero banner image URLs from `GET /food/hero-banners/public`.
///
/// Returns an empty list on failure so the header falls back to its video
/// slide rather than showing a broken carousel.
final heroBannersProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getHeroBannerImages();
  } catch (_) {
    return const [];
  }
});

/// Admin-uploaded promo banners for the home carousel.
///
/// Returns fallback local collection banners on failure or empty list,
/// ensuring the banner slider always renders on the home screen.
final promoBannersProvider = FutureProvider<List<PromoBannerModel>>((ref) async {
  try {
    final banners = await ref.watch(catalogRemoteDataSourceProvider).getPromoBanners();
    if (banners.isNotEmpty) {
      return [
        ...banners,
        const PromoBannerModel(
          id: 'banner_collections',
          imageUrl: 'assets/collectionspagebanner.png',
          title: 'Your Collections',
        ),
      ];
    }
  } catch (_) {}
  return const [
    PromoBannerModel(
      id: 'banner_collections',
      imageUrl: 'assets/collectionspagebanner.png',
      title: 'Your Collections',
    ),
    PromoBannerModel(
      id: 'banner_offer',
      imageUrl: 'assets/offerpagebanner.png',
      title: 'Special Offers',
    ),
    PromoBannerModel(
      id: 'banner_top10',
      imageUrl: 'assets/top10pagebanner.png',
      title: 'Top 10 Banners',
    ),
  ];
});

