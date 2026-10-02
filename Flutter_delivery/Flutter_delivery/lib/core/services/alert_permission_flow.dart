import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// The permissions the full-screen offer card depends on.
///
/// All but [notifications] are Android "special" permissions: there is no runtime
/// dialog for them. Each can only be granted on its own Settings page, which is why
/// the flow below is a sequence of screen visits rather than a permission request.
enum AlertPermission {
  /// Without it nothing is shown at all.
  notifications,

  /// Android 14+ denies this by default to anything that is not a calling or alarm
  /// app. Denied, the alert still appears — as an ordinary heads-up banner that never
  /// wakes the screen. Nothing looks broken, which is what makes it expensive.
  fullScreenIntent,

  /// "Display over other apps". Also lifts the background-activity-launch ban, which
  /// is what lets the card start itself when the full-screen intent is refused.
  overlay,

  /// Doze defers FCM for battery-optimised apps, so an offer can arrive minutes late
  /// or after the window has closed.
  batteryOptimisation,
}

extension AlertPermissionCopy on AlertPermission {
  String get title => switch (this) {
        AlertPermission.notifications => 'Allow notifications',
        AlertPermission.fullScreenIntent => 'Full-screen order alerts',
        AlertPermission.overlay => 'Display over other apps',
        AlertPermission.batteryOptimisation => 'Unrestricted battery usage',
      };

  String get description => switch (this) {
        AlertPermission.notifications =>
          'Required to tell you an order has arrived at all.',
        AlertPermission.fullScreenIntent =>
          'Lets the order card cover your screen and wake your phone, instead of '
              'appearing as a banner you can miss.',
        AlertPermission.overlay =>
          'Shows the order card on top of whatever you are doing, so you can accept '
              'without opening the app.',
        AlertPermission.batteryOptimisation =>
          'Stops Android delaying orders while your screen is off. The most common '
              'reason riders stop being offered work.',
      };

  /// Missing this means orders are missed outright, not merely degraded.
  bool get isCritical => this != AlertPermission.overlay;
}

/// Checks and requests the permissions the offer card needs.
///
/// Requests are issued ONE AT A TIME, each waiting for the app to come back to the
/// foreground before the next. Android ignores a request to open a Settings page
/// while another is already showing, so firing all of them together means the rider
/// is shown exactly one and the rest are silently dropped — the app then believes it
/// asked for everything.
class AlertPermissionFlow {
  static const MethodChannel _channel =
      MethodChannel('app.fooddelivery/device_readiness');

  /// Never defaults to "granted".
  ///
  /// A helper that returns true when the channel throws hides real errors and makes
  /// a completely unconfigured device report as fully set up — the rider is told
  /// everything is fine while receiving nothing. Unknown is reported as NOT granted
  /// so the banner errs towards showing a step that is already done, rather than
  /// hiding one that is not.
  static Future<bool> _nativeBool(String method) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isGranted(AlertPermission permission) async {
    if (!Platform.isAndroid) return true;
    return switch (permission) {
      AlertPermission.notifications => Permission.notification.isGranted,
      AlertPermission.fullScreenIntent => _nativeBool('canUseFullScreenIntent'),
      AlertPermission.overlay => _nativeBool('canDrawOverlays'),
      AlertPermission.batteryOptimisation =>
        _nativeBool('isIgnoringBatteryOptimizations'),
    };
  }

  /// Everything still outstanding, in the order it should be asked for: cheapest and
  /// most important first, so a rider who gives up partway through has the steps that
  /// matter most already done.
  static Future<List<AlertPermission>> missing() async {
    if (!Platform.isAndroid) return const [];
    final result = <AlertPermission>[];
    for (final permission in AlertPermission.values) {
      if (!await isGranted(permission)) result.add(permission);
    }
    return result;
  }

  /// Opens the grant path for one permission. Returns whether anything opened.
  static Future<bool> request(AlertPermission permission) async {
    if (!Platform.isAndroid) return true;
    return switch (permission) {
      // The only one with a real runtime dialog.
      AlertPermission.notifications =>
        (await Permission.notification.request()).isGranted,
      AlertPermission.fullScreenIntent => _nativeBool('requestFullScreenIntent'),
      AlertPermission.overlay => _nativeBool('requestOverlay'),
      AlertPermission.batteryOptimisation =>
        _nativeBool('requestIgnoreBatteryOptimizations'),
    };
  }

  /// Walk the rider through every outstanding permission, one screen at a time.
  ///
  /// Returns whatever is still missing when the walk finishes.
  static Future<List<AlertPermission>> runSequentially() async {
    if (!Platform.isAndroid) return const [];

    for (final permission in await missing()) {
      // Re-checked immediately before asking: an earlier screen may have granted
      // this as a side effect, and OEM battery screens in particular often cover
      // several of these at once.
      if (await isGranted(permission)) continue;

      final opened = await request(permission);

      // The notification dialog resolves in place without backgrounding the app, so
      // there is no resume to wait for.
      if (permission == AlertPermission.notifications) continue;

      if (opened) await _waitForResume();
    }

    return missing();
  }

  /// Wait for the app to return to the foreground, with a ceiling.
  ///
  /// The timeout is not defensive padding. Several OEM Settings screens return
  /// without producing a resume event — and some never open despite reporting that
  /// they did — and without a ceiling the whole sequence would stop there, leaving
  /// every later permission unasked with no error anywhere.
  static Future<void> _waitForResume({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final observer = _ResumeObserver();
    WidgetsBinding.instance.addObserver(observer);
    try {
      await observer.resumed.timeout(timeout);
    } on TimeoutException {
      // Move on to the next permission rather than stalling the sequence.
    } finally {
      WidgetsBinding.instance.removeObserver(observer);
      observer.dispose();
    }

    // Settings state is not always readable the instant the app resumes.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  final Completer<void> _completer = Completer<void>();

  /// Only fires on a resume that follows a real backgrounding, so the resume caused
  /// by opening the Settings page cannot immediately satisfy its own wait.
  bool _wasPaused = false;

  Future<void> get resumed => _completer.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasPaused = true;
      return;
    }
    if (state == AppLifecycleState.resumed &&
        _wasPaused &&
        !_completer.isCompleted) {
      _completer.complete();
    }
  }

  void dispose() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Outstanding permissions, for the banner.
class AlertPermissionController extends AsyncNotifier<List<AlertPermission>> {
  bool _walkInFlight = false;

  @override
  Future<List<AlertPermission>> build() => AlertPermissionFlow.missing();

  Future<void> refresh() async {
    state = AsyncData(await AlertPermissionFlow.missing());
  }

  /// Run the guided sequence. Guarded because a second walk started while the first
  /// is mid-Settings would interleave two screens and lose both.
  Future<void> runSequentially() async {
    if (_walkInFlight) return;
    _walkInFlight = true;
    try {
      state = AsyncData(await AlertPermissionFlow.runSequentially());
    } finally {
      _walkInFlight = false;
    }
  }

  /// Fix one permission from the banner.
  Future<void> fix(AlertPermission permission) async {
    await AlertPermissionFlow.request(permission);
    await refresh();
  }
}

final alertPermissionControllerProvider =
    AsyncNotifierProvider<AlertPermissionController, List<AlertPermission>>(
  AlertPermissionController.new,
);
