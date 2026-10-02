import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../branding/app_colors.dart';

enum ImageCategory { restaurant, food, category, brand }

class SmartImage extends StatelessWidget {
  final String url;
  final ImageCategory category;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SmartImage({
    super.key,
    required this.url,
    required this.category,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder(context);
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final hasFiniteWidth = width != null && width!.isFinite;
    final cacheWidth = hasFiniteWidth ? (width! * dpr).round() : null;

    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => _skeleton(context),
        errorWidget: (context, url, error) => _placeholder(context),
      );
    }

    return Image.asset(
      url,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );
  }

  /// Brand wash used while an image loads and when it fails.
  ///
  /// Flat grey here was the single biggest reason the app read as empty: every
  /// slow or broken image — hero banners included — left a large neutral void.
  /// A magenta→teal wash means a missing photo still looks like Fudron.
  static LinearGradient _wash(bool isDark, {bool strong = false}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.primaryTintDark, AppColors.accentTintDark]
          : strong
              ? [AppColors.primaryTintStrong, AppColors.accentTintStrong]
              : [AppColors.primaryTint, AppColors.accentTint],
    );
  }

  Widget _skeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(gradient: _wash(isDark)),
    );
  }

  Widget _placeholder([BuildContext? context]) {
    final isDark =
        context != null && Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(gradient: _wash(isDark, strong: true)),
      alignment: Alignment.center,
      child: Icon(
        category == ImageCategory.food ? Icons.restaurant_rounded : Icons.storefront_rounded,
        color: isDark ? AppColors.accentLight : AppColors.accentDeep,
        size: (width != null && width! < 40) ? width! * 0.6 : 28,
      ),
    );
  }
}
