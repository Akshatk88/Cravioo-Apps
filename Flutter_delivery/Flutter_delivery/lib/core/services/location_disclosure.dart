import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play "Prominent Disclosure and Consent" for location.
///
/// The app uses ACCESS_BACKGROUND_LOCATION (live tracking of an order while
/// the app is closed). Play requires an in-app disclosure, shown BEFORE the
/// system location prompt, that says what data is collected, why, and that it
/// is collected in the background, and the rider must accept it. Without it
/// the app is rejected ("Missing Prominent Disclosure").
///
/// [ensure] shows it once; after "Accept" the system prompts follow exactly
/// as before. On "Deny" no location permission is requested.
class LocationDisclosure {
  LocationDisclosure._();

  static const _acceptedKey = 'location_disclosure_accepted_v1';

  /// Supplies a context to show the dialog on (set from the app's router).
  static BuildContext? Function()? contextResolver;

  static bool _showing = false;

  /// True while the disclosure is on screen (other start-up dialogs wait).
  static bool get isShowing => _showing;

  static Future<bool> isAccepted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_acceptedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// True once the rider has accepted (now or earlier).
  static Future<bool> ensure([BuildContext? context]) async {
    if (await isAccepted()) return true;
    if (_showing) return false;

    final ctx = context ?? contextResolver?.call();
    if (ctx == null || !ctx.mounted) return false;

    _showing = true;
    bool? accepted;
    try {
      accepted = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const _LocationDisclosureDialog(),
      );
    } finally {
      _showing = false;
    }

    if (accepted == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_acceptedKey, true);
      } catch (_) {}
      return true;
    }
    return false;
  }
}

class _LocationDisclosureDialog extends StatelessWidget {
  const _LocationDisclosureDialog();

  static const _green = Color(0xFF1FA84F);

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final body = TextStyle(fontSize: 14, height: 1.45, color: onSurface.withValues(alpha: 0.8));

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: _green),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: body)),
            ],
          ),
        );

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_rounded, size: 34, color: _green),
        ),
        title: const Text(
          'Location access',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cravioo Delivery collects location data to enable live order '
                'tracking, assign you nearby delivery orders and show navigation '
                'to pickup and drop points, even when the app is closed or not '
                'in use, while you are online.',
                style: body.copyWith(fontWeight: FontWeight.w600, color: onSurface),
              ),
              const SizedBox(height: 14),
              point(Icons.delivery_dining_rounded,
                  'Your location is used to offer you orders near you and to calculate trip distance and earnings.'),
              point(Icons.share_location_rounded,
                  'During an active delivery your live location is shared with the customer and the restaurant for that order.'),
              point(Icons.nights_stay_rounded,
                  'Location is collected in the background only while you are online. Go offline to stop it.'),
              const SizedBox(height: 4),
              Text(
                'You can change this anytime in your phone settings.',
                style: body.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Deny'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
