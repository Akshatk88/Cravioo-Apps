import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

const List<({String question, String answer})> _faqs = [
  (
    question: "How is my restaurant's rating calculated?",
    answer:
        "Your restaurant's rating is calculated based on customer reviews and ratings from delivery and dining orders. The system takes an average of all ratings received, with more recent reviews having slightly more weight.",
  ),
  (
    question: 'Why am I not getting rating on all orders?',
    answer:
        'Not all customers leave ratings after their orders. Some customers may skip the rating step, while others may not have the option to rate depending on the order type or platform. Typically, about 30-40% of customers provide ratings.',
  ),
  (
    question: 'Can I call customer to discuss rating?',
    answer:
        'Yes, you can contact customers through the order details page if they have provided a phone number. However, please be respectful and professional when discussing ratings.',
  ),
  (
    question:
        'How to raise a concern if I think rating was bad due to delivery partner?',
    answer:
        "If you believe a low rating was due to delivery partner issues, you can raise a concern through the order details page. Navigate to the specific order, click on 'Raise Concern', and select 'Delivery Partner Issue'.",
  ),
  (
    question: "What if I don't agree with the rating?",
    answer:
        "If you disagree with a customer's rating, you can reply to the review publicly to address concerns professionally. You can also raise a concern if you believe the rating violates our guidelines.",
  ),
  (
    question: 'How can I reply on a customer review?',
    answer:
        "To reply to a customer review, go to the Reviews section in your restaurant dashboard. Find the review you want to respond to and tap the 'Reply' button. Write a professional, courteous response.",
  ),
];

/// Ratings & reviews overview + help. The web page is static (FAQ and a
/// "was this helpful" prompt); the rating itself comes from the restaurant
/// profile (`rating`, `totalRatings`).
class RatingsReviewsScreen extends ConsumerStatefulWidget {
  const RatingsReviewsScreen({super.key});

  @override
  ConsumerState<RatingsReviewsScreen> createState() =>
      _RatingsReviewsScreenState();
}

class _RatingsReviewsScreenState extends ConsumerState<RatingsReviewsScreen> {
  final Set<int> _expanded = {};
  bool? _helpful;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final subColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final profile = ref.watch(restaurantProfileControllerProvider);
    final restaurant = profile.value;
    final total = restaurant?.totalRatings ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Ratings & reviews',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantProfileControllerProvider);
          try {
            await ref.read(restaurantProfileControllerProvider.future);
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your restaurant's rating",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.isLoading && restaurant == null
                              ? 'Loading...'
                              : profile.hasError && restaurant == null
                              ? 'Could not load rating. Pull to retry.'
                              : total > 0
                              ? 'Based on $total ratings'
                              : 'No ratings yet',
                          style: TextStyle(color: subColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: total > 0
                          ? AppColors.primaryButton
                          : AppColors.neutral400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (restaurant?.rating ?? 0).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Select your concern',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (var i = 0; i < _faqs.length; i++) ...[
                    InkWell(
                      onTap: () => setState(() {
                        if (!_expanded.add(i)) _expanded.remove(i);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _faqs[i].question,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Icon(
                              _expanded.contains(i)
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: textColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_expanded.contains(i))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _faqs[i].answer,
                          style: TextStyle(
                            color: subColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    if (i < _faqs.length - 1)
                      Divider(height: 1, color: borderColor),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_helpful == null) ...[
              Text(
                'Was this helpful in resolving your query?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _helpful = true),
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                      label: const Text('Yes, thank you'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _helpful = false),
                      icon: const Icon(
                        Icons.thumb_down_alt_outlined,
                        size: 18,
                      ),
                      label: const Text('Not helpful'),
                    ),
                  ),
                ],
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      _helpful! ? Icons.thumb_up : Icons.thumb_down,
                      color: _helpful! ? AppColors.primary : subColor,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _helpful! ? 'Thank you!' : "We're sorry",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _helpful!
                          ? "We're glad we could help resolve your query."
                          : "We're sorry this wasn't helpful. Please contact our support team for further assistance.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: subColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
