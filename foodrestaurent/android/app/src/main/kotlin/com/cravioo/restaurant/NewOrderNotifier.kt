package com.cravioo.restaurant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Posts the new-order alert, with Accept and Reject on the notification itself.
 *
 * Everything here runs from Kotlin with no Flutter engine, which is the point. The
 * previous alert was drawn by `flutter_local_notifications` from the Dart background
 * handler, so it only appeared once an engine had been started — and when the app is
 * killed or the phone has been idle, that either happens late or not at all. Posting
 * natively happens the instant FCM delivers, in every app state.
 */
object NewOrderNotifier {

    /**
     * Versioned, and it MUST be bumped to change importance or sound.
     *
     * A channel's importance and sound are fixed at creation: calling
     * createNotificationChannel again on the same id silently ignores both, forever,
     * including across app updates. Only a new id takes effect. Reinstalling to test
     * hides this, which is how it survives review.
     */
    private const val CHANNEL_ID = "new_order_native_v3"
    private const val CHANNEL_NAME = "New order alerts"

    const val ACTION_ACCEPT = "com.cravioo.restaurant.NEW_ORDER_ACCEPT"
    const val ACTION_REJECT = "com.cravioo.restaurant.NEW_ORDER_REJECT"
    const val EXTRA_ORDER_ID = "orderId"
    const val EXTRA_RESTAURANT_ID = "restaurantId"

    /** Keyed on the order so a withdrawal can cancel exactly this alert. */
    fun notificationId(orderId: String?): Int =
        (orderId ?: "new_order").hashCode() and 0x7fffffff

    fun show(context: Context, data: Map<String, String>) {
        val orderId = NewOrderMessagingService.orderIdOf(data) ?: return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        createChannel(context, manager)
        wakeScreen(context)

        val ringMillis = expiryMillis(data)
        val title = data["title"]?.takeIf { it.isNotBlank() } ?: "New order received"
        val rawBody = data["body"]?.takeIf { it.isNotBlank() } ?: buildBody(data)

        // An order for ANOTHER outlet of the same owner. Accept/Reject cannot be
        // answered from here (the session belongs to a different outlet), so the
        // notification names the outlet and just opens it: tapping switches the app
        // to that outlet and shows the order there.
        val restaurantId = data["restaurantId"]?.takeIf { it.isNotBlank() }
        val outletName = data["restaurantName"]?.takeIf { it.isNotBlank() }
        val otherOutlet = isOtherOutlet(context, restaurantId)
        val body = if (otherOutlet && outletName != null && !rawBody.contains(outletName)) {
            "$outletName · $rawBody"
        } else {
            rawBody
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setSound(null) // the looping NewOrderRingtone is the ONLY audio: a channel sound on top of it rang twice
            // CATEGORY_CALL earns call-style ranking and gets through most Do Not
            // Disturb configurations. Not cosmetic: without it the full-screen intent
            // is treated as an ordinary notification.
            .setCategory(NotificationCompat.CATEGORY_CALL)
            // PUBLIC so the buttons are usable straight from the lock screen, which is
            // where this alert most often arrives.
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // Neither swipeable nor auto-dismissed: an order alert must be answered,
            // not brushed away. It is cancelled explicitly on Accept, Reject, the
            // order being taken elsewhere, or expiry.
            .setOngoing(!otherOutlet)
            .setAutoCancel(otherOutlet)
            .setFullScreenIntent(openAppIntent(context, orderId, restaurantId), true)
            .setContentIntent(openAppIntent(context, orderId, restaurantId))
            .setTimeoutAfter(ringMillis + 10_000)

        if (!otherOutlet) {
            builder
                .addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Reject",
                    actionIntent(context, ACTION_REJECT, orderId),
                )
                .addAction(
                    android.R.drawable.ic_menu_send,
                    "Accept",
                    actionIntent(context, ACTION_ACCEPT, orderId),
                )
        }
        val notification: Notification = builder.build()

        try {
            manager.notify(notificationId(orderId), notification)
        } catch (t: Throwable) {
            android.util.Log.e("NewOrderNotifier", "manager.notify failed: $t")
        }

        // After the notification is up, so the restaurant is never left with a sound
        // and nothing on screen explaining it.
        NewOrderRingtone.start(context, orderId, ringMillis)
    }

    /**
     * Whether [restaurantId] is a different outlet from the one the app is signed
     * in as. The app mirrors its active outlet id into SharedPreferences
     * ("restaurant_id", which Flutter's plugin stores as "flutter.restaurant_id")
     * precisely so this can be answered with no engine running. Unknown on either
     * side means "not another outlet": the normal alert is the safe default.
     */
    internal fun isOtherOutlet(context: Context, restaurantId: String?): Boolean {
        if (restaurantId.isNullOrBlank()) return false
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val active = prefs.getString("flutter.restaurant_id", null)
            !active.isNullOrBlank() && active != restaurantId
        } catch (_: Throwable) {
            false
        }
    }

    /** Take the alert down and stop the ring — order taken elsewhere, or cancelled. */
    fun dismiss(context: Context, orderId: String?) {
        NewOrderOverlay.dismiss(orderId)
        NewOrderRingtone.stop(orderId)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            manager.cancel(notificationId(orderId))
        } catch (_: Throwable) {}
    }

    /** Shows an immediate confirmation notification when order is accepted or rejected from notification */
    fun showActionFeedback(context: Context, orderId: String, accepted: Boolean) {
        NewOrderOverlay.dismiss(orderId)
        NewOrderRingtone.stop(orderId)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val feedbackChannelId = "order_feedback_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                feedbackChannelId,
                "Order Action Feedback",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Shows confirmation when an order is accepted or rejected."
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }

        val title = if (accepted) "Order Accepted ✅" else "Order Rejected ❌"
        val body = if (accepted) "Order #$orderId has been accepted and confirmed." else "Order #$orderId has been rejected."

        val notification = NotificationCompat.Builder(context, feedbackChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(context, orderId))
            .build()

        try {
            manager.notify(notificationId(orderId), notification)
        } catch (t: Throwable) {
            android.util.Log.e("NewOrderNotifier", "showActionFeedback failed: $t")
        }
    }

    /**
     * Last-resort alert when the rich one could not be posted. Deliberately minimal —
     * no full-screen intent, no actions — because whatever broke [show] is most likely
     * one of those.
     */
    fun showFallback(context: Context, data: Map<String, String>) {
        val orderId = NewOrderMessagingService.orderIdOf(data) ?: return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel(context, manager)

        try {
            manager.notify(
                notificationId(orderId),
                NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle(data["title"]?.takeIf { it.isNotBlank() } ?: "New order received")
                    .setContentText(buildBody(data))
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setAutoCancel(true)
                    .setContentIntent(openAppIntent(context, orderId))
                    .build(),
            )
        } catch (t: Throwable) {
            android.util.Log.e("NewOrderNotifier", "showFallback manager.notify failed: $t")
        }

        // The rich alert failed, so this is all there is. Being heard matters more
        // here than in the normal path, not less.
        NewOrderRingtone.start(context, orderId, expiryMillis(data))
    }

    private fun actionIntent(context: Context, action: String, orderId: String): PendingIntent {
        val intent = Intent(context, NewOrderActionReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        return PendingIntent.getBroadcast(
            context,
            // Distinct per action AND per order, or Android reuses one PendingIntent
            // and Reject silently carries Accept's extras.
            (action + orderId).hashCode() and 0x7fffffff,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openAppIntent(
        context: Context,
        orderId: String,
        restaurantId: String? = null,
    ): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(EXTRA_ORDER_ID, orderId)
                if (!restaurantId.isNullOrBlank()) putExtra(EXTRA_RESTAURANT_ID, restaurantId)
            }
            ?: Intent()
        return PendingIntent.getActivity(
            context,
            notificationId(orderId),
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * The channel id the BACKEND names on restaurant pushes
     * (`android.notification.channel_id` in firebase.service.js).
     *
     * When such a push arrives with the app closed, Android draws it itself - no
     * Kotlin or Dart runs - into whatever channel the id names. If the app never
     * created that channel, Android silently drops the message into a default
     * low-priority one: no sound, no heads-up, easy to miss entirely. Creating it
     * here, loud, means that path still rings and pops up. It is the fallback; the
     * data-only push drives the full alert (buttons, overlay) through
     * [NewOrderMessagingService].
     */
    const val BACKEND_ORDERS_CHANNEL_ID = "orders_channel"

    /** Creates every channel an order push can land in. Call once at app start. */
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            createChannel(context, manager)
            if (manager.getNotificationChannel(BACKEND_ORDERS_CHANNEL_ID) != null) return

            // The backend names this channel on EVERY restaurant push that carries a
            // notification block (order updates, admin messages, tests...), not only
            // new orders. So it uses the phone's normal notification sound: giving it
            // the order ringtone made every notification ring. The ringtone belongs to
            // the native new-order alert alone (NewOrderRingtone).
            val channel = NotificationChannel(
                BACKEND_ORDERS_CHANNEL_ID,
                "Order notifications",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Order updates and messages."
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
            }
            manager.createNotificationChannel(channel)
        } catch (t: Throwable) {
            android.util.Log.w("NewOrderNotifier", "ensureChannels failed: $t")
        }
    }

    private fun createChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return


        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alerts for new orders. Requires an immediate accept or reject."
            // Silent on purpose. NewOrderRingtone loops the ring (and vibrates) itself;
            // a channel sound plays once on top of it, which is the "rings twice" bug.
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * Screen on, briefly, so a full-screen intent is taken rather than downgraded.
     *
     * A full-screen intent only launches straight through when the screen is off or
     * locked; on an awake device Android turns it into an ordinary heads-up. Released
     * on a timeout rather than by hand, so a missed release can never pin the screen.
     */
    private fun wakeScreen(context: Context) {
        try {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (power.isInteractive) return

            @Suppress("DEPRECATION")
            val lock = power.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "cravioo_restaurant:new_order",
            )
            lock.acquire(10_000L)
        } catch (_: Throwable) {
            // Costs the straight-to-screen launch on a sleeping device, not the alert.
        }
    }

    internal fun expiryMillis(data: Map<String, String>): Long {
        val seconds = (data["expiresInSeconds"] ?: data["acceptTimeoutSeconds"])
            ?.toLongOrNull()
            ?.coerceIn(15, 300)
            ?: 60
        return seconds * 1000
    }

    private fun buildBody(data: Map<String, String>): String {
        val parts = listOfNotNull(
            data["customerName"]?.takeIf { it.isNotBlank() }?.let { "Customer: $it" },
            data["itemCount"]?.takeIf { it.isNotBlank() }?.let { "$it item(s)" },
            (data["total"] ?: data["amount"])?.takeIf { it.isNotBlank() }?.let { "Total: Rs.$it" },
        )
        return if (parts.isEmpty()) "Tap to view the order" else parts.joinToString(" · ")
    }
}
