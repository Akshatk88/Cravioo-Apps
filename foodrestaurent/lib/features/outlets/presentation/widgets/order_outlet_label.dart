import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/outlets/presentation/controllers/outlets_controller.dart';

/// Names the outlet an order belongs to — only in the "All outlets" view, where
/// the list mixes several outlets and the name is what tells them apart.
class OrderOutletLabel extends ConsumerWidget {
  const OrderOutletLabel({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(ordersScopeProvider) != kOrdersScopeAll) {
      return const SizedBox.shrink();
    }
    final list = ref.watch(outletsControllerProvider).value;
    final name = list?.nameOf(restaurantId) ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF32C45A),
        ),
      ),
    );
  }
}

