import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF5B3B68)),
            accountName: Text(
              restaurant?.restaurantName ?? 'Restaurant Name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(restaurant?.primaryContactNumber ?? restaurant?.ownerPhone ?? ''),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                image: restaurant?.profileImage.isNotEmpty == true
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(restaurant!.profileImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: restaurant?.profileImage.isEmpty == true
                  ? const Icon(Icons.storefront, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.receipt_long,
                  title: 'Orders',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/orders');
                  },
                ),
                _DrawerItem(
                  icon: Icons.inventory_2,
                  title: 'Inventory',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/inventory');
                  },
                ),
                _DrawerItem(
                  icon: Icons.account_balance_wallet,
                  title: 'Payouts',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/payouts');
                  },
                ),
                _DrawerItem(
                  icon: Icons.table_restaurant,
                  title: 'Dining Management',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/dining');
                  },
                ),
                _DrawerItem(
                  icon: Icons.explore,
                  title: 'Explore',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/explore');
                  },
                ),
                const Divider(height: 32),
                _DrawerItem(
                  icon: Icons.person,
                  title: 'Profile Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/restaurant-status');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
            child: _DrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).iconTheme.color),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
