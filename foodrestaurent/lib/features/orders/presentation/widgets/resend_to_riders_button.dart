import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';

/// Sends the delivery request out again when no rider has taken it.
///
/// A rider can miss the first request (app closed, phone silent, offer expired).
/// The server clears the previous offer list and dispatches afresh, so every
/// nearby partner gets another chance. It is only offered while the food is
/// ready for pickup and nobody has accepted: the server refuses it in every
/// other state, and once a rider has accepted, resending would disturb them.
class ResendToRidersButton extends ConsumerStatefulWidget {
  const ResendToRidersButton({super.key, required this.order, this.compact = false});

  final OrderModel order;

  /// Smaller, for use inside a list card rather than as a primary action.
  final bool compact;

  /// Whether the button should be shown for [order] at all.
  static bool isAvailableFor(OrderModel order) =>
      order.orderStatus == 'ready_for_pickup' &&
      order.dispatchStatus != 'accepted' &&
      !order.hasRider;

  @override
  ConsumerState<ResendToRidersButton> createState() => _ResendToRidersButtonState();
}

class _ResendToRidersButtonState extends ConsumerState<ResendToRidersButton> {
  /// Last send time per order, kept across rebuilds. Repeated taps would
  /// re-notify every rider each time, so there is a short pause between sends.
  static final Map<String, DateTime> _lastSent = {};
  static const _cooldown = Duration(seconds: 30);

  bool _sending = false;
  Timer? _tick;

  int get _secondsLeft {
    final last = _lastSent[widget.order.id];
    if (last == null) return 0;
    final left = _cooldown.inSeconds - DateTime.now().difference(last).inSeconds;
    return left > 0 ? left : 0;
  }

  @override
  void initState() {
    super.initState();
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    _tick?.cancel();
    if (_secondsLeft <= 0) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {});
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_sending || _secondsLeft > 0) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(liveOrdersControllerProvider.notifier)
          .resendNotification(widget.order.id);
      _lastSent[widget.order.id] = DateTime.now();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Request sent again to nearby delivery partners.'),
        ),
      );
      _startTickerIfNeeded();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not resend. Please try again.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _secondsLeft;
    final label = _sending
        ? 'Sending…'
        : waiting > 0
        ? 'Resend available in ${waiting}s'
        : 'Resend to drivers';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_sending || waiting > 0) ? null : _resend,
        icon: _sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          // The app theme gives buttons an infinite minimum width; pin it so the
          // button lays out inside a Row/Column without a layout error.
          minimumSize: Size(0, widget.compact ? 42 : 50),
          foregroundColor: AppColors.primaryDark,
          side: BorderSide(color: AppColors.primaryAlpha(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.compact ? 12 : 30),
          ),
        ),
      ),
    );
  }
}
