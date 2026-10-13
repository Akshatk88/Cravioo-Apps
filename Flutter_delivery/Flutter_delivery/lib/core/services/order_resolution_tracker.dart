/// Tracks delivery orders that have been resolved (accepted, declined, completed, or cancelled)
/// in the current session so duplicate FCM pushes or socket events do not re-trigger
/// the incoming order alert siren or bottom sheet.
class OrderResolutionTracker {
  OrderResolutionTracker._();

  /// Resolved order id -> when it was resolved (epoch ms).
  static final Map<String, int> _resolvedOrderIds = <String, int>{};
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
      _resolvedOrderIds[orderId.trim()] = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Returns true if this order has already been resolved in this app session.
  static bool isResolved(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) return false;
    return _resolvedOrderIds.containsKey(orderId.trim());
  }

  /// A fresh dispatch offer (`new_order_available`) for an order this rider
  /// already declined, missed or saw withdrawn: the restaurant pressed "Resend
  /// to drivers" and the backend re-offered it. Forget the old resolution so
  /// the new offer rings. Returns true when it was reopened.
  ///
  /// Only once [minAgeMs] has passed since it was resolved, so the socket and
  /// FCM copies of the SAME offer (which arrive within a second or two) cannot
  /// bring back an alert the rider just answered.
  static bool reopenForNewOffer(String? orderId, {int minAgeMs = 10000}) {
    if (orderId == null || orderId.trim().isEmpty) return false;
    final cleanId = orderId.trim();
    final resolvedAt = _resolvedOrderIds[cleanId];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (resolvedAt != null && (now - resolvedAt) < minAgeMs) return false;
    final lastAlert = _recentAlertTimestamps[cleanId];
    if (resolvedAt == null && lastAlert != null && (now - lastAlert) < minAgeMs) {
      return false;
    }
    final wasBlocked = resolvedAt != null || lastAlert != null;
    _resolvedOrderIds.remove(cleanId);
    _recentAlertTimestamps.remove(cleanId);
    return wasBlocked;
  }

  /// Clears the resolution cache (e.g. on logout).
  static void clear() {
    _resolvedOrderIds.clear();
    _recentAlertTimestamps.clear();
  }
}
