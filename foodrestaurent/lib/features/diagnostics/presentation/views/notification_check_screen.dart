import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/order_overlay_service.dart';

enum _Level { ok, warn, bad, unknown }

class _Check {
  const _Check(this.title, this.level, this.detail, {this.action});
  final String title;
  final _Level level;
  final String detail;

  /// Optional fix, shown as a button.
  final _CheckAction? action;
}

class _CheckAction {
  const _CheckAction(this.label, this.run);
  final String label;
  final Future<void> Function() run;
}

/// Answers "why don't I get order notifications?" on the device itself.
///
/// Every step between a customer's order and the restaurant's phone can fail
/// silently - a permission, a missing push token, the server not reaching Firebase.
/// From the outside they all look the same ("nothing arrives"). This screen checks
/// each step and can send a real test push, so the broken one is named instead of
/// guessed at.
class NotificationCheckScreen extends ConsumerStatefulWidget {
  const NotificationCheckScreen({super.key});

  @override
  ConsumerState<NotificationCheckScreen> createState() => _NotificationCheckScreenState();
}

class _NotificationCheckScreenState extends ConsumerState<NotificationCheckScreen> {
  List<_Check> _checks = const [];
  String? _testResult;
  _Level _testLevel = _Level.unknown;
  bool _running = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runChecks());
  }

  Future<void> _runChecks() async {
    if (_running) return;
    setState(() => _running = true);
    final fcm = ref.read(fcmServiceProvider);
    final checks = <_Check>[];

    // 1. Notification permission.
    final notif = await Permission.notification.status;
    checks.add(
      _Check(
        'Notifications allowed',
        notif.isGranted ? _Level.ok : _Level.bad,
        notif.isGranted
            ? 'The app may show notifications.'
            : 'Blocked. Android shows nothing until you allow it.',
        action: notif.isGranted
            ? null
            : _CheckAction('Allow', () async {
                await Permission.notification.request();
                if (!await Permission.notification.isGranted) await openAppSettings();
              }),
      ),
    );

    // 2. Overlay permission.
    final overlay = await OrderOverlayService.hasPermission();
    checks.add(
      _Check(
        'Display over other apps',
        overlay ? _Level.ok : _Level.warn,
        overlay
            ? 'The new-order card can appear over other apps.'
            : 'Off. Orders still ring and notify, but the pop-up card will not appear.',
        action: overlay ? null : _CheckAction('Allow', OrderOverlayService.requestPermission),
      ),
    );

    // 3. Battery optimisation.
    final battery = await Permission.ignoreBatteryOptimizations.status;
    checks.add(
      _Check(
        'Battery restriction removed',
        battery.isGranted ? _Level.ok : _Level.warn,
        battery.isGranted
            ? 'Android will not put the app to sleep.'
            : 'The phone may stop the app in the background and drop order alerts.',
        action: battery.isGranted
            ? null
            : _CheckAction('Fix', () async {
                await Permission.ignoreBatteryOptimizations.request();
              }),
      ),
    );

    // 4. Device push token.
    final token = await fcm.currentToken();
    final hasToken = token != null && token.isNotEmpty;
    checks.add(
      _Check(
        'Push token on this phone',
        hasToken ? _Level.ok : _Level.bad,
        hasToken
            ? 'Token ...${token.substring(token.length - 8)}'
            : (FcmService.lastRegistrationError ?? 'Firebase gave this phone no token.'),
      ),
    );

    // 5. Token registered on the server for this login.
    if (hasToken) {
      final saved = await fcm.saveTokenToServer();
      checks.add(
        _Check(
          'Token saved on the server',
          saved ? _Level.ok : _Level.bad,
          saved
              ? 'The server knows this phone for this restaurant.'
              : (FcmService.lastRegistrationError ?? 'The save request failed.'),
        ),
      );
    } else {
      checks.add(const _Check('Token saved on the server', _Level.unknown, 'Needs a push token first.'));
    }

    if (!mounted) return;
    setState(() {
      _checks = checks;
      _running = false;
    });
  }

  Future<void> _sendTest() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _testResult = null;
      _testLevel = _Level.unknown;
    });
    try {
      final response = await ref.read(dioProvider).post(
        '/fcm-tokens/test',
        data: {'platform': 'mobile'},
      );
      final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};
      final tokenCount = (data['tokenCount'] as num?)?.toInt() ?? 0;
      final success = (data['successCount'] as num?)?.toInt() ?? 0;
      final failure = (data['failureCount'] as num?)?.toInt() ?? 0;
      final reason = data['reason']?.toString();
      final error = data['error']?.toString();

      if (reason == 'NO_TOKENS' || tokenCount == 0) {
        _testLevel = _Level.bad;
        _testResult =
            'The server has NO push token for this restaurant, so nothing can be sent. '
            'Log out and log in again, then run the checks.';
      } else if (success > 0) {
        _testLevel = _Level.ok;
        _testResult =
            'Sent to $success device(s). A "Test Notification" should appear within a few seconds. '
            'If it does not, the problem is on this phone (permission, battery, Do Not Disturb), not the server.';
      } else {
        _testLevel = _Level.bad;
        _testResult =
            'The server tried $tokenCount token(s) and all $failure failed'
            '${error == null ? '' : ': $error'}. The saved token is probably stale - log out and in again.';
      }
    } catch (e) {
      _testLevel = _Level.bad;
      _testResult = e is ApiException ? e.message : 'Could not reach the server: $e';
    }
    if (mounted) setState(() => _sending = false);
  }

  Color _color(_Level l) {
    switch (l) {
      case _Level.ok:
        return const Color(0xFF16A34A);
      case _Level.warn:
        return const Color(0xFFD97706);
      case _Level.bad:
        return AppColors.error;
      case _Level.unknown:
        return Colors.grey;
    }
  }

  IconData _icon(_Level l) {
    switch (l) {
      case _Level.ok:
        return Icons.check_circle_rounded;
      case _Level.warn:
        return Icons.warning_amber_rounded;
      case _Level.bad:
        return Icons.cancel_rounded;
      case _Level.unknown:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/orders'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Checks every step between a new order and this phone, and names the one that is broken.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          if (_running && _checks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          for (final c in _checks)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(c.level), color: _color(c.level)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(c.detail, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                        ],
                      ),
                    ),
                    if (c.action != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                        onPressed: () async {
                          await c.action!.run();
                          await _runChecks();
                        },
                        child: Text(c.action!.label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _running ? null : _runChecks,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Run checks again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _sending ? null : _sendTest,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_rounded),
                  label: const Text('Send test push'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _color(_testLevel).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _color(_testLevel).withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(_testLevel), color: _color(_testLevel)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_testResult!, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
