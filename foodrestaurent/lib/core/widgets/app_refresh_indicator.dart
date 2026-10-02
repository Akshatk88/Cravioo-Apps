import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/services/audio_service.dart';

class AppRefreshIndicator extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;
  final Color? color;
  final Color? backgroundColor;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      displacement: displacement,
      color: color,
      backgroundColor: backgroundColor,
      onRefresh: () async {
        ref.read(audioServiceProvider).playRefreshSound();
        await onRefresh();
      },
      child: child,
    );
  }
}
