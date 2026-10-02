/// Tracks orders that have been resolved (accepted, rejected, confirmed, or cancelled)
/// in the current session so duplicate FCM pushes or socket events do not re-trigger
/// the incoming order alert siren or dialog.
class OrderResolutionTracker {
  OrderResolutionTracker._();

  static final Set<String> _resolvedOrderIds = <String>{};

  static final Map<String, int> _alertedTimestamps = <String, int>{};

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

  /// Returns true if an alert was already triggered for this order within [windowMs] (default 30s)
  static bool hasAlertedRecently(String? orderId, {int windowMs = 30000}) {
    if (orderId == null || orderId.trim().isEmpty) return false;
    final id = orderId.trim();
    if (_resolvedOrderIds.contains(id)) return true;
    final lastTime = _alertedTimestamps[id];
    if (lastTime == null) return false;
    return (DateTime.now().millisecondsSinceEpoch - lastTime) < windowMs;
  }

  /// Records that an alert was displayed for this order
  static void markAlerted(String? orderId) {
    if (orderId != null && orderId.trim().isNotEmpty) {
      _alertedTimestamps[orderId.trim()] = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Clears the resolution cache (e.g. on logout).
  static void clear() {
    _resolvedOrderIds.clear();
    _alertedTimestamps.clear();
  }
}
