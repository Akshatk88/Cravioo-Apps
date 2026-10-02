package com.cravioo.delivery

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles Accept and Reject pressed on the new-order notification in delivery app.
 */
class NewOrderActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val orderId = intent.getStringExtra(NewOrderNotifier.EXTRA_ORDER_ID)
        if (orderId.isNullOrBlank()) return

        val accepted = when (action) {
            NewOrderNotifier.ACTION_ACCEPT -> true
            NewOrderNotifier.ACTION_REJECT -> false
            else -> return
        }
        Log.i(TAG, "delivery action=${if (accepted) "accept" else "reject"} order=$orderId")

        // Stop the noise first, always.
        NewOrderRingtone.stop(orderId)
        
        // Show feedback notification immediately replacing the ringing alert
        NewOrderNotifier.showActionFeedback(context, orderId, accepted)

        PendingOrderAction.set(orderId = orderId, accepted = accepted)

        // Launch app on accept
        if (accepted) {
            try {
                val launch = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
                    }
                if (launch != null) context.startActivity(launch)
            } catch (t: Throwable) {
                Log.w(TAG, "could not launch app after accept", t)
            }
        } else {
            val pendingResult = goAsync()
            Thread {
                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    var token = prefs.getString("flutter.delivery_access_token", null)
                    if (token == null) {
                        val securePrefs = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
                        token = securePrefs.getString("VG9vbGtpdFNlY3VyZVN0b3JhZ2V_access_token", null)
                    }
                    if (!token.isNullOrBlank()) {
                        val url = java.net.URL("https://cravioo.in/api/v1/food/delivery/orders/$orderId/reject")
                        val conn = url.openConnection() as java.net.HttpURLConnection
                        conn.requestMethod = "PATCH"
                        conn.setRequestProperty("Authorization", "Bearer $token")
                        conn.setRequestProperty("Content-Type", "application/json")
                        conn.connectTimeout = 7000
                        conn.readTimeout = 7000
                        val code = conn.responseCode
                        Log.i(TAG, "Background reject order=$orderId httpCode=$code")
                    } else {
                        Log.w(TAG, "No token found to reject order=$orderId in background")
                    }
                } catch (t: Throwable) {
                    Log.w(TAG, "Background reject failed for order=$orderId: ${t.message}")
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }

    private companion object {
        const val TAG = "DeliveryOrderAction"
    }
}

/**
 * The delivery partner's decision, parked until Dart can act on it.
 */
object PendingOrderAction {

    @Volatile
    private var pending: Map<String, Any?>? = null

    @Volatile
    var listener: ((Map<String, Any?>) -> Unit)? = null

    @Synchronized
    fun set(orderId: String, accepted: Boolean) {
        val action = mapOf<String, Any?>("orderId" to orderId, "accepted" to accepted)
        pending = action
        listener?.invoke(action)
    }

    @Synchronized
    fun consume(): Map<String, Any?>? {
        val current = pending
        pending = null
        return current
    }

    @Synchronized
    fun hasPending(): Boolean = pending != null
}
