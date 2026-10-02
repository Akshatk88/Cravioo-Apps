package com.cravioo.delivery

import android.content.Context
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Raises the new-order alert from Kotlin the instant FCM lands.
 *
 * Extends FlutterFirebaseMessagingService so both native alerting AND
 * Dart's firebase_messaging background listener receive the message.
 */
class NewOrderMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val notif = message.notification
        val title = (data["title"] ?: notif?.title ?: "").lowercase()
        val body = (data["body"] ?: notif?.body ?: "").lowercase()
        val type = data["type"]
        val orderId = orderIdOf(data)
        var orderStatus = (data["orderStatus"] ?: data["status"])?.lowercase()

        Log.d(TAG, "[FCM] MESSAGE RECEIVED (native) type=$type data=$data")
        Log.i(TAG, "Delivery FCM received: type=$type id=$orderId status=$orderStatus title=$title")

        if (data.isNotEmpty() || notif != null) {
            val isExplicitDismiss = type in CLOSE_TYPES ||
                    (data["isCancel"] == "true") ||
                    title.contains("cancel")

            if (isExplicitDismiss) {
                if (orderId != null) {
                    withdraw(orderId)
                }
                super.onMessageReceived(message)
                return
            }

            val isOrderReadyAnnouncement = type in READY_TYPES ||
                    title.contains("ready for pickup") ||
                    title.contains("order ready") ||
                    body.contains("ready for pickup") ||
                    body.contains("order ready")

            // If orderStatus is missing/null, fetch remote status from backend API
            if (orderStatus.isNullOrBlank() && !isOrderReadyAnnouncement && orderId != null) {
                orderStatus = fetchRemoteOrderStatus(applicationContext, orderId)
                Log.i(TAG, "Fetched remote orderStatus for $orderId: $orderStatus")
            }

            val isReady = isOrderReadyAnnouncement ||
                    orderStatus in READY_STATUSES

            // STRICT FILTER: If order is created, placed, pending, confirmed, or preparing,
            // or if it's NOT ready, DO NOT alert delivery! Delivery must ONLY ring when food is ready.
            val isNotReady = orderStatus in NOT_READY_STATUSES || (!isReady && orderStatus != null)

            val isNewOrder = isReady && !isNotReady && (
                type in NEW_ORDER_TYPES ||
                isOrderReadyAnnouncement ||
                data["audience"] == "delivery" ||
                data.containsKey("pickupAddress") ||
                data.containsKey("restaurantName")
            )

            try {
                if (isNewOrder) {
                    Log.i(TAG, "Displaying incoming order alert for $orderId (status=$orderStatus)")
                    // Foreground is excluded deliberately: the in-app alert owns that
                    // case, and floating a second copy over our own screen helps nobody.
                    if (!AppForeground.isForeground) {
                        // Dart's background handler returns early for these pushes, so
                        // this is the ONLY place a notification can come from — the
                        // card, or the fallback below, never both.
                        if (NewOrderOverlay.show(applicationContext, data)) {
                            Log.d(TAG, "[NEW_ORDER] overlay owns this one — no notification")
                        } else {
                            Log.d(TAG, "[NEW_ORDER] overlay unavailable — posting the fallback")
                            NewOrderNotifier.post(applicationContext, data)
                        }
                    }
                } else {
                    Log.i(TAG, "Suppressed incoming order alert for $orderId: isReady=$isReady isNotReady=$isNotReady status=$orderStatus")
                    if (isNotReady && orderId != null) {
                        withdraw(orderId)
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to post new-order alert", t)
                if (isNewOrder) {
                    try {
                        NewOrderNotifier.post(applicationContext, data)
                    } catch (_: Throwable) {
                    }
                }
            }
        }

        super.onMessageReceived(message)
    }

    /** Card, ringtone, our notification and the server's tray copy — all of it. */
    private fun withdraw(orderId: String) {
        NewOrderOverlay.dismissFor(orderId)
        NewOrderNotifier.cancel(applicationContext, orderId)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    private fun fetchRemoteOrderStatus(context: Context, orderId: String): String? {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            var token = prefs.getString("flutter.delivery_access_token", null)
            if (token.isNullOrBlank()) {
                val secPrefs = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
                token = secPrefs.getString("VG9vbGtpdFNlY3VyZVN0b3JhZ2V_access_token", null)
            }

            val url = URL("https://cravioo.in/api/v1/food/delivery/orders/$orderId")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 3000
            conn.readTimeout = 3000
            if (!token.isNullOrBlank()) {
                conn.setRequestProperty("Authorization", "Bearer $token")
            }
            conn.setRequestProperty("Accept", "application/json")

            if (conn.responseCode in 200..299) {
                val responseBody = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(responseBody)
                val dataObj = json.optJSONObject("data")
                val orderObj = dataObj?.optJSONObject("order") ?: dataObj
                orderObj?.optString("orderStatus")?.lowercase()?.takeIf { it.isNotBlank() }
            } else {
                Log.w(TAG, "fetchRemoteOrderStatus HTTP ${conn.responseCode} for $orderId")
                null
            }
        } catch (e: Exception) {
            Log.w(TAG, "fetchRemoteOrderStatus exception for $orderId: ${e.message}")
            null
        }
    }

    companion object {
        private const val TAG = "DeliveryOrderFcm"

        private val NOT_READY_STATUSES = setOf(
            "created",
            "pending",
            "placed",
            "confirmed",
            "preparing"
        )

        private val READY_STATUSES = setOf(
            "ready_for_pickup",
            "ready"
        )

        private val READY_TYPES = setOf(
            "order_ready",
            "order_ready_for_pickup"
        )

        private val NEW_ORDER_TYPES = setOf(
            "new_order",
            "new_order_available",
            "order_assigned",
            "delivery_partner_assigned",
            "order_ready",
            "order_ready_for_pickup"
        )

        private val CLOSE_TYPES = setOf(
            "order_taken",
            "order_deassigned",
            "order_cancelled",
            "cancel_order",
            "order_expired",
            "order_delivered",
            "order_completed"
        )

        fun orderIdOf(data: Map<String, String>): String? =
            listOf("orderMongoId", "orderId", "_id", "id", "order_id")
                .asSequence()
                .mapNotNull { data[it] }
                .firstOrNull { it.isNotBlank() }
    }
}
