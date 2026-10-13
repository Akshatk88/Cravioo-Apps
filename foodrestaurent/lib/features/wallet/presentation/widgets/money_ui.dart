import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';

/// Shared helpers for the wallet / reports / business-plan screens.
String moneyErrorMessage(Object error, [String fallback = 'Something went wrong']) {
  if (error is ApiException) return error.message;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner.message;
  }
  return fallback;
}

String formatInr(num? value, {int decimals = 2}) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimals,
  ).format(value ?? 0);
}

String formatDateTime(DateTime? d) {
  if (d == null) return 'N/A';
  return DateFormat('d MMM yyyy, hh:mm a').format(d.toLocal());
}

String formatDate(DateTime? d) {
  if (d == null) return 'N/A';
  return DateFormat('d MMM yyyy').format(d.toLocal());
}

num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

bool isDarkMode(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

class MoneyColors {
  MoneyColors(this.dark);
  final bool dark;

  Color get background => dark ? AppColors.backgroundDark : AppColors.backgroundLight;
  Color get surface => dark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get text => dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get subtext => dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get border => dark ? AppColors.borderDark : AppColors.borderLight;
  Color get primary => dark ? AppColors.primaryLight : AppColors.primaryButton;
}

class MoneyErrorView extends StatelessWidget {
  const MoneyErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = MoneyColors(isDarkMode(context));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.text)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class MoneyEmptyView extends StatelessWidget {
  const MoneyEmptyView({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = MoneyColors(isDarkMode(context));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.subtext.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.subtext, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

void showMoneySnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : null,
    ),
  );
}
