import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/alert_permission_flow.dart';

/// Persistent notice of every permission the offer alert is still missing.
///
/// Deliberately not dismissible. Each missing item means the rider is quietly being
/// offered fewer orders, or none — a state that produces no error, no empty screen
/// and nothing else to explain itself. A banner they can dismiss is a banner they
/// dismiss once and never think about again, while the app stays broken.
class AlertPermissionBanner extends ConsumerWidget {
  const AlertPermissionBanner({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(alertPermissionControllerProvider).value;
    if (missing == null || missing.isEmpty) return const SizedBox.shrink();

    final critical = missing.where((p) => p.isCritical).toList();
    final isSevere = critical.isNotEmpty;
    final accent = isSevere ? const Color(0xFFE23744) : const Color(0xFFF3A712);

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSevere ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSevere
                        ? 'You may miss new orders'
                        : 'Order alerts are not fully set up',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Listed individually rather than summarised as a count: the rider has to
            // grant each one on a different Settings screen, so "3 permissions
            // missing" tells them nothing they can act on.
            for (final permission in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.radio_button_unchecked,
                        size: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permission.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            permission.description,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.3,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => ref
                          .read(alertPermissionControllerProvider.notifier)
                          .fix(permission),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        foregroundColor: accent,
                      ),
                      child: const Text('Fix'),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => ref
                    .read(alertPermissionControllerProvider.notifier)
                    .runSequentially(),
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('Fix all, one at a time'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
