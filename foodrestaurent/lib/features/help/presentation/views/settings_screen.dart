import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';
import 'package:food_user_application/core/widgets/account_actions.dart';

/// App settings: theme, policy/support links, logout and delete account.
/// Mirrors web SettingsPage.jsx (the web notification/language rows were
/// non-functional placeholders and are intentionally not ported).
/// Route: `/settings`
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final mode = ref.watch(themeModeProvider);

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
          'Settings',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Section(
            title: 'Preferences',
            children: [
              SwitchListTile.adaptive(
                value: mode == ThemeMode.dark,
                activeTrackColor: AppColors.primary,
                secondary: _IconBadge(
                  icon: mode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                title: const Text(
                  'Dark mode',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onChanged: (v) => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Support & information',
            children: [
              _NavTile(
                icon: Icons.help_outline_rounded,
                label: 'Help Centre',
                onTap: () => context.push('/help-centre'),
              ),
              _NavTile(
                icon: Icons.support_agent_rounded,
                label: 'Support',
                onTap: () => context.push('/support-policy'),
              ),
              _NavTile(
                icon: Icons.description_outlined,
                label: 'Terms & Conditions',
                onTap: () => context.push('/terms-and-conditions'),
              ),
              _NavTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => context.push('/privacy-policy'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Actions',
            children: [
              ListTile(
                leading: _IconBadge(
                  icon: Icons.logout_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                onTap: () => confirmAndLogout(context, ref),
              ),
              ListTile(
                leading: _IconBadge(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete your account',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () => confirmAndDeleteAccount(context, ref),
              ),
            ],
          ),
          if (isDark) const SizedBox(height: 4),
        ],
      ),
    );
  }

}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: secondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.color = AppColors.primary});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _IconBadge(icon: icon),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
