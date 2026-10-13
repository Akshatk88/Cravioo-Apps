import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/help/domain/page_content_model.dart';
import 'package:food_user_application/features/help/presentation/controllers/page_content_controller.dart';
import 'package:food_user_application/features/help/presentation/widgets/simple_html_view.dart';

/// Shared CMS page view used by Privacy Policy, Terms & Conditions and
/// Support Policy. Content comes from the public `GET /food/pages/:key`.
class LegalPageScreen extends ConsumerWidget {
  const LegalPageScreen({
    super.key,
    required this.pageKey,
    required this.appBarTitle,
  });

  final PageContentKey pageKey;
  final String appBarTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pageContentProvider(pageKey));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

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
          appBarTitle,
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException ? e.message : 'Failed to load this page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(pageContentProvider(pageKey)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (page) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pageContentProvider(pageKey));
            await ref.read(pageContentProvider(pageKey).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: _PageBody(page: page, pageKey: pageKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page, required this.pageKey});

  final PageContentModel page;
  final PageContentKey pageKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final date = DateFormat('MMMM d, yyyy').format(page.updatedAt?.toLocal() ?? DateTime.now());
    final isSupport = pageKey == PageContentKey.support;
    final emptyLabel = switch (pageKey) {
      PageContentKey.privacy => 'No privacy policy content available.',
      PageContentKey.terms => 'No terms content available.',
      PageContentKey.support => 'No support content available.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          page.title,
          style: TextStyle(
            color: onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Last updated: $date',
          style: TextStyle(color: secondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (isSupport && (page.contactNumber.isNotEmpty || page.email.isNotEmpty)) ...[
          if (page.contactNumber.isNotEmpty)
            _ContactTile(
              icon: Icons.phone_outlined,
              value: page.contactNumber,
              label: 'Phone',
            ),
          if (page.email.isNotEmpty)
            _ContactTile(
              icon: Icons.mail_outline_rounded,
              value: page.email,
              label: 'Email',
            ),
          const SizedBox(height: 8),
        ],
        if (page.content.trim().isNotEmpty) SimpleHtmlView(html: page.content),
        if (isSupport && page.faqs.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Frequently Asked Questions',
            style: TextStyle(
              color: onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final faq in page.faqs) _FaqTile(faq: faq),
        ],
        if (page.isEmpty)
          Text(emptyLabel, style: TextStyle(color: secondary, fontSize: 14)),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // No url_launcher dependency in the project, so tapping copies the value.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied to clipboard')),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final PageFaq faq;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(
            faq.question,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [SimpleHtmlView(html: faq.answer, fontSize: 13)],
        ),
      ),
    );
  }
}
