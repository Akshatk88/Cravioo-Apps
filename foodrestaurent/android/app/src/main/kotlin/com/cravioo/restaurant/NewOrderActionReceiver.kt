package com.cravioo.restaurant

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles Accept and Reject pressed on the new-order notification.
 *
 * Silencing and clearing the alert happens HERE, synchronously, before anything that
 * can be slow or fail. The restaurant pressed a button; the ringing has to stop that
 * instant, whether or not the network call that follows succeeds.
 *
 * The status update itself is carried out by Dart, which already owns the auth token
 * and the API client. [PendingOrderAction] hands the decision over immediately when
 * the app's engine is alive, and parks it otherwise.
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
        Log.i(TAG, "action=${if (accepted) "accept" else "reject"} order=$orderId")

        // Stop the noise first, always.
        NewOrderRingtone.stop(orderId)
        
        // Show feedback notification immediately replacing the ringing alert
        NewOrderNotifier.showActionFeedback(context, orderId, accepted)

        PendingOrderAction.set(orderId = orderId, accepted = accepted)

        // Only Accept opens the app.
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
            // Reject: fire background HTTP request to update backend status immediately
            val pendingResult = goAsync()
            Thread {
                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    var token = prefs.getString("flutter.access_token", null)
                    if (token.isNullOrBlank()) {
                        val secPrefs = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
                        token = secPrefs.getString("VG9vbGtpdFNlY3VyZVN0b3JhZ2V_access_token", null)
                    }
                    if (!token.isNullOrBlank()) {
                        val url = java.net.URL("https://cravioo.in/api/v1/food/restaurant/orders/$orderId/status")
                        val conn = url.openConnection() as java.net.HttpURLConnection
                        conn.requestMethod = "PATCH"
                        conn.setRequestProperty("Authorization", "Bearer $token")
                        conn.setRequestProperty("Content-Type", "application/json")
                        conn.connectTimeout = 7000
                        conn.readTimeout = 7000
                        conn.doOutput = true
                        val bodyJson = "{\"orderStatus\":\"cancelled_by_restaurant\"}"
                        conn.outputStream.use { os ->
                            os.write(bodyJson.toByteArray())
                        }
                        val code = conn.responseCode
                        Log.i(TAG, "Background restaurant reject order=$orderId httpCode=$code")
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
        const val TAG = "NewOrderAction"
    }
}

/**
 * The restaurant's decision, parked until Dart can act on it.
 *
 * Process-static rather than persisted: the decision is only meaningful inside the
 * acceptance window, and an order that outlives the process has expired anyway.
 * Restoring one from disk after a cold start would confirm an order that no longer
 * exists.
 */
object PendingOrderAction {

    @Volatile
    private var pending: Map<String, Any?>? = null

    /**
     * Set by [MainActivity] while its Flutter engine exists, so a decision can be
     * handed to Dart the instant it is made.
     *
     * This is what lets Reject reach the server without opening the app.
     */
    @Volatile
    var listener: ((Map<String, Any?>) -> Unit)? = null

    @Synchronized
    fun set(orderId: String, accepted: Boolean) {
        val action = mapOf<String, Any?>("orderId" to orderId, "accepted" to accepted)
        pending = action

        // Delivered live when Dart is listening, and cleared so the poll on next
        // resume cannot act on the same decision twice.
        listener?.let { deliver ->
            pending = null
            deliver(action)
        }
    }

    /** Read-and-clear: acting on one decision twice would double-submit. */
    @Synchronized
    fun consume(): Map<String, Any?>? {
        val value = pending
        pending = null
        return value
    }

    @Synchronized
    fun hasPending(): Boolean = pending != null
}
