import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/registration/presentation/controllers/registration_controller.dart';
import 'package:food_user_application/features/registration/presentation/views/steps/step1_restaurant_info.dart';
import 'package:food_user_application/features/registration/presentation/views/steps/step2_location.dart';
import 'package:food_user_application/features/registration/presentation/views/steps/step3_documents.dart';
import 'package:food_user_application/features/registration/presentation/views/steps/step4_bank_review.dart';
import 'package:food_user_application/features/registration/presentation/widgets/step_progress_header.dart';

const _stepTitles = [
  'Restaurant Info',
  'Location & Timings',
  'Documents & Compliance',
  'Bank & Review',
];

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.initialPhone,
    this.initialToken,
  });

  final String initialPhone;
  final String? initialToken;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _pageController = PageController();
  final List<bool> _stepValid = [false, false, false, false];
  bool _hasHandledSubmitSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(registrationControllerProvider.notifier);
      notifier.prefillPhone(widget.initialPhone);
      if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
        notifier.setRegistrationToken(widget.initialToken!);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDiscard() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard application?'),
        content: const Text('Your progress on this registration will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (shouldDiscard == true && mounted) {
      context.go('/login');
    }
  }

  void _onNext(int currentStep) {
    if (currentStep == 3) {
      ref.read(registrationControllerProvider.notifier).submit();
      return;
    }
    ref.read(registrationControllerProvider.notifier).nextStep();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _onBack(int currentStep) {
    if (currentStep == 0) {
      _confirmDiscard();
      return;
    }
    ref.read(registrationControllerProvider.notifier).previousStep();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(registrationControllerProvider);

    ref.listen(registrationControllerProvider, (previous, next) {
      if (next.submitError != null &&
          next.submitError != previous?.submitError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.submitError!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      if (next.isSubmitted && !_hasHandledSubmitSuccess) {
        _hasHandledSubmitSuccess = true;
        context.go('/register/success');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F2),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _confirmDiscard,
                    icon: const Icon(Icons.close, color: Colors.black87),
                  ),
                  const Expanded(
                    child: Text(
                      'Restaurant onboarding',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: StepProgressHeader(
                currentStep: uiState.currentStep,
                stepTitles: _stepTitles,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Step1RestaurantInfo(
                    onValidityChanged: (v) => setState(() => _stepValid[0] = v),
                  ),
                  Step2Location(
                    onValidityChanged: (v) => setState(() => _stepValid[1] = v),
                  ),
                  Step3Documents(
                    onValidityChanged: (v) => setState(() => _stepValid[2] = v),
                  ),
                  Step4BankReview(
                    onValidityChanged: (v) => setState(() => _stepValid[3] = v),
                  ),
                ],
              ),
            ),
            if (!_stepValid[uiState.currentStep])
              _buildMissingFieldsHint(uiState.currentStep),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: uiState.isSubmitting
                            ? null
                            : () => _onBack(uiState.currentStep),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          uiState.currentStep == 0 ? 'Cancel' : 'Back',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_stepValid[uiState.currentStep] &&
                                !uiState.isSubmitting)
                            ? () => _onNext(uiState.currentStep)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: uiState.isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                uiState.currentStep == 3
                                    ? 'Submit Application'
                                    : 'Next',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingFieldsHint(int currentStep) {
    final missing = ref
        .read(registrationControllerProvider.notifier)
        .form
        .missingFieldsForStep(currentStep);
    if (missing.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'To continue, please complete:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...missing.map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                  '•  $item',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
