package com.cravioo.delivery

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Whether the app's own screen is showing; the in-app incoming screen owns that case. */
object AppForeground {
    @Volatile
    var isForeground: Boolean = false
}

/**
 * The high-priority new-order card drawn over other apps, straight from Kotlin
 * (same approach as the restaurant app).
 *
 * It used to be a second Flutter engine (flutter_overlay_window) started from the
 * FCM background isolate. That depends on an engine booting and data crossing an
 * isolate boundary while the app is in the background, and on real devices it
 * often showed nothing - the rider got only a plain notification. Kotlin already
 * runs for every order push (it rings and posts the notification), so the card is
 * raised right there from the push data itself.
 *
 * Reject reuses [NewOrderActionReceiver] (the notification's Reject button). Accept
 * opens MainActivity with the same accept intent the notification uses, which
 * stops the ring and hands the accept to Dart.
 */
object NewOrderOverlay {

    private const val TAG = "DeliveryOrderOverlay"

    private val main = Handler(Looper.getMainLooper())

    private var root: View? = null
    private var showingOrderId: String? = null
    private var countdownRunnable: Runnable? = null

    fun canShow(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /** Shows the card for [data]. Safe from any thread. */
    fun show(context: Context, data: Map<String, String>) {
        val app = context.applicationContext
        main.post {
            try {
                showOnMain(app, data)
            } catch (t: Throwable) {
                Log.e(TAG, "overlay failed", t)
            }
        }
    }

    /** Removes the card, if it is showing [orderId] (or any card when null). */
    fun dismiss(orderId: String?) {
        main.post {
            if (orderId != null && showingOrderId != null && showingOrderId != orderId) return@post
            removeOnMain()
        }
    }

    // ------------------------------------------------------------------------------

    private fun dp(context: Context, v: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, context.resources.displayMetrics).toInt()

    private fun rounded(color: Int, radius: Float, strokeColor: Int? = null, strokeWidth: Int = 0) =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
            if (strokeColor != null) setStroke(strokeWidth, strokeColor)
        }

    private fun text(context: Context, value: String, sp: Float, color: Int, bold: Boolean = false) =
        TextView(context).apply {
            text = value
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            setTextColor(color)
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }

    private fun money(raw: String?): String? {
        val v = raw?.toDoubleOrNull() ?: return null
        return if (v == Math.floor(v)) "₹${v.toLong()}" else "₹%.1f".format(v)
    }

    private fun showOnMain(context: Context, data: Map<String, String>) {
        val orderId = NewOrderMessagingService.orderIdOf(data) ?: return
        if (!canShow(context)) {
            Log.i(TAG, "no overlay permission; notification only")
            return
        }
        if (AppForeground.isForeground) {
            Log.i(TAG, "app in foreground; in-app incoming screen shows the offer")
            return
        }
        // Same order again: keep the card that is already up.
        if (showingOrderId == orderId && root != null) return
        removeOnMain()

        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val green = Color.parseColor("#1FA84F")
        val greenDark = Color.parseColor("#0B3D1E")
        val greenTint = Color.parseColor("#F2FBF5")
        val red = Color.parseColor("#D64545")
        val ink = Color.parseColor("#111827")
        val muted = Color.parseColor("#6B7280")

        val displayId = data["orderId"]?.takeIf { it.isNotBlank() && it != orderId }
        val earning = money(data["riderEarning"] ?: data["price"] ?: data["earnings"])
        val isPrepaid = data["isPrepaid"] == "true"
        val orderValue = money(data["orderValue"] ?: data["total"])
        val toCollect = if (isPrepaid) "₹0" else (money(data["amountToCollect"] ?: data["cashToCollect"]) ?: orderValue ?: "—")

        val pad = dp(context, 16f)

        // ---- card ----
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(Color.WHITE, dp(context, 26f).toFloat())
            elevation = dp(context, 12f).toFloat()
            clipToOutline = true
        }

        // ---- green header ----
        val header = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad + dp(context, 2f), pad, pad, pad)
            background = GradientDrawable().apply {
                setColor(green)
                val r = dp(context, 26f).toFloat()
                cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
            }
        }
        val titleRow = LinearLayout(context).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        titleRow.addView(
            text(context, "🔔  New Order Received!", 20f, Color.WHITE, bold = true),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        titleRow.addView(
            text(context, "✕", 20f, Color.WHITE, bold = true).apply {
                setPadding(dp(context, 10f), 0, 0, 0)
                setOnClickListener { removeOnMain() }
            },
        )
        header.addView(titleRow)
        header.addView(
            text(
                context,
                listOfNotNull(displayId?.let { "Order $it" }, earning?.let { "$it earning" })
                    .joinToString("  •  ")
                    .ifBlank { "A new delivery is waiting" },
                15f,
                Color.WHITE,
                bold = true,
            ).apply { setPadding(0, dp(context, 4f), 0, 0) },
        )
        header.addView(
            text(context, "Accept before the time runs out", 13f, Color.parseColor("#E6FFFFFF"))
                .apply { setPadding(0, dp(context, 2f), 0, 0) },
        )
        val countdown = text(context, "", 16f, greenDark, bold = true).apply {
            background = rounded(Color.WHITE, dp(context, 22f).toFloat())
            setPadding(dp(context, 18f), dp(context, 8f), dp(context, 18f), dp(context, 8f))
        }
        header.addView(
            countdown,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 12f)
                gravity = Gravity.CENTER_HORIZONTAL
            },
        )
        card.addView(header)

        // ---- details ----
        val bodyBox = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad + dp(context, 2f), dp(context, 6f), pad + dp(context, 2f), pad)
        }
        fun row(label: String, value: String, sub: String? = null) {
            bodyBox.addView(text(context, label, 12.5f, muted).apply { setPadding(0, dp(context, 10f), 0, 0) })
            bodyBox.addView(text(context, value, 16f, ink, bold = true).apply { maxLines = 3 })
            if (!sub.isNullOrBlank()) bodyBox.addView(text(context, sub, 12.5f, muted).apply { maxLines = 2 })
        }
        row(
            "Pickup from",
            data["restaurantName"]?.takeIf { it.isNotBlank() } ?: "Restaurant",
            data["pickupAddress"],
        )
        row(
            "Deliver to",
            data["customerName"]?.takeIf { it.isNotBlank() } ?: "Customer",
            data["dropAddress"],
        )
        row("Items", data["itemsSummary"]?.takeIf { it.isNotBlank() } ?: "—")
        row("Order value (customer pays)", "${orderValue ?: "—"}   •   ${if (isPrepaid) "Prepaid" else "Cash"}")

        // Collect / earning box
        val moneyBox = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            background = rounded(greenTint, dp(context, 16f).toFloat(), Color.parseColor("#BFE8CD"), dp(context, 1f))
            setPadding(dp(context, 14f), dp(context, 12f), dp(context, 14f), dp(context, 12f))
        }
        fun moneyCol(title: String, amount: String, note: String?): LinearLayout =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(text(context, title, 12.5f, ink))
                addView(text(context, amount, 22f, green, bold = true).apply { setPadding(0, dp(context, 4f), 0, 0) })
                if (note != null) addView(text(context, note, 11.5f, muted))
            }
        moneyBox.addView(
            moneyCol(
                "👛 Total to collect",
                toCollect,
                if (isPrepaid) "Prepaid — collect nothing" else "Collect cash at delivery",
            ),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )
        moneyBox.addView(
            moneyCol("👛 Your earning", earning ?: "—", null),
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { leftMargin = dp(context, 12f) },
        )
        bodyBox.addView(
            moneyBox,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(context, 14f)
            },
        )

        // ---- actions ----
        val actions = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 16f), 0, 0)
        }
        val btnHeight = dp(context, 54f)
        val reject = text(context, "✕  REJECT", 16f, red, bold = true).apply {
            gravity = Gravity.CENTER
            background = rounded(Color.WHITE, dp(context, 16f).toFloat(), red, dp(context, 2f))
            setOnClickListener {
                sendReject(context, orderId)
                removeOnMain()
            }
        }
        val accept = text(context, "✓  ACCEPT ORDER", 16f, Color.WHITE, bold = true).apply {
            gravity = Gravity.CENTER
            background = rounded(green, dp(context, 16f).toFloat())
            setOnClickListener {
                // Opened while this window is still on screen: that is what lets a
                // background app start an activity at all.
                openApp(context, orderId, accept = true)
                removeOnMain()
            }
        }
        actions.addView(reject, LinearLayout.LayoutParams(0, btnHeight, 1f))
        actions.addView(accept, LinearLayout.LayoutParams(0, btnHeight, 1.6f).apply { leftMargin = dp(context, 12f) })
        bodyBox.addView(actions)
        bodyBox.addView(
            text(context, "🛡  High priority order • We'll notify the customer once you accept.", 12.5f, muted)
                .apply { setPadding(0, dp(context, 12f), 0, 0) },
        )
        card.addView(bodyBox)

        // Tapping the details opens the offer in the app.
        bodyBox.setOnClickListener {
            openApp(context, orderId, accept = false)
            removeOnMain()
        }

        val scroll = ScrollView(context).apply {
            isVerticalScrollBarEnabled = false
            addView(card)
        }
        val container = FrameLayout(context).apply {
            setPadding(dp(context, 12f), 0, dp(context, 12f), 0)
            addView(scroll)
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val screenH = context.resources.displayMetrics.heightPixels
        @Suppress("DEPRECATION")
        val params = WindowManager.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        ).apply {
            // Wrap-content height + top gravity: the rest of the screen stays usable.
            gravity = Gravity.TOP
            y = statusBarHeight(context) + dp(context, 12f)
        }
        // Never taller than the screen (small phones scroll inside the card).
        scroll.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        scroll.post {
            val max = (screenH * 0.86f).toInt()
            if (scroll.height > max) {
                scroll.layoutParams = scroll.layoutParams.apply { height = max }
            }
        }

        wm.addView(container, params)
        root = container
        showingOrderId = orderId
        Log.i(TAG, "overlay shown for $orderId")

        startCountdown(data, countdown)
    }

    private fun statusBarHeight(context: Context): Int {
        val id = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) context.resources.getDimensionPixelSize(id) else 0
    }

    private fun startCountdown(data: Map<String, String>, view: TextView) {
        var left = (data["offerTimeoutSeconds"]?.toIntOrNull() ?: 45).coerceIn(15, 90)
        val tick = object : Runnable {
            override fun run() {
                if (root == null) return
                view.text = "⏱  Accept within $left sec"
                if (left <= 0) {
                    removeOnMain()
                    return
                }
                left -= 1
                main.postDelayed(this, 1000)
            }
        }
        countdownRunnable = tick
        tick.run()
    }

    private fun removeOnMain() {
        countdownRunnable?.let { main.removeCallbacks(it) }
        countdownRunnable = null
        val v = root ?: return
        root = null
        showingOrderId = null
        try {
            (v.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Throwable) {
            // Already detached.
        }
    }

    private fun sendReject(context: Context, orderId: String) {
        val intent = Intent(context, NewOrderActionReceiver::class.java).apply {
            action = NewOrderNotifier.ACTION_REJECT
            putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
        }
        context.sendBroadcast(intent)
    }

    /** Opens the app on this offer; with [accept] it also accepts it (MainActivity handles the intent). */
    private fun openApp(context: Context, orderId: String, accept: Boolean) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
                if (accept) {
                    action = NewOrderNotifier.ACTION_ACCEPT
                    putExtra(NewOrderNotifier.EXTRA_ORDER_ACTION, "accept")
                }
            }
            context.startActivity(intent)
        } catch (t: Throwable) {
            Log.w(TAG, "could not open app", t)
        }
    }
}
