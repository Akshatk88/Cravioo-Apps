import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showOtp = false;
  bool _isSubmitting = false;
  String? _errorText;

  final FocusNode _mobileFocusNode = FocusNode();
  final TextEditingController _mobileController = TextEditingController();

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  Timer? _resendTimer;
  int _resendSeconds = 45;

  static const _otpLength = 4;

  @override
  void initState() {
    super.initState();
    _mobileFocusNode.addListener(() => setState(() {}));
    _otpFocusNode.addListener(() => setState(() {}));
  }

  void _startTimer() {
    _resendSeconds = 45;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _mobileFocusNode.dispose();
    _mobileController.dispose();
    _otpFocusNode.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _phone => _mobileController.text.trim();

  bool get _isPhoneValid => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone);

  Future<void> _onLoginPressed() async {
    if (!_isPhoneValid) {
      setState(() => _errorText = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(_phone);
      if (!mounted) return;
      setState(() {
        _showOtp = true;
        _otpController.text = '1234';
      });
      _startTimer();
      _otpFocusNode.requestFocus();
    } catch (e) {
      setState(() => _errorText = _messageFor(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onResendPressed() async {
    if (_resendSeconds > 0 || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(_phone);
      _startTimer();
    } catch (e) {
      setState(() => _errorText = _messageFor(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _onBackPressed() {
    setState(() {
      _showOtp = false;
      _errorText = null;
      _otpController.clear();
    });
  }

  Future<void> _onVerifyPressed() async {
    if (_otpController.text.length != _otpLength) {
      setState(() => _errorText = 'Enter the $_otpLength-digit code');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: _phone, otp: _otpController.text);
      if (!mounted) return;
      _routeAfterAuth();
    } catch (e) {
      setState(() => _errorText = _messageFor(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _routeAfterAuth() {
    final state = ref.read(authControllerProvider);
    switch (state) {
      case AuthAuthenticated():
        context.go('/orders');
      case AuthNeedsRegistration(:final phone, :final registrationToken):
        context.go('/register', extra: {'phone': phone, 'token': registrationToken});
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
        break;
    }
  }

  String _messageFor(Object e) {
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F2),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurvedImage('assets/image/onboard3.jpeg'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showOtp ? _buildOtpForm() : _buildLoginForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurvedImage(String assetPath) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Stack(
        children: [
          ClipPath(
            clipper: _OrangeClipperAuth(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              width: double.infinity,
              color: AppColors.primary,
            ),
          ),
          ClipPath(
            clipper: _ImageClipperAuth(),
            child: Image.asset(
              assetPath,
              height: MediaQuery.of(context).size.height * 0.38,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          if (_showOtp)
            Positioned(
              top: 50,
              left: 20,
              child: GestureDetector(
                onTap: _onBackPressed,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Partner Login',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Login with your registered mobile number to manage your restaurant',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 32),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _errorText != null
                  ? AppColors.error
                  : (_mobileFocusNode.hasFocus
                        ? AppColors.primary
                        : Colors.black12),
              width: _mobileFocusNode.hasFocus ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.phone, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              const Text(
                '+91',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: Colors.black12),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  focusNode: _mobileFocusNode,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(color: Colors.black, fontSize: 15),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                  onSubmitted: (_) => _onLoginPressed(),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.only(left: 12),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    hintText: 'Enter your mobile number',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.black38),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Send OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF4F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "New restaurant partner? Just verify your number — we'll take you "
                  "straight into the sign-up form if you don't have an account yet.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOtpForm() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
            children: [
              const TextSpan(text: 'Verify Your '),
              TextSpan(
                text: 'Number',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the code sent to',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '+91 $_phone',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _onBackPressed,
              child: Icon(
                Icons.edit_square,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Stack(
          children: [
            Opacity(
              opacity: 0.0,
              child: TextField(
                controller: _otpController,
                focusNode: _otpFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                maxLength: _otpLength,
                onChanged: (_) {
                  setState(() => _errorText = null);
                  if (_otpController.text.length == _otpLength) {
                    _onVerifyPressed();
                  }
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_otpLength, (index) {
                String digit = '';
                if (index < _otpController.text.length) {
                  digit = _otpController.text[index];
                }
                bool isFocused =
                    _otpController.text.length == index ||
                    (_otpController.text.length == _otpLength &&
                        index == _otpLength - 1);
                bool hasFocusNode = _otpFocusNode.hasFocus;

                return GestureDetector(
                  onTap: () => _otpFocusNode.requestFocus(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _errorText != null
                            ? AppColors.error
                            : ((isFocused && hasFocusNode)
                                  ? AppColors.primary
                                  : Colors.black12),
                        width: (isFocused && hasFocusNode) ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: digit.isNotEmpty
                          ? Text(
                              digit,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : ((isFocused && hasFocusNode)
                                ? Text(
                                    '|',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  )
                                : const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.black26,
                                  )),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Center(
          child: _resendSeconds > 0
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                    children: [
                      const TextSpan(text: "Didn't receive the code? "),
                      TextSpan(
                        text:
                            'Resend in 00:${_resendSeconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: _onResendPressed,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                      children: [
                        const TextSpan(text: "Didn't receive the code? "),
                        TextSpan(
                          text: 'Resend OTP',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF4F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure & Safe',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "We'll never share your number\nwith anyone.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _onVerifyPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Verify & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ImageClipperAuth extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 90);

    var firstControlPoint = Offset(size.width * 0.3, size.height - 20);
    var firstEndPoint = Offset(size.width * 0.6, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.85, size.height - 40);
    var secondEndPoint = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _OrangeClipperAuth extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 90);

    var firstControlPoint = Offset(size.width * 0.3, size.height - 30);
    var firstEndPoint = Offset(size.width * 0.6, size.height - 50);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    var secondControlPoint = Offset(size.width * 0.85, size.height - 70);
    var secondEndPoint = Offset(size.width, size.height - 50);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
