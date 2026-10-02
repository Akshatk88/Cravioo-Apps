package com.cravioo.restaurant

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * DEBUG ONLY. Drives the new-order alert from adb, without involving FCM.
 *
 * Lives in src/debug so it is not compiled into release at all — not merely disabled
 * there, absent.
 *
 * Exercising the alert through a real push means depending on push delivery, Doze,
 * per-OEM background limits and which device currently holds the account's FCM token.
 * None of those are the alert's behaviour, and every one of them fails in a way that
 * looks identical to the alert being broken, which makes it nearly impossible to test
 * in isolation. Driving the Accept/Reject actions from here is likewise the only way
 * to test them deterministically: hunting for the buttons in the notification shade
 * depends on whether the heads-up is still expanded, which it usually is not.
 *
 *   adb shell am broadcast -n com.cravioo.restaurant/.NewOrderDebugReceiver \
 *       -e orderId TEST1 -e total 349
 *   adb shell am broadcast -n com.cravioo.restaurant/.NewOrderDebugReceiver \
 *       -e orderId TEST1 -e do accept
 */
class NewOrderDebugReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val orderId = intent.getStringExtra("orderId") ?: "DEBUG_ORDER"

        when (intent.getStringExtra("do")) {
            // Delivered straight to the real receiver, in-process, so exported="false"
            // on it stays intact — the production path is what gets exercised.
            "accept", "reject" -> {
                val accepted = intent.getStringExtra("do") == "accept"
                NewOrderActionReceiver().onReceive(
                    app,
                    Intent(app, NewOrderActionReceiver::class.java).apply {
                        action = if (accepted) {
                            NewOrderNotifier.ACTION_ACCEPT
                        } else {
                            NewOrderNotifier.ACTION_REJECT
                        }
                        putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
                    },
                )
            }
            else -> {
                val data = HashMap<String, String>()
                intent.extras?.let { extras ->
                    for (key in extras.keySet()) {
                        val value = extras.get(key)
                        if (value is String) data[key] = value
                    }
                }
                data["type"] = "new_order"
                data["orderId"] = orderId
                NewOrderNotifier.show(app, data)
            }
        }
    }
}
