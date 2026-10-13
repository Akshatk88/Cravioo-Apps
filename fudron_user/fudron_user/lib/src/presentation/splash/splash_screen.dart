import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/src/core/services/update_service.dart';
import 'package:food_user_application/src/presentation/auth/viewmodels/auth_viewmodel.dart';
import 'package:food_user_application/src/presentation/navigation/route_names.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    UpdateService.checkForUpdate();
    _setupSuperSmoothAnimations();
  }

  void _setupSuperSmoothAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), _goNext);
    });
  }

  /// Login first: a signed-in user goes to Home, anyone else to the login
  /// screen (it used to send everyone straight to Home).
  Future<void> _goNext() async {
    if (!mounted) return;
    var auth = ref.read(authViewModelProvider);
    // Session restore may still be running; give it a moment, not forever.
    for (var i = 0; i < 25 && auth.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      auth = ref.read(authViewModelProvider);
    }
    if (!mounted) return;
    final signedIn = auth.value != null;
    context.go(signedIn ? RouteNames.home : RouteNames.login);
  }

  @override
  void dispose() {
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: Stack(
              children: [
                // 1. Full Screen Background Splash Image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/splash.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // 2. Bottom Loading Bar & Text Overlay (Shifted down and size reduced)
                Positioned(
                  bottom: 12, // Aur zyada neeche shift kiya hai
                  left: 40,
                  right: 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1FA84F).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FA84F),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
