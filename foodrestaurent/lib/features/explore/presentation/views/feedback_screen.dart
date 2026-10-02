import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/services/review_service.dart';
import 'package:food_user_application/features/feedback/data/feedback_repository.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int? _selectedRating;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == null) return;
    setState(() => _isSubmitting = true);
    try {
      final backendRating = (_selectedRating! / 2).ceil().clamp(1, 5);
      await ref
          .read(feedbackRepositoryProvider)
          .submit(
            rating: backendRating,
            comment: _commentController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your feedback!')),
        );
        context.pop();
        ReviewService.requestReviewIfEligible(backendRating);
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : 'Failed to submit feedback. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              if (context.canPop()) context.pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                'Share your feedback',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '0 to 10 rating scale where 0 is \'not at all likely\' and 10 is \'extremely likely\'',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 48),
              _buildRatingScale(context),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    hintText: 'Anything you\'d like to add? (optional)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildGraphic(context),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_selectedRating != null && !_isSubmitting)
                      ? _submit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingScale(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: List.generate(11, (index) {
        bool isSelected = _selectedRating == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedRating = index),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).cardColor,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGraphic(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildBar(Colors.red, 40),
        _buildBar(Colors.redAccent, 60),
        _buildBar(Colors.orange, 80),
        _buildBar(Colors.amber, 100),
        _buildBar(Colors.yellow, 120),
        _buildBar(Colors.lightGreen, 140),
        _buildBar(Colors.green, 160),
      ],
    );
  }

  Widget _buildBar(Color color, double height) {
    return Container(
      width: 16,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
    );
  }
}
