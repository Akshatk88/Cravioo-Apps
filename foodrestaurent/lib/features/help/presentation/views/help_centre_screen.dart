import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

class _HelpTopic {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.isTab = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  /// Bottom-nav shell tabs must be reached with `go`, others with `push`.
  final bool isTab;
}

/// Searchable list of help topics that deep-link into the relevant screens.
/// Mirrors web HelpCentre.jsx. Route: `/help-centre`
class HelpCentreScreen extends StatefulWidget {
  const HelpCentreScreen({super.key});

  @override
  State<HelpCentreScreen> createState() => _HelpCentreScreenState();
}

class _HelpCentreScreenState extends State<HelpCentreScreen> {
  static const List<_HelpTopic> _topics = [
    _HelpTopic(
      icon: Icons.power_settings_new_rounded,
      title: 'Outlet online / offline status',
      subtitle: 'Current status & details',
      route: '/restaurant-status',
    ),
    _HelpTopic(
      icon: Icons.restaurant_rounded,
      title: 'Order related issues',
      subtitle: 'Cancellations & delivery related concerns',
      route: '/order-history',
    ),
    _HelpTopic(
      icon: Icons.storefront_outlined,
      title: 'Restaurant',
      subtitle: 'Timings, contacts, FSSAI, bank details, location etc.',
      route: '/outlet-info',
    ),
    _HelpTopic(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payments',
      subtitle: 'Statement of account, invoices etc.',
      route: '/payouts',
      isTab: true,
    ),
    _HelpTopic(
      icon: Icons.support_agent_rounded,
      title: 'Support',
      subtitle: 'Raise ticket and get admin response',
      route: '/support',
    ),
    _HelpTopic(
      icon: Icons.verified_outlined,
      title: 'FSSAI license',
      subtitle: 'View or update your food license',
      route: '/fssai',
    ),
    _HelpTopic(
      icon: Icons.help_outline_rounded,
      title: 'Support policy and FAQs',
      subtitle: 'Contact details and frequently asked questions',
      route: '/support-policy',
    ),
    _HelpTopic(
      icon: Icons.description_outlined,
      title: 'Terms & Conditions',
      subtitle: 'Partner terms of service',
      route: '/terms-and-conditions',
    ),
    _HelpTopic(
      icon: Icons.privacy_tip_outlined,
      title: 'Privacy Policy',
      subtitle: 'How your data is handled',
      route: '/privacy-policy',
    ),
  ];

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final q = _search.text.trim().toLowerCase();
    final filtered = _topics
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.subtitle.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: onSurface,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          'Help Centre',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'How can we help you',
            style: TextStyle(
              color: onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by issue',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final topic in filtered)
            InkWell(
              onTap: () =>
                  topic.isTab ? context.go(topic.route) : context.push(topic.route),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(topic.icon, color: onSurface, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            style: TextStyle(
                              color: onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            topic.subtitle,
                            style: TextStyle(color: secondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: secondary),
                  ],
                ),
              ),
            ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'No help topics found matching "${_search.text}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
