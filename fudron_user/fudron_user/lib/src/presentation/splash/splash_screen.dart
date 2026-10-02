import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/src/core/services/update_service.dart';
import 'package:food_user_application/src/presentation/navigation/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
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
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go(RouteNames.home);
        }
      });
    });
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
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Cravioo - Food Delivered Fast",
                        style: TextStyle(
                          color: Color(0xFFFFB300), // Mangoish Yellow color
                          fontSize: 10, // Text ko thoda chota kiya hai
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
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
