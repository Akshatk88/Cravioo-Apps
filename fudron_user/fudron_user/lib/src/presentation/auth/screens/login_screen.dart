import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? fromPath;
  final int initialTabIndex;

  const LoginScreen({super.key, this.fromPath, this.initialTabIndex = 0});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _phoneController = TextEditingController();

  final FocusNode _phoneFocus = FocusNode();

  bool _isLoading = false;

  late AnimationController _buttonController;

  late Animation<double> _buttonAnimation;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _buttonController.dispose();

    super.dispose();
  }

  // ============================================================
  // REDIRECT
  // ============================================================

  String _getRedirectTarget() {
    final queryFrom = GoRouterState.of(context).uri.queryParameters['from'];

    return widget.fromPath ?? queryFrom ?? RouteNames.home;
  }

  // ============================================================
  // OTP LOGIN
  // ============================================================

  Future<void> _handleOtpLogin() async {
    if (_isLoading) {
      return;
    }

    Haptics.light();

    _buttonController.forward().then((_) {
      if (mounted) {
        _buttonController.reverse();
      }
    });

    final phone = Validators.digitsOf(_phoneController.text);

    final phoneError = Validators.phone(phone);

    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    if (phone.length != 10) {
      _showError('Please enter a valid 10-digit mobile number.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    if (kDebugMode) {
      debugPrint('[AUTH] Requesting OTP for +91 $phone');
    }

    try {
      final result = await ref
          .read(authViewModelProvider.notifier)
          .requestOtp(phone);

      if (!mounted) return;

      if (!result.ok) {
        _showError(
          ref.read(authViewModelProvider.notifier).lastError ??
              'Could not send OTP. Please try again.',
        );

        Haptics.error();

        return;
      }

      Haptics.medium();

      if (kDebugMode) {
        debugPrint('[AUTH] OTP request successful');
        debugPrint('[AUTH] Opening OTP screen');
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phoneNumber: phone,
            name: null,
            devOtp: result.devOtp ?? '1234',
            fromPath: _getRedirectTarget(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[AUTH] OTP request exception: $e');
        debugPrint('$stackTrace');
      }

      if (!mounted) return;

      final raw = e.toString();
      final msg = raw.contains('Exception:')
          ? raw.split('Exception:').last.trim()
          : (raw.isNotEmpty ? raw : 'Could not send OTP. Please try again.');

      _showError(msg);

      Haptics.error();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  void _handleLogin() {
    if (_isLoading) return;

    Haptics.light();

    final phone = Validators.digitsOf(_phoneController.text);

    if (phone.length != 10) {
      _showError('Please enter a valid 10-digit mobile number.');

      return;
    }

    _handleOtpLogin();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  void _handleRegister() {
    Haptics.light();

    _phoneFocus.requestFocus();
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    AppSnackbar.error(context, message);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,

      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double designWidth = 852;
            const double designHeight = 1846;

            final double screenWidth = constraints.maxWidth;

            final double actualWidth = screenWidth > 600 ? 600 : screenWidth;

            final double screenHeight = MediaQuery.sizeOf(context).height;

            final double calculatedHeight =
                actualWidth * designHeight / designWidth;

            final double actualHeight = screenHeight > calculatedHeight
                ? screenHeight
                : calculatedHeight;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Center(
                child: SizedBox(
                  width: actualWidth,
                  height: actualHeight,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: designWidth,
                      height: designHeight,
                      child: _buildPage(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  Widget _buildPage() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // ==========================================================
    // CRAVIOO COLORS
    // ==========================================================

    final Color primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final Color secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final Color phoneFieldColor = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;

    final Color phoneNumberColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final Color phoneHintColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final Color dividerColor = isDark
        ? AppColors.darkBorder
        : AppColors.borderLight;

    final Color greenColor = AppColors.primary;

    return SizedBox(
      width: 852,
      height: 1846,

      child: Stack(
        clipBehavior: Clip.none,

        children: [
          // ======================================================
          // BACKGROUND
          // ======================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/login_screen.png',
              fit: BoxFit.fill,
              alignment: Alignment.center,
            ),
          ),

          // ======================================================
          // WELCOME BACK
          // ======================================================
          Positioned(
            top: 735,
            left: 25,
            right: 25,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
                children: [
                  const TextSpan(text: 'Welcome '),
                  TextSpan(
                    text: 'Back!',
                    style: TextStyle(color: greenColor),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // SUBTITLE
          // ======================================================
          Positioned(
            top: 800,
            left: 40,
            right: 40,
            child: Text(
              'Login to continue and order your\n'
              'favourite food ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                height: 1.28,
                color: secondaryTextColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          // ======================================================
          // PHONE FIELD
          // ======================================================
          Positioned(
            top: 895,
            left: 45,
            right: 45,
            child: _buildPhoneField(
              isDark: isDark,
              phoneFieldColor: phoneFieldColor,
              phoneNumberColor: phoneNumberColor,
              phoneHintColor: phoneHintColor,
              dividerColor: dividerColor,
              greenColor: greenColor,
            ),
          ),

          // ======================================================
          // LOGIN BUTTON
          // ======================================================
          Positioned(
            top: 1080,
            left: 125,
            right: 125,
            child: _buildLoginButton(greenColor: greenColor),
          ),

          // ======================================================
          // OR
          // ======================================================
          Positioned(
            top: 1235,
            left: 90,
            right: 90,
            child: Row(
              children: [
                Expanded(child: Divider(color: dividerColor, thickness: 1.5)),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Expanded(child: Divider(color: dividerColor, thickness: 1.5)),
              ],
            ),
          ),

          // ======================================================
          // REGISTER
          // ======================================================
          Positioned(
            top: 1300,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: _handleRegister,
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    const TextSpan(text: 'New here? '),
                    TextSpan(
                      text: 'Register Now',
                      style: TextStyle(
                        color: greenColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PHONE FIELD
  // ============================================================

  Widget _buildPhoneField({
    required bool isDark,
    required Color phoneFieldColor,
    required Color phoneNumberColor,
    required Color phoneHintColor,
    required Color dividerColor,
    required Color greenColor,
  }) {
    return Container(
      height: 145,

      decoration: BoxDecoration(
        color: phoneFieldColor,

        borderRadius: BorderRadius.circular(28),

        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
          width: 1.5,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 17,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Row(
        children: [
          // ====================================================
          // PHONE ICON
          // ====================================================

          Padding(
            padding: const EdgeInsets.only(left: 32, right: 22),
            child: Icon(
              Icons.phone_android_rounded,
              color: greenColor,
              size: 48,
            ),
          ),

          // ====================================================
          // +91
          // ====================================================
          Text(
            '+91',
            style: TextStyle(
              color: phoneNumberColor,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),

          // ====================================================
          // DIVIDER
          // ====================================================
          Container(
            width: 1.5,
            height: 68,
            margin: const EdgeInsets.symmetric(horizontal: 22),
            color: dividerColor,
          ),

          // ====================================================
          // PHONE INPUT
          // ====================================================
          Expanded(
            child: TextField(
              controller: _phoneController,

              focusNode: _phoneFocus,

              keyboardType: TextInputType.phone,

              textInputAction: TextInputAction.done,

              onSubmitted: (_) {
                if (!_isLoading) {
                  _handleLogin();
                }
              },

              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],

              style: TextStyle(
                fontSize: 32,
                color: phoneNumberColor,
                fontWeight: FontWeight.w600,
              ),

              cursorColor: greenColor,

              decoration: InputDecoration(
                hintText: 'Mobile Number',

                hintStyle: TextStyle(
                  color: phoneHintColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                ),

                filled: true,

                fillColor: phoneFieldColor,

                border: InputBorder.none,

                enabledBorder: InputBorder.none,

                focusedBorder: InputBorder.none,

                disabledBorder: InputBorder.none,

                errorBorder: InputBorder.none,

                focusedErrorBorder: InputBorder.none,

                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(width: 28),
        ],
      ),
    );
  }

  // ============================================================
  // LOGIN BUTTON
  // ============================================================

  Widget _buildLoginButton({required Color greenColor}) {
    return ScaleTransition(
      scale: _buttonAnimation,

      child: SizedBox(
        height: 110,
        width: double.infinity,

        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),

            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.secondary,
                AppColors.primary,
                AppColors.primaryButton,
              ],
            ),

            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,

              disabledBackgroundColor: Colors.transparent,

              disabledForegroundColor: Colors.white,

              shadowColor: Colors.transparent,

              elevation: 0,

              padding: EdgeInsets.zero,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(35),
              ),
            ),

            child: Stack(
              alignment: Alignment.center,

              children: [
                // ==================================================
                // LOADING / LOGIN
                // ==================================================

                Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'LOGIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),

                // ==================================================
                // ARROW
                // ==================================================
                if (!_isLoading)
                  const Positioned(
                    right: 25,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
