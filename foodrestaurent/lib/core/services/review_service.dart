import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

class ReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;

  /// Prompts the user for an in-app review if available on the device.
  static Future<void> requestReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        debugPrint("In-App Review: Prompting native review dialog.");
        await _inAppReview.requestReview();
      } else {
        debugPrint("In-App Review: API not available on this device.");
      }
    } catch (e) {
      debugPrint("In-App Review Error: $e");
    }
  }

  /// Triggers an in-app review prompt if the user provided a positive rating (rating >= 4).
  static Future<void> requestReviewIfEligible(int rating) async {
    if (rating >= 4) {
      debugPrint("In-App Review: User rated $rating/5 stars — requesting review.");
      await requestReview();
    } else {
      debugPrint("In-App Review: Rating ($rating/5) below threshold of 4. Skipping prompt.");
    }
  }

  /// Opens the store listing page in Play Store or App Store.
  static Future<void> openStoreListing({String? appStoreId}) async {
    try {
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint("In-App Review Error opening store listing: $e");
    }
  }
}
