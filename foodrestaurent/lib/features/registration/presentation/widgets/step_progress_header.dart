import 'package:flutter/material.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

/// The numbered step indicator + "STEP X OF 4" / percentage badge shown atop
/// the registration wizard.
class StepProgressHeader extends StatelessWidget {
  const StepProgressHeader({
    super.key,
    required this.currentStep,
    required this.stepTitles,
  });

  final int currentStep; // 0-indexed
  final List<String> stepTitles;

  @override
  Widget build(BuildContext context) {
    final total = stepTitles.length;
    final percent = (((currentStep + 1) / total) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total * 2 - 1, (i) {
            if (i.isOdd) {
              final leftStepDone = (i - 1) ~/ 2 < currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: leftStepDone ? AppColors.primary : Colors.black12,
                ),
              );
            }
            final stepIndex = i ~/ 2;
            final isDone = stepIndex < currentStep;
            final isCurrent = stepIndex == currentStep;
            return Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDone || isCurrent) ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: (isDone || isCurrent)
                      ? AppColors.primary
                      : Colors.black12,
                  width: 1.5,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.black38,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STEP ${currentStep + 1} OF $total',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$percent%',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          stepTitles[currentStep],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
