import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';

class FireParticleShareButton extends StatefulWidget {
  final VoidCallback onPressed;

  const FireParticleShareButton({super.key, required this.onPressed});

  @override
  State<FireParticleShareButton> createState() => _FireParticleShareButtonState();
}

class _FireParticleShareButtonState extends State<FireParticleShareButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          Haptics.medium();
          widget.onPressed();
        },
        child: Container(
          width: 220.w,
          height: 52.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAlpha(0.4),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 10.w),
              Text(
                'SHARE YOUR TICKET',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
