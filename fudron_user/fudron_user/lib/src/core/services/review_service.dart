import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// Service for managing native store in-app review prompts (Google Play / App Store).
class ReviewService {
  /// Prompts the user for an in-app review if the rating is 4 or 5 stars and
  /// the native in-app review API is available on the device.
  static Future<void> requestReviewIfQualified(int rating) async {
    // Only request review for positive feedback (4 or 5 stars)
    if (rating < 4) {
      debugPrint(
        "In-App Review: Rating is $rating (< 4 stars). Skipping review prompt.",
      );
      return;
    }

    try {
      final InAppReview inAppReview = InAppReview.instance;

      final isAvailable = await inAppReview.isAvailable();
      if (isAvailable) {
        debugPrint(
          "In-App Review: API is available. Requesting review dialog...",
        );
        await inAppReview.requestReview();
      } else {
        debugPrint("In-App Review: API is not available on this device.");
      }
    } catch (e) {
      debugPrint("In-App Review Error: Failed to trigger in-app review: $e");
    }
  }
}
