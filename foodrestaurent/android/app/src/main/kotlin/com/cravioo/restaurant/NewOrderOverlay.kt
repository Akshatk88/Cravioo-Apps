package com.cravioo.restaurant

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
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Whether the app's own screen is showing; the in-app dialog owns that case. */
object AppForeground {
    @Volatile
    var isForeground: Boolean = false
}

/**
 * The new-order card drawn over other apps, straight from Kotlin.
 *
 * It used to be a second Flutter engine (flutter_overlay_window) started from the
 * FCM background isolate. That path depends on an engine booting and an order
 * crossing an isolate boundary while the app is killed, and on real devices it
 * often showed nothing. Kotlin already runs for every push (it rings and posts the
 * notification), so the card is raised right there, from the push data itself.
 *
 * Answering reuses [NewOrderActionReceiver] - the same code the notification's
 * Accept/Reject buttons run - so the ring stops and the order is updated in one place.
 */
object NewOrderOverlay {

    private const val TAG = "NewOrderOverlay"
    private const val API_BASE = "https://cravioo.in/api/v1"

    private val main = Handler(Looper.getMainLooper())

    private var root: View? = null
    private var showingOrderId: String? = null
    private var countdownRunnable: Runnable? = null

    // Views updated after the details fetch.
    private var customerView: TextView? = null
    private var itemsView: TextView? = null
    private var totalView: TextView? = null
    private var headlineView: TextView? = null

    /**
     * Orders that arrived while another card was on screen. They used to REPLACE
     * the card (and the ring), so with two orders the first one silently lost its
     * alert: answering the second closed the only card and it looked as if both
     * had been accepted. Now they wait here and come up one by one.
     */
    private val queue = LinkedHashMap<String, Map<String, String>>()
    private var appContext: Context? = null
    private var moreView: TextView? = null

    private fun updateMoreBadge() {
        val n = queue.size
        moreView?.apply {
            text = if (n == 1) "+1 more order waiting" else "+$n more orders waiting"
            visibility = if (n > 0) View.VISIBLE else View.GONE
        }
    }

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
            if (orderId == null) {
                // App came to the front: its own dialog handles orders from here.
                queue.clear()
                removeOnMain(showNext = false)
                return@post
            }
            if (queue.remove(orderId) != null) {
                updateMoreBadge()
                return@post
            }
            if (showingOrderId != null && showingOrderId != orderId) return@post
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

    private fun showOnMain(context: Context, data: Map<String, String>) {
        val orderId = NewOrderMessagingService.orderIdOf(data) ?: return
        if (!canShow(context)) {
            Log.i(TAG, "no overlay permission; notification only")
            return
        }
        appContext = context
        // Same order again: keep the card that is already up.
        if (showingOrderId == orderId && root != null) return
        // Another order's card is up: queue this one instead of replacing it.
        if (root != null && showingOrderId != null) {
            queue[orderId] = data
            updateMoreBadge()
            Log.i(TAG, "queued $orderId behind $showingOrderId (${queue.size} waiting)")
            return
        }
        queue.remove(orderId)
        removeOnMain(showNext = false)

        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val green = Color.parseColor("#22C55E")
        val greenDark = Color.parseColor("#16A34A")
        val red = Color.parseColor("#DC2626")
        val ink = Color.parseColor("#111827")
        val muted = Color.parseColor("#6B7280")

        val restaurantId = data["restaurantId"]?.takeIf { it.isNotBlank() }
        val outletName = data["restaurantName"]?.takeIf { it.isNotBlank() }
        val otherOutlet = NewOrderNotifier.isOtherOutlet(context, restaurantId)
        val displayId = (data["orderDisplayId"] ?: data["orderNumber"])?.takeIf { it.isNotBlank() }
        val body = data["body"]?.takeIf { it.isNotBlank() } ?: "A new order is waiting for review."

        val pad = dp(context, 16f)

        // ---- card ----
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = rounded(Color.WHITE, dp(context, 26f).toFloat())
            elevation = dp(context, 12f).toFloat()
            clipToOutline = true
        }

        // ---- header ----
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
        val close = text(context, "✕", 20f, Color.WHITE, bold = true).apply {
            setPadding(dp(context, 10f), 0, 0, 0)
            setOnClickListener { removeOnMain() }
        }
        titleRow.addView(close)
        header.addView(titleRow)

        headlineView = text(context, if (displayId != null) "Order #$displayId" else body, 15f, Color.WHITE).apply {
            setPadding(0, dp(context, 4f), 0, 0)
        }
        header.addView(headlineView)
        header.addView(
            text(
                context,
                when {
                    otherOutlet && outletName != null -> "For $outletName (another outlet)"
                    outletName != null -> outletName
                    else -> "Accept before the time runs out"
                },
                13f,
                Color.parseColor("#E6FFFFFF"),
            ).apply { setPadding(0, dp(context, 2f), 0, 0) },
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
        moreView = text(context, "", 13f, Color.WHITE, bold = true).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(context, 8f), 0, 0)
        }
        header.addView(
            moreView,
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT),
        )
        updateMoreBadge()
        card.addView(header)

        // ---- details ----
        val bodyBox = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad + dp(context, 2f), dp(context, 12f), pad + dp(context, 2f), pad)
        }
        fun row(label: String, value: String): TextView {
            bodyBox.addView(text(context, label, 12.5f, muted).apply { setPadding(0, dp(context, 8f), 0, 0) })
            val v = text(context, value, 16f, ink, bold = true).apply { maxLines = 6 }
            bodyBox.addView(v)
            return v
        }
        customerView = row("Customer", data["customerName"]?.takeIf { it.isNotBlank() } ?: "—")
        itemsView = row("Items", body)
        totalView = row("Order value", data["total"]?.takeIf { it.isNotBlank() }?.let { "₹$it" } ?: "—")

        // ---- actions ----
        val actions = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 16f), 0, 0)
        }
        val btnHeight = dp(context, 52f)
        if (otherOutlet) {
            val open = text(context, "OPEN ${(outletName ?: "OUTLET").uppercase()}", 16f, Color.WHITE, bold = true).apply {
                gravity = Gravity.CENTER
                background = rounded(greenDark, dp(context, 16f).toFloat())
                setOnClickListener {
                    launchApp(context, orderId, restaurantId, answered = false)
                    removeOnMain()
                }
            }
            actions.addView(open, LinearLayout.LayoutParams(0, btnHeight, 1f))
        } else {
            val reject = text(context, "✕  REJECT", 16f, red, bold = true).apply {
                gravity = Gravity.CENTER
                background = rounded(Color.WHITE, dp(context, 16f).toFloat(), red, dp(context, 2f))
                setOnClickListener {
                    sendAction(context, NewOrderNotifier.ACTION_REJECT, orderId)
                    removeOnMain()
                }
            }
            val accept = text(context, "✓  ACCEPT ORDER", 16f, Color.WHITE, bold = true).apply {
                gravity = Gravity.CENTER
                background = rounded(greenDark, dp(context, 16f).toFloat())
                setOnClickListener {
                    // Open the app FIRST, while this window is still on screen: that is
                    // what lets a background app start an activity at all.
                    launchApp(context, orderId, restaurantId, answered = true)
                    sendAction(context, NewOrderNotifier.ACTION_ACCEPT, orderId)
                    removeOnMain()
                }
            }
            actions.addView(reject, LinearLayout.LayoutParams(0, btnHeight, 1f))
            actions.addView(
                accept,
                LinearLayout.LayoutParams(0, btnHeight, 2f).apply { leftMargin = dp(context, 12f) },
            )
        }
        bodyBox.addView(actions)
        bodyBox.addView(
            text(context, "🛡  High priority order • The customer is notified once you accept.", 12.5f, muted).apply {
                setPadding(0, dp(context, 12f), 0, 0)
            },
        )
        card.addView(bodyBox)

        // Tapping the details opens the order in the app.
        bodyBox.setOnClickListener {
            launchApp(context, orderId, restaurantId, answered = false)
            removeOnMain()
        }

        val container = FrameLayout(context).apply {
            setPadding(dp(context, 12f), 0, dp(context, 12f), 0)
            addView(card)
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
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

        wm.addView(container, params)
        root = container
        showingOrderId = orderId
        Log.i(TAG, "overlay shown for $orderId")

        startCountdown(context, data, countdown)
        fetchDetails(context, orderId)
    }

    private fun statusBarHeight(context: Context): Int {
        val id = context.resources.getIdentifier("status_bar_height", "dimen", "android")
        return if (id > 0) context.resources.getDimensionPixelSize(id) else 0
    }

    private fun startCountdown(context: Context, data: Map<String, String>, view: TextView) {
        // A deadline already in the past means the push was delayed (Doze): still give
        // the full window rather than opening a card that expires immediately.
        var left = (NewOrderNotifier.expiryMillis(data) / 1000).toInt().coerceAtLeast(15)
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

    /**
     * Takes the card down. With [showNext] the next waiting order (if any) comes
     * up right away with its own card and ring, so no order is left without an
     * alert after another one was answered.
     */
    private fun removeOnMain(showNext: Boolean = true) {
        countdownRunnable?.let { main.removeCallbacks(it) }
        countdownRunnable = null
        val v = root
        root = null
        showingOrderId = null
        customerView = null
        itemsView = null
        totalView = null
        headlineView = null
        moreView = null
        if (v != null) {
            try {
                (v.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
            } catch (_: Throwable) {
                // Already detached.
            }
        }
        if (!showNext) return
        val ctx = appContext ?: return
        val next = queue.entries.firstOrNull() ?: return
        queue.remove(next.key)
        try {
            NewOrderRingtone.start(ctx, next.key, NewOrderNotifier.expiryMillis(next.value))
        } catch (_: Throwable) {
        }
        main.post {
            try {
                showOnMain(ctx, next.value)
            } catch (t: Throwable) {
                Log.e(TAG, "next overlay failed", t)
            }
        }
    }

    private fun sendAction(context: Context, action: String, orderId: String) {
        val intent = Intent(context, NewOrderActionReceiver::class.java).apply {
            this.action = action
            putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
        }
        context.sendBroadcast(intent)
    }

    private fun launchApp(context: Context, orderId: String, restaurantId: String?, answered: Boolean) {
        try {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            launch.putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
            if (!restaurantId.isNullOrBlank()) launch.putExtra(NewOrderNotifier.EXTRA_RESTAURANT_ID, restaurantId)
            if (answered) {
                launch.putExtra("orderActionHandled", true)
                launch.putExtra("accepted", true)
            }
            context.startActivity(launch)
        } catch (t: Throwable) {
            Log.w(TAG, "could not open app", t)
        }
    }

    /** Fills in items, customer and total from the order itself. Best effort. */
    private fun fetchDetails(context: Context, orderId: String) {
        Thread {
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.access_token", null)
                if (token.isNullOrBlank()) return@Thread
                val conn = URL("$API_BASE/food/restaurant/orders/$orderId").openConnection() as HttpURLConnection
                conn.setRequestProperty("Authorization", "Bearer $token")
                conn.connectTimeout = 7000
                conn.readTimeout = 7000
                if (conn.responseCode !in 200..299) return@Thread
                val json = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
                val dataObj = json.optJSONObject("data") ?: json
                val order = dataObj.optJSONObject("order") ?: dataObj

                val items = order.optJSONArray("items")
                val lines = mutableListOf<String>()
                if (items != null) {
                    for (i in 0 until items.length()) {
                        val it = items.optJSONObject(i) ?: continue
                        val name = it.optString("name")
                        if (name.isNotBlank()) lines.add("${it.optInt("quantity", 1)} × $name")
                    }
                }
                val total = when {
                    order.has("total") -> order.optDouble("total")
                    order.optJSONObject("pricing") != null -> order.optJSONObject("pricing")!!.optDouble("total")
                    else -> Double.NaN
                }
                val user = order.optJSONObject("userId")
                val customer = order.optString("customerName").ifBlank { user?.optString("name").orEmpty() }
                val method = order.optJSONObject("payment")?.optString("method").orEmpty().lowercase()
                val payment = when {
                    method.isBlank() -> ""
                    method == "cash" || method == "cod" -> "  •  Cash on delivery"
                    else -> "  •  Prepaid"
                }
                val displayId = order.optString("orderId").ifBlank { order.optString("order_id") }

                main.post {
                    if (showingOrderId != orderId) return@post
                    if (customer.isNotBlank()) customerView?.text = customer
                    if (lines.isNotEmpty()) itemsView?.text = lines.take(6).joinToString("\n") +
                        if (lines.size > 6) "\n+ ${lines.size - 6} more" else ""
                    if (!total.isNaN() && total > 0) totalView?.text = "₹%.2f%s".format(total, payment)
                    if (displayId.isNotBlank()) headlineView?.text = "Order #$displayId"
                }
            } catch (t: Throwable) {
                Log.w(TAG, "details fetch failed: ${t.message}")
            }
        }.start()
    }
}
