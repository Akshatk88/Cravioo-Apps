package com.cravioo.restaurant

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * The incoming-order card, drawn directly by the window manager.
 *
 * Runs in the app's own process off the FCM `RemoteMessage`, so there is no Flutter
 * engine and no cross-isolate handoff involved in getting the order onto the screen.
 * An overlay rather than a custom notification because Android caps notification
 * layouts at roughly 256dp.
 *
 * Accept and Reject are NOT handled here: they are forwarded to
 * [NewOrderActionReceiver], the one place that already turns a button press into a
 * silenced alert, a parked decision for Dart and (for Reject) a background request.
 * The overlay and the notification buttons therefore cannot drift apart.
 */
object NewOrderOverlay {
    private const val TAG = "NewOrderOverlay"

    /** Matches NewOrderNotifier's own default; the server's window overrides it. */
    private const val DEFAULT_WINDOW_SECONDS = 60L

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newCachedThreadPool()

    private var view: View? = null
    private var windowManager: WindowManager? = null
    private var timer: CountDownTimer? = null
    private var player: MediaPlayer? = null
    private var alarmWatchdog: Runnable? = null

    /**
     * The order currently on screen — the de-duplication key. The same order
     * arriving again rebinds in place instead of stacking a window or restarting
     * the ringtone.
     */
    private var showingOrderId: String? = null

    fun canDrawOverlay(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /** Returns whether the card will be on screen; false means post a notification. */
    @SuppressLint("InflateParams")
    fun show(context: Context, data: Map<String, String>): Boolean {
        val orderId = orderIdOf(data)
        if (orderId.isEmpty()) {
            Log.w(TAG, "[NEW_ORDER] push carries no order id — nothing to show")
            return false
        }
        if (!canDrawOverlay(context)) {
            Log.w(TAG, "[NEW_ORDER] 'Display over other apps' not granted — skipping overlay")
            return false
        }

        main.post {
            try {
                if (showingOrderId == orderId && view != null) {
                    Log.d(TAG, "[NEW_ORDER] $orderId already on screen — refreshing in place")
                    view?.let { bind(context, it, data, orderId) }
                    return@post
                }
                dismissInternal()
                showingOrderId = orderId

                val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val card = LayoutInflater.from(context).inflate(R.layout.overlay_new_order, null)
                bind(context, card, data, orderId)

                wm.addView(card, layoutParams())
                windowManager = wm
                view = card

                startAlarm(context, data.remainingSeconds())
                startCountdown(data)
                Log.d(TAG, "[NEW_ORDER_NOTIFICATION] overlay shown for $orderId")
                enrichFromApi(context, data, orderId)
            } catch (e: Exception) {
                // A window that fails to attach must not take the process with it.
                Log.e(TAG, "[NEW_ORDER] overlay failed: $e")
                showingOrderId = null
            }
        }
        return true
    }

    /** Called when the order is answered, cancelled or otherwise withdrawn. */
    fun dismissFor(orderId: String?) = main.post {
        if (showingOrderId == null || orderId == null || showingOrderId == orderId) {
            dismissInternal()
        }
    }

    fun dismiss() = main.post { dismissInternal() }

    // ------------------------------------------------------------------ bind

    private fun bind(
        context: Context,
        root: View,
        data: Map<String, String>,
        orderId: String,
    ) {
        val display = displayId(data, orderId)
        val total = data.firstNonZero(*TOTAL_KEYS)

        root.html(
            R.id.headline,
            buildString {
                append("Order ").append(display)
                if (total.isNotEmpty()) append(" • <b>₹").append(total).append("</b>")
            },
        )

        root.text(R.id.customer_name, data.firstNonEmpty("customerName").ifEmpty { "Customer" })
        root.text(R.id.customer_address, data.firstNonEmpty("address", "customerAddress"))

        val itemsList = data.firstNonEmpty("itemsList")
        val count = data.firstNonEmpty("itemCount", "itemsCount", "totalItems")
            .ifEmpty { runCatching { JSONArray(data["items"]).length().toString() }.getOrDefault("") }
            .let { if (it == "0") "" else it }
        root.text(
            R.id.items_count,
            if (count.isEmpty()) "Items" else "$count ${if (count == "1") "item" else "items"}",
        )
        root.findViewById<TextView>(R.id.items_list)?.apply {
            text = itemsList
            visibility = if (itemsList.isEmpty()) View.GONE else View.VISIBLE
        }

        root.text(R.id.order_value, if (total.isEmpty()) "—" else "₹$total")

        val method = data.firstNonEmpty("paymentMethod").lowercase()
        val cash = method == "cash" || method == "cod"
        root.findViewById<TextView>(R.id.payment_chip)?.apply {
            if (method.isEmpty()) {
                visibility = View.GONE
            } else {
                visibility = View.VISIBLE
                text = if (cash) "Cash" else "Prepaid"
                setTextColor(if (cash) 0xFFD97706.toInt() else 0xFF16A34A.toInt())
            }
        }

        root.findViewById<View>(R.id.btn_accept)?.setOnClickListener {
            Log.d(TAG, "[NEW_ORDER_NOTIFICATION] ACCEPT tapped for $orderId")
            answer(context, NewOrderNotifier.ACTION_ACCEPT, orderId)
        }
        root.findViewById<View>(R.id.btn_reject)?.setOnClickListener {
            Log.d(TAG, "[NEW_ORDER_NOTIFICATION] REJECT tapped for $orderId")
            answer(context, NewOrderNotifier.ACTION_REJECT, orderId)
        }
        root.findViewById<View>(R.id.overlay_root)?.setOnClickListener {
            stopAlarm()
            openApp(context, orderId)
            dismissInternal()
        }
    }

    /** Hands the decision to the same receiver the notification buttons use. */
    private fun answer(context: Context, action: String, orderId: String) {
        stopAlarm()
        context.sendBroadcast(
            Intent(context, NewOrderActionReceiver::class.java)
                .setAction(action)
                .putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
        )
        dismissInternal()
    }

    // -------------------------------------------------------------- enrichment

    /**
     * Fills in what the push does not carry, from the order-details endpoint, then
     * rebinds the text. The card is already up: this only improves it, and any
     * failure (no token, expired token, offline) leaves the push values as they were.
     */
    private fun enrichFromApi(context: Context, data: Map<String, String>, orderId: String) {
        val missing = data.firstNonZero(*TOTAL_KEYS).isEmpty() ||
            data.firstNonEmpty("customerName").isEmpty() ||
            data.firstNonEmpty("address", "customerAddress").isEmpty() ||
            data.firstNonEmpty("itemsList", "itemCount", "itemsCount").isEmpty() ||
            data.firstNonEmpty("orderDisplayId", "orderNumber", "orderCode", "order_id").isEmpty()
        if (!missing) return

        io.execute {
            val extra = fetchOrderDetails(context, orderId) ?: return@execute
            val merged = HashMap(data)
            // Push values win where they exist; the API only fills gaps.
            extra.forEach { (k, v) -> if (v.isNotBlank() && merged[k].isNullOrBlank()) merged[k] = v }
            main.post {
                if (showingOrderId != orderId) return@post
                view?.let { bind(context, it, merged, orderId) }
            }
        }
    }

    private fun fetchOrderDetails(context: Context, orderId: String): Map<String, String>? {
        return try {
            val token = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.access_token", null)
            if (token.isNullOrBlank()) {
                Log.w(TAG, "[NEW_ORDER] no stored token — card keeps the push values")
                return null
            }
            val conn = URL("https://cravioo.in/api/v1/food/restaurant/orders/$orderId")
                .openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 4000
            conn.readTimeout = 4000
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Accept", "application/json")
            if (conn.responseCode !in 200..299) {
                Log.w(TAG, "[NEW_ORDER] order details HTTP ${conn.responseCode}")
                return null
            }
            val json = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val root = json.optJSONObject("data") ?: json
            val order = root.optJSONObject("order") ?: root

            val out = HashMap<String, String>()
            order.optString("order_id").takeIf { it.isNotBlank() }?.let { out["orderCode"] = it }
            order.optJSONObject("pricing")?.optDouble("total")
                ?.takeIf { !it.isNaN() && it > 0 }
                ?.let { out["total"] = formatMoney(it) }
            order.optJSONArray("items")?.let { items ->
                out["itemCount"] = items.length().toString()
                out["itemsList"] = (0 until items.length()).mapNotNull { i ->
                    val item = items.optJSONObject(i) ?: return@mapNotNull null
                    val name = item.optString("name").takeIf { it.isNotBlank() } ?: return@mapNotNull null
                    "${item.optInt("quantity", 1)} × $name"
                }.joinToString("\n")
            }
            val user = order.optJSONObject("userId")
            (order.optString("customerName").takeIf { it.isNotBlank() }
                ?: user?.optString("name")?.takeIf { it.isNotBlank() })
                ?.let { out["customerName"] = it }
            order.optJSONObject("deliveryAddress")?.let { a ->
                listOf("street", "additionalDetails", "city")
                    .map { a.optString(it) }.filter { it.isNotBlank() }.distinct()
                    .joinToString(", ").takeIf { it.isNotEmpty() }
                    ?.let { out["address"] = it }
            }
            order.optJSONObject("payment")?.optString("method")
                ?.takeIf { it.isNotBlank() }?.let { out["paymentMethod"] = it }
            Log.d(TAG, "[NEW_ORDER] enriched $orderId from API: ${out.keys}")
            out
        } catch (e: Exception) {
            Log.w(TAG, "[NEW_ORDER] order details failed: $e")
            null
        }
    }

    private fun formatMoney(v: Double): String =
        if (v % 1.0 == 0.0) v.toInt().toString() else String.format("%.2f", v)

    // -------------------------------------------------------------- lifecycle

    private fun layoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            // NOT_FOCUSABLE keeps the app underneath usable; the card still gets its
            // own taps. WRAP_CONTENT means everything below it belongs to that app.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
            y = 0
        }
    }

    private fun startCountdown(data: Map<String, String>) {
        val seconds = data.remainingSeconds()
        val countdown = view?.findViewById<TextView>(R.id.countdown)
        timer?.cancel()
        timer = object : CountDownTimer(seconds * 1000, 1000) {
            override fun onTick(msLeft: Long) {
                val left = (msLeft / 1000).toInt()
                val colour = if (left <= seconds * 0.3) "#E04444" else "#16A34A"
                countdown?.setHtml("🕐  Accept within <font color='$colour'><b>$left</b></font> sec")
            }

            override fun onFinish() {
                Log.d(TAG, "[NEW_ORDER] offer expired on screen")
                stopAlarm()
                dismissInternal()
            }
        }.start()
    }

    /**
     * Server-driven when the push says so. A deadline already in the past means the
     * push sat in Doze, so the full window is used — opening at zero is worse.
     */
    private fun Map<String, String>.remainingSeconds(): Long {
        this["acceptanceDeadlineAt"]?.takeIf { it.isNotBlank() }?.let { raw ->
            runCatching {
                val deadline = java.time.Instant.parse(raw).toEpochMilli()
                val left = (deadline - System.currentTimeMillis()) / 1000
                if (left > 0) return left
            }
        }
        listOf("expiresInSeconds", "acceptTimeoutSeconds").forEach { key ->
            this[key]?.toLongOrNull()?.takeIf { it > 0 }?.let { return it.coerceIn(15, 300) }
        }
        return DEFAULT_WINDOW_SECONDS
    }

    private fun startAlarm(context: Context, windowSeconds: Long) {
        stopAlarm()
        try {
            // Attributes go to create(): setAudioAttributes is ignored after prepare.
            // Alarm usage keeps it audible with media volume down.
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            player = MediaPlayer.create(
                context,
                R.raw.tujh_bin,
                attributes,
                AudioManager.AUDIO_SESSION_ID_GENERATE,
            )?.apply {
                setOnErrorListener { _, what, extra ->
                    Log.w(TAG, "ringtone error $what/$extra — releasing")
                    stopAlarm()
                    true
                }
                isLooping = true
                start()
            }
            Log.d(TAG, "[NEW_ORDER] ringtone started")
        } catch (e: Exception) {
            Log.w(TAG, "ringtone failed: $e")
        }

        // Backstop: bounds the ring if an exit path is ever missed.
        alarmWatchdog?.let { main.removeCallbacks(it) }
        val watchdog = Runnable {
            if (player != null) {
                Log.w(TAG, "[NEW_ORDER] alarm watchdog fired — forcing silence")
                stopAlarm()
            }
        }
        alarmWatchdog = watchdog
        main.postDelayed(watchdog, (windowSeconds + 10) * 1000)

        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            // Bounded, never repeating forever.
            val pattern = longArrayOf(0, 400, 300, 400, 900, 400, 300, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            Log.w(TAG, "vibration failed: $e")
        }
    }

    /**
     * Silences the ringtone. Safe to call any number of times, from any state. The
     * field is cleared first so a throwing stop() cannot leave an unreachable,
     * still-looping player behind.
     */
    private fun stopAlarm() {
        alarmWatchdog?.let { main.removeCallbacks(it) }
        alarmWatchdog = null

        val current = player ?: return
        player = null
        try {
            current.stop()
        } catch (e: Exception) {
            Log.w(TAG, "ringtone stop failed, releasing anyway: $e")
        }
        try {
            current.release()
        } catch (e: Exception) {
            Log.w(TAG, "ringtone release failed: $e")
        }
        Log.d(TAG, "[NEW_ORDER] ringtone stopped")
    }

    private fun dismissInternal() {
        timer?.cancel()
        timer = null
        stopAlarm()
        val current = view
        val wm = windowManager
        view = null
        windowManager = null
        showingOrderId = null
        if (current != null && wm != null) {
            try {
                wm.removeView(current)
            } catch (_: Exception) {
                // Already detached — nothing to undo.
            }
        }
    }

    /**
     * Opens the app on the tapped order. An EXPLICIT intent with CLEAR_TOP +
     * SINGLE_TOP: a bare launcher intent against an existing task is delivered as a
     * plain resume and the extras are dropped.
     */
    private fun openApp(context: Context, orderId: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(NewOrderNotifier.EXTRA_ORDER_ID, orderId)
        }
        context.startActivity(intent)
    }

    /** The order's total as the push may name it — the backend has used several. */
    val TOTAL_KEYS = arrayOf(
        "total", "orderValue", "orderTotal", "totalAmount", "grandTotal", "orderAmount", "amount",
    )

    fun orderIdOf(data: Map<String, String>): String =
        data.firstNonEmpty("orderMongoId", "_id", "orderId", "id", "order_id")

    /**
     * The readable order code. `orderId` is the readable code on some pushes and the
     * Mongo id on others, so it only counts when it does not look like one.
     */
    fun displayId(data: Map<String, String>, orderId: String): String {
        val readable = data.firstNonEmpty("orderDisplayId", "orderNumber", "orderCode", "order_id")
        if (readable.isNotEmpty()) return readable
        val code = data["orderId"]?.trim().orEmpty()
        if (code.isNotEmpty() && !code.matches(Regex("^[0-9a-fA-F]{24}$"))) return code
        return "#" + orderId.takeLast(6).uppercase()
    }
}

private fun View.text(id: Int, value: String) {
    findViewById<TextView>(id)?.text = value
}

private fun View.html(id: Int, value: String) {
    findViewById<TextView>(id)?.setHtml(value)
}

private fun TextView.setHtml(value: String) {
    text = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        android.text.Html.fromHtml(value, android.text.Html.FROM_HTML_MODE_LEGACY)
    } else {
        @Suppress("DEPRECATION")
        android.text.Html.fromHtml(value)
    }
}

private fun Map<String, String>.firstNonEmpty(vararg keys: String): String {
    for (key in keys) {
        val value = this[key]?.trim()
        if (!value.isNullOrEmpty()) return value
    }
    return ""
}

/** Like [firstNonEmpty] but also skips values that parse to zero. */
private fun Map<String, String>.firstNonZero(vararg keys: String): String {
    for (key in keys) {
        val value = this[key]?.trim() ?: continue
        if (value.isNotEmpty() && (value.toDoubleOrNull() ?: 0.0) > 0.0) return value
    }
    return ""
}
