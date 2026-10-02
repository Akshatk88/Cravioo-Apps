import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/services/update_service.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  late Animation<double> _imageOpacity;
  late Animation<double> _imageScale;
  late Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    // Check app update
    UpdateService.checkForUpdate();

    // Hide status bar during splash screen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Splash image fade + smooth scale
    _imageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    _imageScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // Loading dots appear after image
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.25, 0.50, curve: Curves.easeIn),
      ),
    );

    _animationController.forward().then((_) {
      _resolveDestination();
    });
  }

  Future<void> _resolveDestination() async {
    await ref.read(authControllerProvider.notifier).checkSession();

    if (!mounted) return;

    switch (ref.read(authControllerProvider)) {
      case AuthAuthenticated():
        context.go('/orders');

      case AuthPendingApproval(:final message):
        context.go(
          '/application-status',
          extra: {'status': 'pending', 'message': message},
        );

      case AuthRejected(:final message):
        context.go(
          '/application-status',
          extra: {'status': 'rejected', 'message': message},
        );

      default:
        final hasSeenOnboarding = await ref
            .read(tokenStorageProvider)
            .hasSeenOnboarding;

        if (!mounted) return;

        context.go(hasSeenOnboarding ? '/login' : '/onboarding');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EE),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // =========================================================
          // SPLASH IMAGE
          // =========================================================
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _imageOpacity.value,
                child: Transform.scale(
                  scale: _imageScale.value,
                  child: Image.asset(
                    'assets/image/splash_screen.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            },
          ),

          // =========================================================
          // BOTTOM LOADING DOTS
          // =========================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 55,
            child: AnimatedBuilder(
              animation: _loaderOpacity,
              builder: (context, child) {
                return Opacity(
                  opacity: _loaderOpacity.value,
                  child: const VideoStyleDotLoader(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// LOADING DOTS
// =============================================================

class VideoStyleDotLoader extends StatefulWidget {
  const VideoStyleDotLoader({super.key});

  @override
  State<VideoStyleDotLoader> createState() => _VideoStyleDotLoaderState();
}

class _VideoStyleDotLoaderState extends State<VideoStyleDotLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final double delay = index * 0.20;

            double progress = _dotController.value - delay;

            if (progress < 0) {
              progress += 1.0;
            }

            final double animationValue = Curves.easeInOut.transform(
              progress <= 0.5 ? progress * 2 : (1.0 - progress) * 2,
            );

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFF6E3618,
                ).withValues(alpha: 0.25 + (animationValue * 0.75)),
              ),
            );
          }),
        );
      },
    );
  }
}
