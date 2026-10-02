import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';

/// Shown after OTP login when the restaurant tied to that phone number is
/// `pending` (awaiting admin approval) or `rejected`. There's no dashboard
/// to fall back to in either case — this screen is a dead end until the
/// backend status changes.
class ApplicationStatusScreen extends ConsumerWidget {
  const ApplicationStatusScreen({
    super.key,
    required this.status,
    required this.message,
  });

  final String status;
  final String message;

  bool get _isRejected => status == 'rejected';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _isRejected
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRejected
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  color: _isRejected ? AppColors.error : AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _isRejected
                    ? 'Application Rejected'
                    : 'Application Under Review',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.support_agent,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Questions about your application? Reach out to our partner support team.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
