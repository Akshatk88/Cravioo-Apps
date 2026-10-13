import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/outlets/data/outlet_repository.dart';
import 'package:food_user_application/features/outlets/presentation/controllers/outlets_controller.dart';
import 'package:food_user_application/features/outlets/presentation/widgets/add_outlets_dialog.dart';
import 'package:food_user_application/features/registration/presentation/controllers/registration_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

/// Every outlet under this owner account: status, switch, and finishing the
/// onboarding of outlets that were added but not yet submitted for review.
class OutletsScreen extends ConsumerStatefulWidget {
  const OutletsScreen({super.key});

  @override
  ConsumerState<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends ConsumerState<OutletsScreen> {
  bool _busy = false;

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }

  String _errorText(Object e, String fallback) =>
      e is ApiException ? e.message : fallback;

  Future<void> _switchTo(OutletModel outlet) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).switchOutlet(outlet.id);
      if (!mounted) return;
      _toast('Switched to ${outlet.restaurantName}');
      context.go('/orders');
    } catch (e) {
      _toast(_errorText(e, 'Could not switch outlet'), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeOnboarding(OutletModel outlet) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = await ref
          .read(outletRepositoryProvider)
          .onboardingToken(outlet.id);
      // Owner phone and zone come from the outlet this session is acting as; the
      // server fills the rest of the owner-level details in itself.
      final profile = await ref.read(restaurantProfileControllerProvider.future);

      // Drop any half-filled form from an earlier visit before configuring.
      ref.invalidate(registrationControllerProvider);
      ref
          .read(registrationControllerProvider.notifier)
          .configureAdditionalOutlet(
            outletName: outlet.restaurantName,
            ownerPhone: profile.ownerPhone,
            zoneId: profile.zoneId,
            token: token,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      context.go(
        '/outlets/onboard',
        extra: {'phone': profile.ownerPhone, 'token': token},
      );
    } catch (e) {
      _toast(_errorText(e, 'Could not open onboarding'), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOutlets() async {
    final created = await showAddOutletsDialog(context);
    if (created) await ref.read(outletsControllerProvider.notifier).refresh();
  }

  Future<void> _setScope(String scope) async {
    await ref.read(ordersScopeProvider.notifier).set(scope);
    ref.invalidate(liveOrdersControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final outletsAsync = ref.watch(outletsControllerProvider);
    final scope = ref.watch(ordersScopeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My outlets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/orders'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addOutlets,
        icon: const Icon(Icons.add),
        label: const Text('Add outlets'),
      ),
      body: outletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errorText(error, 'Failed to load outlets.')),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () =>
                      ref.read(outletsControllerProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.read(outletsControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const Text(
                'Each outlet is reviewed separately by admin.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              if (list.hasMultiple) ...[
                const SizedBox(height: 14),
                const Text(
                  'Orders to show',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: kOrdersScopeOutlet,
                      label: Text('This outlet'),
                    ),
                    ButtonSegment(
                      value: kOrdersScopeAll,
                      label: Text('All outlets'),
                    ),
                  ],
                  selected: {scope},
                  onSelectionChanged: (s) => _setScope(s.first),
                ),
              ],
              const SizedBox(height: 14),
              for (final outlet in list.outlets)
                _OutletTile(
                  outlet: outlet,
                  isActive: outlet.id == list.activeOutletId,
                  busy: _busy,
                  onOpen: () => _switchTo(outlet),
                  onCompleteOnboarding: () => _completeOnboarding(outlet),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutletTile extends StatelessWidget {
  const _OutletTile({
    required this.outlet,
    required this.isActive,
    required this.busy,
    required this.onOpen,
    required this.onCompleteOnboarding,
  });

  final OutletModel outlet;
  final bool isActive;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onCompleteOnboarding;

  ({Color bg, Color fg}) get _badge {
    switch (outlet.status) {
      case 'approved':
        return (bg: Colors.green.shade50, fg: Colors.green.shade700);
      case 'pending':
        return (bg: Colors.amber.shade50, fg: Colors.amber.shade800);
      case 'rejected':
        return (bg: Colors.red.shade50, fg: Colors.red.shade700);
      default:
        return (bg: Colors.grey.shade200, fg: Colors.grey.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    Widget? action;
    if (outlet.isOnboarding) {
      action = ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: busy ? null : onCompleteOnboarding,
        child: const Text('Complete onboarding'),
      );
    } else if (isActive) {
      action = const Chip(label: Text('Current'));
    } else if (outlet.isApproved) {
      action = OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: busy ? null : onOpen,
        child: const Text('Open'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outlet.restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (outlet.locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      outlet.locationLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badge.bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      outlet.statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badge.fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 10), action],
          ],
        ),
      ),
    );
  }
}
