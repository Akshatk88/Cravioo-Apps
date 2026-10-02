import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
            width: 1.0,
          ),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0.w, vertical: 6.0.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home (Branch 0)
              _buildNavItem(
                context: context,
                icon: Icons.home_rounded,
                label: l10n.home,
                index: 0,
                isDark: isDark,
              ),

              // 2. 149 Meals (Branch 2)
              _buildNavItem(
                context: context,
                icon: Icons.lunch_dining_rounded,
                label: '149 Meals',
                index: 2,
                isDark: isDark,
              ),

              // 3. Members (Branch 3)
              _buildNavItem(
                context: context,
                icon: Icons.military_tech_rounded,
                label: 'Members',
                index: 3,
                isDark: isDark,
              ),

              // 4. Dining (Branch 4)
              _buildNavItem(
                context: context,
                icon: Icons.restaurant_rounded,
                label: 'Dining',
                index: 4,
                isDark: isDark,
              ),

              // 5. Profile (Branch 5)
              _buildNavItem(
                context: context,
                icon: Icons.person_outline_rounded,
                label: l10n.profile,
                index: 5,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.primary;
    final unselectedColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF757575);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.0.w, vertical: 4.0.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : unselectedColor,
              size: 24.sp,
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : unselectedColor,
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
