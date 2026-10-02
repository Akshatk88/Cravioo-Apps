import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Best-effort whitelisting so aggressive OEM battery managers stop blocking
/// the app's process from starting to show the new-order alert when killed.
///
/// Two independent mechanisms, both Android-only:
/// - The stock Doze/App Standby exemption (works everywhere, one system API).
/// - OEM "Autostart"/"background pop-up" screens (Xiaomi, Vivo, Oppo, Huawei,
///   Asus, Letv), which stock Android has no API for at all — each is reached
///   by launching that manufacturer's own settings activity directly, and
///   silently skipped if it doesn't exist on this device/firmware.
class BatteryOptimizationService {
  BatteryOptimizationService._();

  /// Requests exemption from Doze/App Standby battery optimization.
  ///
  /// A no-op (returns true) on non-Android platforms.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) return true;
      final result = await Permission.ignoreBatteryOptimizations.request();
      return result.isGranted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('requestIgnoreBatteryOptimizations failed: $e');
      }
      return false;
    }
  }

  // Each entry is one OEM's Autostart/background-permission activity. Tried in
  // order; the first one whose component actually exists on this device wins.
  // Component names are undocumented OEM internals that shift across
  // firmware versions, so a miss here is expected and harmless — the
  // exception is swallowed and the next candidate is tried.
  static final List<_AutostartTarget> _targets = [
    _AutostartTarget(
      'com.miui.securitycenter',
      'com.miui.permcenter.autostart.AutoStartManagementActivity',
    ),
    _AutostartTarget(
      'com.coloros.safecenter',
      'com.coloros.safecenter.permission.startup.StartupAppListActivity',
    ),
    _AutostartTarget(
      'com.oppo.safe',
      'com.oppo.safe.permission.startup.StartupAppListActivity',
    ),
    _AutostartTarget(
      'com.iqoo.secure',
      'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity',
    ),
    _AutostartTarget(
      'com.vivo.permissionmanager',
      'com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
    ),
    _AutostartTarget(
      'com.huawei.systemmanager',
      'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
    ),
    _AutostartTarget(
      'com.asus.mobilemanager',
      'com.asus.mobilemanager.autostart.AutoStartActivity',
    ),
    _AutostartTarget(
      'com.letv.android.letvsafe',
      'com.letv.android.letvsafe.AutobootManageActivity',
    ),
  ];

  /// Opens this device's manufacturer-specific Autostart settings screen, if
  /// one is recognized. Returns false on stock/unrecognized firmware — the
  /// Doze exemption above is the only thing that applies there.
  static Future<bool> openAutostartSettings() async {
    if (!Platform.isAndroid) return false;
    for (final target in _targets) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          componentName: '${target.package}/${target.activity}',
        );
        await intent.launch();
        return true;
      } catch (_) {
        // Not this device's manufacturer/firmware — try the next candidate.
        continue;
      }
    }
    return false;
  }
}

class _AutostartTarget {
  const _AutostartTarget(this.package, this.activity);
  final String package;
  final String activity;
}
