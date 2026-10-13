import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/help/data/page_content_repository.dart';
import 'package:food_user_application/features/help/domain/page_content_model.dart';

/// Public CMS pages are not restaurant-specific, so there is nothing here that
/// needs resetting on logout. Auto-disposed so a re-open always re-fetches.
final pageContentProvider = FutureProvider.autoDispose
    .family<PageContentModel, PageContentKey>((ref, key) {
      return ref
          .read(pageContentRepositoryProvider)
          .fetch(key.apiKey, fallbackTitle: key.fallbackTitle);
    });

enum PageContentKey {
  privacy('privacy', 'Privacy Policy'),
  terms('terms', 'Terms and Conditions'),
  support('support', 'Support');

  const PageContentKey(this.apiKey, this.fallbackTitle);

  final String apiKey;
  final String fallbackTitle;
}
