import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';

class FloatingActiveOrderCard extends StatefulWidget {
  final OrderModel order;
  final bool isCompact;

  const FloatingActiveOrderCard({
    super.key,
    required this.order,
    this.isCompact = false,
  });

  @override
  State<FloatingActiveOrderCard> createState() => _FloatingActiveOrderCardState();
}

class _FloatingActiveOrderCardState extends State<FloatingActiveOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[HOME] Widget inserted into UI');
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondaryColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;

    final order = widget.order;
    final etaText = order.etaLabel;

    // Responsive design dimensions
    final double cardWidth = widget.isCompact ? 280.0 : MediaQuery.of(context).size.width - 32;
    final double iconContainerSize = widget.isCompact ? 32.0 : 42.0;
    final double iconSize = widget.isCompact ? 16.0 : 22.0;
    final double titleFontSize = widget.isCompact ? 12.5 : 14.0;
    final double statusFontSize = widget.isCompact ? 11.5 : 12.5;
    final double chipPaddingHorizontal = widget.isCompact ? 8.0 : 12.0;
    final double chipPaddingVertical = widget.isCompact ? 5.0 : 8.0;
    final double chipFontSize = widget.isCompact ? 10.0 : 11.5;
    final double spacingWidth = widget.isCompact ? 8.0 : 12.0;
    final double itemSpacingHeight = widget.isCompact ? 0.0 : 2.0;
    final double innerPaddingHorizontal = widget.isCompact ? 10.0 : 14.0;
    final double innerPaddingVertical = widget.isCompact ? 8.0 : 12.0;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Haptics.medium();
                if (kDebugMode) {
                  debugPrint('[HOME] Widget clicked');
                  debugPrint('[TRACKING] Tracking page opened');
                }
                context.push('/orders/track/${order.id}');
              },
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: cardWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: innerPaddingHorizontal,
                  vertical: innerPaddingVertical,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        color: AppColors.primaryAlpha(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        order.isOutForDelivery
                            ? Icons.two_wheeler_rounded
                            : Icons.soup_kitchen_rounded,
                        color: AppColors.primary,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: spacingWidth),

                    // Restaurant & Status Column
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: Text(
                              order.restaurantName.isNotEmpty
                                  ? order.restaurantName
                                  : 'Food Order',
                            ),
                          ),
                          SizedBox(height: itemSpacingHeight),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  style: TextStyle(
                                    fontSize: statusFontSize,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  child: Text(order.statusLabel),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Green ETA Pill
                    if (etaText != null && etaText.isNotEmpty)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                              horizontal: chipPaddingHorizontal,
                              vertical: chipPaddingVertical,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B562),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00B562).withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              order.compactEtaLabel ?? etaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: chipFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
