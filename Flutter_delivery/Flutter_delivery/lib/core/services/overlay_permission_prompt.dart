import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import 'location_disclosure.dart';
import 'order_overlay_service.dart';

/// Asks for "Display over other apps" so the new-order overlay can appear
/// while the rider is outside the app.
///
/// The permission was only requested from the Device readiness screen, so after
/// every fresh install it stayed off and the overlay silently never showed.
class OverlayPermissionPrompt {
  OverlayPermissionPrompt(this._ref);

  final Ref _ref;
  bool _showing = false;
  DateTime? _lastShownAt;

  static const _cooldown = Duration(minutes: 30);

  Future<void> check({bool force = false}) async {
    // Never on top of the location disclosure (it must be read and answered).
    if (!Platform.isAndroid || _showing || LocationDisclosure.isShowing) return;
    if (await OrderOverlayService.hasPermission()) return;
    if (!force &&
        _lastShownAt != null &&
        DateTime.now().difference(_lastShownAt!) < _cooldown) {
      return;
    }

    final context =
        _ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    _showing = true;
    _lastShownAt = DateTime.now();
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.layers_rounded, color: Color(0xFF1FA84F), size: 40),
        title: const Text('Allow order pop-up', textAlign: TextAlign.center),
        content: const Text(
          'New orders appear as a pop-up over other apps so you can accept '
          'them instantly. On the next screen turn on "Allow display over '
          'other apps" for Cravioo Delivery.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Later'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1FA84F),
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    _showing = false;
    if (allow == true) await OrderOverlayService.requestPermission();
  }
}

final overlayPermissionPromptProvider =
    Provider<OverlayPermissionPrompt>(OverlayPermissionPrompt.new);
