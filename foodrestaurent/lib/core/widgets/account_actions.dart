import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';

/// "Are you sure you want to logout?" — every logout entry point (Settings,
/// Explore, side drawer, application status) goes through this, so none of
/// them signs the restaurant out on a single accidental tap.
Future<bool> confirmLogoutDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Logout?'),
      content: const Text(
        'Are you sure you want to logout? You will need to verify your phone '
        'number again to log back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Logout',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Asks first, then logs out.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  if (await confirmLogoutDialog(context)) {
    await ref.read(authControllerProvider.notifier).logout();
  }
}

/// Asks first, then permanently deletes the restaurant account (with a
/// blocking progress dialog and an error message if it fails).
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Delete Account?'),
      content: const Text(
        'Are you sure you want to delete your account? This will permanently '
        'delete your restaurant profile, menu items, order history, and '
        'account data. This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete Account',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    ),
  );

  try {
    await ref.read(authControllerProvider.notifier).deleteAccount();
    // On success the router redirects to /login; the progress dialog lives on
    // the root navigator, so close it explicitly.
    if (navigator.mounted && navigator.canPop()) navigator.pop();
  } catch (e) {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiException.messageOf(
              e,
              fallback: 'Failed to delete account. Please try again.',
            ),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }
}
