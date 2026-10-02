import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/core/providers/core_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isButtonAnimating = false;

  void _handleStartTap() async {
    if (_isButtonAnimating) return;
    setState(() {
      _isButtonAnimating = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    _nextPage();

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() {
        _isButtonAnimating = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        physics: const ClampingScrollPhysics(),
        children: [_buildPage1(), _buildPage2(), _buildPage3()],
      ),
    );
  }

  Widget _buildFadedImage(String assetPath) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1() {
    return Stack(
      children: [
        Column(
          children: [
            _buildFadedImage('assets/image/onboard1.webp'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.2,
                            ),
                        children: [
                          const TextSpan(
                            text: 'Exceptional Food,\n',
                            style: TextStyle(fontSize: 28),
                          ),
                          TextSpan(
                            text: 'Delivered Fresh',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Experience gourmet-quality meals prepared\nwith care and delivered faster than ever —\nstraight to your doorstep.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    _buildStartButtonUI(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPage2() {
    return Stack(
      children: [
        Column(
          children: [
            _buildFadedImage('assets/image/onboard2.webp'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),

                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.2,
                            ),

                        children: [
                          const TextSpan(
                            text: 'Craft Your Own\n',
                            style: TextStyle(fontSize: 28),
                          ),
                          TextSpan(
                            text: 'Culinary ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 25,
                            ),
                          ),
                          const TextSpan(
                            text: 'Experience',
                            style: TextStyle(fontSize: 25),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose fresh ingredients curated just for you\nand enjoy a meal made your way.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    _buildPageIndicator(1),
                    const SizedBox(height: 32),
                    _buildWideButton('Continue', _nextPage),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPage3() {
    return Stack(
      children: [
        Column(
          children: [
            _buildFadedImage('assets/image/onboard3.jpeg'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.2,
                            ),
                        children: [
                          const TextSpan(text: 'Welcome to \n'),
                          TextSpan(
                            text: 'Cravioo Restaurant',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Order your favorite meals easily and enjoy fast,\nfresh delivery — simple and convenient. ',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    _buildAppleButton(),
                    // const SizedBox(height: 12),
                    // Row(
                    //   children: [
                    //     Expanded(child: _buildGoogleButton()),
                    //     const SizedBox(width: 12),
                    //     Expanded(child: _buildEmailButton()),
                    //   ],
                    // ),
                    const SizedBox(height: 16),
                    _buildTermsText(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageIndicator(int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          width: currentIndex == index ? 24.0 : 8.0,
          decoration: BoxDecoration(
            color: currentIndex == index
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4.0),
          ),
        );
      }),
    );
  }

  Widget _buildStartButtonUI() {
    return GestureDetector(
      onTap: _handleStartTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(32),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 56),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Start',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: 8,
                  right: _isButtonAnimating ? 8 : constraints.maxWidth - 56,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Icon(
                          Icons.room_service,
                          color: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWideButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () async {
          await ref.read(tokenStorageProvider).setHasSeenOnboarding();
          if (context.mounted) context.go('/login');
        },
        label: Text(
          'Get Started',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            height: 1.5,
          ),
          children: [
            const TextSpan(
              text: 'By signing in to this app you agree with our ',
            ),
            TextSpan(
              text: 'Terms\nof Use',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
