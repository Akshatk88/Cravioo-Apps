import 'package:flutter/material.dart';

/// Helper utility to display sleek, modern Toast notifications anywhere in the app.
class AppToast {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    IconData defaultIcon;

    if (isError) {
      bgColor = const Color(0xFFD32F2F); // Rich red
      defaultIcon = Icons.error_outline_rounded;
    } else if (isSuccess) {
      bgColor = const Color(0xFF2E7D32); // Rich green
      defaultIcon = Icons.check_circle_outline_rounded;
    } else {
      bgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFF1F1F1F); // Dark toast
      defaultIcon = Icons.info_outline_rounded;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: bgColor,
        duration: duration,
        elevation: 6,
        content: Row(
          children: [
            Icon(icon ?? defaultIcon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    show(context, message, isError: true);
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, isSuccess: true);
  }
}
