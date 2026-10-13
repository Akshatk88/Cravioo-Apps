import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/services/haptic_service.dart';

Future<String?> showOtpBottomSheet(BuildContext context, {required String customerName}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    // Pinned near the top and blind to the keyboard inset: a centred Dialog
    // re-laid itself out on every frame of the keyboard animation, which
    // (over the live map) is what made the OTP step stutter.
    builder: (ctx) => MediaQuery.removeViewInsets(
      context: ctx,
      removeBottom: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        alignment: Alignment.topCenter,
        insetAnimationDuration: Duration.zero,
        insetPadding: EdgeInsets.fromLTRB(20.w, 110.h, 20.w, 0),
        child: RepaintBoundary(
          child: OtpBottomSheetContent(customerName: customerName),
        ),
      ),
    ),
  );
}

class OtpBottomSheetContent extends StatefulWidget {
  final String customerName;
  const OtpBottomSheetContent({super.key, required this.customerName});

  @override
  State<OtpBottomSheetContent> createState() => _OtpBottomSheetContentState();
}

class _OtpBottomSheetContentState extends State<OtpBottomSheetContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // After the dialog's open animation: a focus request made during it is often
    // dropped on device, leaving the boxes with no keyboard. Retried once in
    // case the first request lands while the route is still settling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _openKeyboard();
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        // No-op when the keyboard is already up.
        if (mounted) _openKeyboard();
      });
    });
    _controller.addListener(_onTextChanged);
  }

  /// Opens the keyboard every time the boxes are tapped. When the keyboard was
  /// dismissed (back button) the hidden field keeps its focus, so requestFocus()
  /// alone is a no-op and the keyboard never came back - ask for it explicitly.
  void _openKeyboard() {
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.length == 4) {
      HapticService.medium();
      Navigator.of(context).pop(text);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: const Color(0xFF1EBE5D), size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Delivery OTP',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: Colors.black87),
                    ),
                    Text(
                      'Ask ${widget.customerName.isNotEmpty ? widget.customerName : "customer"} for 4-digit code',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18.sp, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),

              GestureDetector(
                onTap: _openKeyboard,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    final char = index < text.length ? text[index] : '';
                    final isFocused = index == text.length || (index == 3 && text.length == 4);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 54.w,
                      height: 58.h,
                      decoration: BoxDecoration(
                        color: char.isNotEmpty ? const Color(0xFFF0FDF4) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFF1EBE5D)
                              : (char.isNotEmpty ? const Color(0xFF86EFAC) : Colors.grey[300]!),
                          width: isFocused ? 2.0 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1EBE5D).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}

/// Runs [request] behind a small blocking "Verifying OTP…" dialog, so the screen
/// never looks frozen while the server checks the code and a second tap cannot
/// send it again.
Future<T> runWithOtpProgress<T>(BuildContext context, Future<T> Function() request) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                SizedBox(width: 16),
                Text('Verifying OTP…', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  try {
    return await request();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
