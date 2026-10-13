import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';

bool adIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color adBackground(BuildContext context) =>
    adIsDark(context) ? AppColors.backgroundDark : AppColors.backgroundLight;

Color adCard(BuildContext context) =>
    adIsDark(context) ? AppColors.cardDark : AppColors.cardLight;

Color adBorder(BuildContext context) =>
    adIsDark(context) ? AppColors.borderDark : AppColors.borderLight;

Color adTextPrimary(BuildContext context) =>
    adIsDark(context) ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

Color adTextSecondary(BuildContext context) => adIsDark(context)
    ? AppColors.textSecondaryDark
    : AppColors.textSecondaryLight;

String adErrorText(Object e, [String fallback = 'Something went wrong']) {
  if (e is ApiException) return e.message;
  return fallback;
}

void adShowSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.primaryButton,
    ),
  );
}

class AdStatusBadge extends StatelessWidget {
  const AdStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'Approved' || 'Running' => (AppColors.primaryTint, AppColors.primaryDeep),
      'Pending' => (AppColors.warningLight, const Color(0xFFB45309)),
      'Rejected' => (AppColors.errorLight, const Color(0xFFB91C1C)),
      'Paused' => (const Color(0xFFE2E8F0), const Color(0xFF334155)),
      'Expired' => (const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      _ => (AppColors.infoLight, const Color(0xFF1D4ED8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class AdNetworkImage extends StatelessWidget {
  const AdNetworkImage({super.key, required this.url, this.height = 180});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, _) => SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => Container(
          height: height,
          color: adBorder(context),
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            color: adTextSecondary(context),
          ),
        ),
      ),
    );
  }
}

/// Thumbnail of a locally picked image.
class AdPickedImage extends StatelessWidget {
  const AdPickedImage({super.key, required this.file, this.height = 180});

  final XFile file;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            snap.data!,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: adCard(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: adBorder(context)),
          ),
          child: child,
        ),
      ),
    );
  }
}
