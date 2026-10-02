package com.cravioo.restaurant

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val ORDER_ACTION_CHANNEL = "app.foodrestaurant/new_order_action"

    /**
     * Held so a decision arriving from the notification can be pushed at Dart
     * immediately, instead of waiting for the next time Dart happens to poll.
     */
    private var actionChannel: MethodChannel? = null
    private var pendingIncomingOrderId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val initialOrderId = intent?.getStringExtra(NewOrderNotifier.EXTRA_ORDER_ID)
        val initialHandled = intent?.getBooleanExtra("orderActionHandled", false) ?: false
        if (!initialOrderId.isNullOrBlank() && !initialHandled) {
            pendingIncomingOrderId = initialOrderId
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORDER_ACTION_CHANNEL)
            .also { channel ->
                actionChannel = channel

                // Lets a Reject pressed on the notification reach Dart without the app
                // being brought to the foreground. invokeMethod must be called from
                // the main thread; the receiver runs there, but the post keeps that
                // true regardless of who calls set().
                PendingOrderAction.listener = { action ->
                    runOnUiThread { actionChannel?.invokeMethod("onOrderAction", action) }
                }

                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Read-and-clear. Dart calls this on start and on resume, which
                        // is the path that matters when the app was killed: no engine
                        // existed when the button was pressed, so the decision has to
                        // wait for Dart rather than the other way round.
                        "consumePendingAction" -> result.success(PendingOrderAction.consume())
                        "hasPendingAction" -> result.success(PendingOrderAction.hasPending())
                        "consumePendingIncomingOrder" -> {
                            val id = pendingIncomingOrderId
                            pendingIncomingOrderId = null
                            result.success(id)
                        }
                        "dismissOrderAlert" -> {
                            NewOrderNotifier.dismiss(
                                applicationContext,
                                call.argument<String>("orderId"),
                            )
                            result.success(true)
                        }
                        "startAlertSound" -> {
                            val orderId = call.argument<String>("orderId") ?: "new_order"
                            val ringMillis = (call.argument<Number>("ringMillis")?.toLong()) ?: 60000L
                            NewOrderRingtone.start(applicationContext, orderId, ringMillis)
                            result.success(true)
                        }
                        // Used when the order is answered inside the app, so the alert
                        // and its ringing stop there too.
                        "stopAlertSound" -> {
                            NewOrderRingtone.stop(call.argument<String>("orderId"))
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    /**
     * A decision taken on the notification while the app was already running. onCreate
     * has come and gone, so Dart would not otherwise learn about it until its next
     * poll — push it now so Accept feels immediate.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val handled = intent.getBooleanExtra("orderActionHandled", false)
        if (PendingOrderAction.hasPending()) {
            actionChannel?.invokeMethod("onOrderAction", PendingOrderAction.consume())
        }
        val orderId = intent.getStringExtra(NewOrderNotifier.EXTRA_ORDER_ID)
        if (!orderId.isNullOrBlank() && !handled) {
            pendingIncomingOrderId = orderId
            actionChannel?.invokeMethod("onIncomingOrder", orderId)
        }
    }

    /** The engine is going away; a stale listener would invoke a dead channel. */
    override fun onDestroy() {
        PendingOrderAction.listener = null
        actionChannel = null
        super.onDestroy()
    }
}
