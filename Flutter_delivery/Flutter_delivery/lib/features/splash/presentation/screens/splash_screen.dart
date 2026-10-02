import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/services/update_service.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;

  late AnimationController _loaderController;

  @override
  void initState() {
    super.initState();

    UpdateService.checkForUpdate();

    // Hide status bar during splash
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );

    // Loading animation
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Splash visible for 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _tryNavigate();
      }
    });
  }

  void _tryNavigate() {
    if (!mounted || _navigated) return;

    final authState = ref.read(authControllerProvider);

    if (authState is AuthInitial || authState is AuthLoading) {
      return;
    }

    _navigated = true;
    context.go('/onboarding');
  }

  @override
  void dispose() {
    _loaderController.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      _tryNavigate();
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // FULL SCREEN SPLASH IMAGE
          Image.asset('assets/image/splash.png', fit: BoxFit.cover),

          // LOADING DOTS
          Positioned(
            bottom: 45,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _loaderController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final value =
                        (_loaderController.value + index * 0.25) % 1.0;

                    final opacity =
                        0.25 +
                        (0.75 * (1 - (value - 0.5).abs() * 2).clamp(0.0, 1.0));

                    final scale =
                        0.7 +
                        (0.3 * (1 - (value - 0.5).abs() * 2).clamp(0.0, 1.0));

                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withValues(alpha: opacity),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
