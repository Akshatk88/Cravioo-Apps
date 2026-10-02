import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/providers/core_providers.dart';
import 'package:food_user_application/core/widgets/battery_optimization_dialog.dart';
import 'package:food_user_application/core/widgets/exit_app_dialog.dart';

class MainLayoutScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayoutScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowBatteryPrompt());
  }

  // One-time, best-effort — shown once per device regardless of the choice
  // made, so declining doesn't nag the restaurant on every app open.
  Future<void> _maybeShowBatteryPrompt() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    if (await tokenStorage.hasSeenBatteryPrompt) return;
    await tokenStorage.setHasSeenBatteryPrompt();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => const BatteryOptimizationDialog(),
    );
  }

  void _onItemTapped(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (widget.navigationShell.currentIndex != 0) {
          // Not on the first tab, so go back to the Orders tab (index 0)
          widget.navigationShell.goBranch(
            0,
            initialLocation: 0 == widget.navigationShell.currentIndex,
          );
        } else {
          // Already on the first tab, show exit confirmation dialog
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => const ExitAppDialog(),
          );

          if (shouldExit ?? false) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true, // Allows body to go behind the floating navbar
      body: widget.navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Orders',
                index: 0,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2,
                label: 'Inventory',
                index: 1,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                label: 'Payouts',
                index: 2,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Explore',
                index: 3,
              ),
            ],
          ),
        ),
      ),
      )
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = widget.navigationShell.currentIndex == index;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDarkMode
        ? AppColors.backgroundDark
        : Colors.white;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isActive ? 52 : 53,
        height: 53,
        alignment: Alignment.center,
        decoration: isActive
            ? BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)
            : const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : unselectedColor,
              size: isActive ? 24 : 24,
            ),
            if (!isActive) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: unselectedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
