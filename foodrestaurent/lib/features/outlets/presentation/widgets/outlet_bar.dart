import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/outlets/data/outlet_repository.dart';
import 'package:food_user_application/features/outlets/presentation/controllers/outlets_controller.dart';

/// Slim strip above the order tabs: which outlet this session is acting as, a
/// way to switch, and the "This outlet / All outlets" toggle. The web
/// dashboard's outlet switcher, for the app.
///
/// Hidden until the outlet list has loaded, and while an owner has only one
/// outlet it shows just the entry point to add more.
class OutletBar extends ConsumerStatefulWidget {
  const OutletBar({super.key});

  @override
  ConsumerState<OutletBar> createState() => _OutletBarState();
}

class _OutletBarState extends ConsumerState<OutletBar> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The outlet list may already be loaded when this bar first appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final value = ref.read(outletsControllerProvider).value;
      if (value != null) _applyScopeDefault(value);
    });
  }

  void _applyScopeDefault(OutletList list) {
    // Deferred: providers must not be modified while a widget is building.
    Future.microtask(() {
      if (!mounted) return;
      final changed = ref
          .read(ordersScopeProvider.notifier)
          .applyDefault(hasMultipleOutlets: list.hasMultiple);
      if (changed) ref.invalidate(liveOrdersControllerProvider);
    });
  }

  Future<void> _switchTo(String outletId) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).switchOutlet(outletId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not switch outlet',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setScope(String scope) async {
    await ref.read(ordersScopeProvider.notifier).set(scope);
    ref.invalidate(liveOrdersControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    // The default view for several outlets is "All outlets" (see applyDefault),
    // so a sibling outlet's order is visible the moment it arrives.
    ref.listen(outletsControllerProvider, (_, next) {
      final value = next.value;
      if (value != null) _applyScopeDefault(value);
    });
    final list = ref.watch(outletsControllerProvider).value;
    if (list == null) return const SizedBox.shrink();
    final scope = ref.watch(ordersScopeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Only approved outlets can be switched to from here; ones under review or
    // still onboarding are handled on the outlets screen.
    final switchable = list.outlets.where((o) => o.isApproved).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      color: isDark ? Colors.white10 : Colors.white,
      child: Row(
        children: [
          if (list.hasMultiple && switchable.length > 1)
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: switchable.any((o) => o.id == list.activeOutletId)
                      ? list.activeOutletId
                      : null,
                  icon: const Icon(Icons.expand_more),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onChanged: _busy
                      ? null
                      : (id) {
                          if (id != null && id != list.activeOutletId) {
                            _switchTo(id);
                          }
                        },
                  items: [
                    for (final o in switchable)
                      DropdownMenuItem(
                        value: o.id,
                        child: Text(
                          o.restaurantName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          if (list.hasMultiple)
            PopupMenuButton<String>(
              tooltip: 'Orders to show',
              icon: Icon(
                scope == kOrdersScopeAll
                    ? Icons.store_mall_directory
                    : Icons.storefront,
              ),
              onSelected: _setScope,
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: kOrdersScopeOutlet,
                  checked: scope == kOrdersScopeOutlet,
                  child: const Text('This outlet'),
                ),
                CheckedPopupMenuItem(
                  value: kOrdersScopeAll,
                  checked: scope == kOrdersScopeAll,
                  child: const Text('All outlets'),
                ),
              ],
            ),
          TextButton.icon(
            onPressed: () => context.push('/outlets'),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: Text(list.hasMultiple ? 'Outlets' : 'Add outlets'),
          ),
        ],
      ),
    );
  }
}
