package com.cravioo.delivery

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
 * Posts the incoming delivery order alert with fullScreenIntent and Accept/Reject buttons.
 */
object NewOrderNotifier {

    const val CHANNEL_ID = "incoming_orders_channel_v6"
    private const val CHANNEL_NAME = "Incoming Orders"

    const val ACTION_ACCEPT = "com.cravioo.delivery.NEW_ORDER_ACCEPT"
    const val ACTION_REJECT = "com.cravioo.delivery.NEW_ORDER_REJECT"
    const val EXTRA_ORDER_ID = "orderId"

    fun notificationId(orderId: String?): Int =
        (orderId ?: "new_delivery_order").hashCode() and 0x7fffffff

    private fun getSmallIcon(context: Context): Int {
        val resId = context.resources.getIdentifier("launcher_icon", "mipmap", context.packageName)
        if (resId != 0) return resId
        val icId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        if (icId != 0) return icId
        return if (context.applicationInfo.icon != 0) context.applicationInfo.icon else android.R.drawable.ic_dialog_info
    }

    fun show(context: Context, data: Map<String, String>) {
        val orderId = NewOrderMessagingService.orderIdOf(data) ?: return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        createChannel(context, manager)
        wakeScreen(context)

        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/tujh_bin1")
        val ringMillis = expiryMillis(data)

        val restaurant = data["restaurantName"]?.takeIf { it.isNotBlank() } ?: "New Order"
        val title = data["title"]?.takeIf { it.isNotBlank() } ?: "New Delivery Order Available"
        val body = data["body"]?.takeIf { it.isNotBlank() } ?: buildBody(data)
        val icon = getSmallIcon(context)

        val notification: Notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setSound(soundUri)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(openAppIntent(context, orderId), true)
            .setContentIntent(openAppIntent(context, orderId))
            .addAction(
                0,
                "Reject",
                actionIntent(context, ACTION_REJECT, orderId),
            )
            .addAction(
                0,
                "Accept",
                actionIntent(context, ACTION_ACCEPT, orderId),
            )
            .setTimeoutAfter(ringMillis + 10_000)
            .build()

        try {
            manager.notify(notificationId(orderId), notification)
        } catch (t: Throwable) {
            android.util.Log.e("NewOrderNotifier", "manager.notify failed: $t")
        }

        NewOrderRingtone.start(context, orderId, ringMillis)
    }

    fun showFallback(context: Context, data: Map<String, String>) {
        val orderId = NewOrderMessagingService.orderIdOf(data) ?: return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel(context, manager)

        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/tujh_bin1")
        val icon = getSmallIcon(context)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(data["restaurantName"]?.takeIf { it.isNotBlank() } ?: "New Delivery Order")
            .setContentText("Tap to view incoming order")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setSound(soundUri)
            .setAutoCancel(true)
            .setContentIntent(openAppIntent(context, orderId))
            .build()
        try {
            manager.notify(notificationId(orderId), notification)
        } catch (t: Throwable) {
            android.util.Log.e("NewOrderNotifier", "showFallback manager.notify failed: $t")
        }
    }

    fun dismiss(context: Context, orderId: String?) {
        NewOrderRingtone.stop(orderId)
        if (orderId != null) {
            try {
                val manager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.cancel(notificationId(orderId))
            } catch (_: Throwable) {
            }
        }
    }

    fun showActionFeedback(context: Context, orderId: String, accepted: Boolean) {
        NewOrderRingtone.stop(orderId)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val feedbackChannelId = "delivery_action_feedback_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                feedbackChannelId,
                "Delivery Action Feedback",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Shows confirmation when delivery order is accepted or rejected."
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }

        val title = if (accepted) "Order Accepted ✅" else "Order Rejected ❌"
        val body = if (accepted) "Delivery order #$orderId has been accepted." else "Delivery order #$orderId was rejected."
        val icon = getSmallIcon(context)

        val notification = NotificationCompat.Builder(context, feedbackChannelId)
            .setSmallIcon(icon)
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

    private fun createChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val soundUri = Uri.parse("android.resource://${context.packageName}/raw/tujh_bin1")
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .build()

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Full-screen incoming order alerts that require immediate action"
            setSound(soundUri, audioAttributes)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 400, 800)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
            enableLights(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun wakeScreen(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "cravioo:delivery_new_order_wake",
            )
            wakeLock.acquire(10_000L)
        } catch (t: Throwable) {
            android.util.Log.w("NewOrderNotifier", "failed to acquire screen wake lock", t)
        }
    }

    private fun buildBody(data: Map<String, String>): String {
        val pickup = data["pickupAddress"] ?: data["restaurantAddress"] ?: "Restaurant"
        val drop = data["dropAddress"] ?: data["customerAddress"] ?: "Customer"
        val price = data["price"] ?: data["riderEarning"] ?: data["earnings"] ?: ""
        val dist = data["distance"] ?: data["tripDistanceKm"] ?: ""
        val parts = mutableListOf<String>()
        if (pickup.isNotBlank()) parts.add("From: $pickup")
        if (drop.isNotBlank()) parts.add("To: $drop")
        val meta = mutableListOf<String>()
        if (price.isNotBlank()) meta.add("Earnings: ₹$price")
        if (dist.isNotBlank()) meta.add("Dist: ${dist}km")
        if (meta.isNotEmpty()) parts.add(meta.joinToString(" | "))
        return if (parts.isNotEmpty()) parts.joinToString("\n") else "Tap to view incoming order"
    }

    private fun expiryMillis(data: Map<String, String>): Long {
        val seconds = data["offerTimeoutSeconds"]?.toLongOrNull()
            ?: data["timeout"]?.toLongOrNull()
            ?: 45L
        return (seconds * 1000L).coerceIn(10_000L, 90_000L)
    }

    private fun openAppIntent(context: Context, orderId: String): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ORDER_ID, orderId)
        } ?: Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getActivity(context, notificationId(orderId), intent, flags)
    }

    private fun actionIntent(context: Context, action: String, orderId: String): PendingIntent {
        val intent = Intent(context, NewOrderActionReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_ORDER_ID, orderId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(
            context,
            notificationId("$orderId:$action"),
            intent,
            flags,
        )
    }
}
