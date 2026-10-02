/// Tracks delivery orders that have been resolved (accepted, declined, completed, or cancelled)
/// in the current session so duplicate FCM pushes or socket events do not re-trigger
/// the incoming order alert siren or bottom sheet.
class OrderResolutionTracker {
  OrderResolutionTracker._();

  static final Set<String> _resolvedOrderIds = <String>{};
  static final Map<String, int> _recentAlertTimestamps = <String, int>{};

  /// Returns true if an alert for this order was already triggered within [windowMs].
  static bool hasAlertedRecently(String? orderId, {int windowMs = 30000}) {
    if (orderId == null || orderId.trim().isEmpty) return false;
    final cleanId = orderId.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _recentAlertTimestamps[cleanId];
    if (lastTime != null && (now - lastTime) < windowMs) {
      return true;
    }
    return false;
  }

  /// Marks that an alert for this order has been fired just now.
  static void markAlerted(String? orderId) {
    if (orderId != null && orderId.trim().isNotEmpty) {
      _recentAlertTimestamps[orderId.trim()] = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Marks an order as resolved so future alerts for it are suppressed.
  static void markResolved(String? orderId) {
    if (orderId != null && orderId.trim().isNotEmpty) {
      _resolvedOrderIds.add(orderId.trim());
    }
  }

  /// Returns true if this order has already been resolved in this app session.
  static bool isResolved(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) return false;
    return _resolvedOrderIds.contains(orderId.trim());
  }

  /// Clears the resolution cache (e.g. on logout).
  static void clear() {
    _resolvedOrderIds.clear();
    _recentAlertTimestamps.clear();
  }
}
