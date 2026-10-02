package com.cravioo.restaurant

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Rings until the restaurant accepts or rejects.
 *
 * A notification channel's sound plays exactly ONCE and cannot be told to repeat.
 * That is the whole reason this exists: a single short chirp from a phone that is
 * locked, or face-down on a counter in a noisy kitchen, is missed, and the order sits
 * unanswered until it expires. This owns the audio instead so it can loop, and stops
 * the moment there is a decision.
 *
 * Process-wide rather than tied to any one screen: the alert must keep ringing while
 * the app is closed, and must survive whatever the restaurant is doing on the phone.
 */
object NewOrderRingtone {

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var focusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null

    /** The order this ring belongs to, so a stale stop cannot silence a newer one. */
    private var ringingFor: String? = null

    private val handler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stop(null) }

    /**
     * Hard ceiling, independent of every other stop path.
     *
     * Every other stop depends on something happening — a button press, the order
     * being taken elsewhere, the app being opened. If any of those is missed, an
     * unbounded loop would ring until the process died. This guarantees silence.
     */
    private const val MAX_RING_MS = 120_000L

    private const val TAG = "NewOrderRingtone"

    @Synchronized
    fun start(context: Context, orderId: String, ringMillis: Long) {
        // Already ringing for this same order: leave it alone. Both the notifier and
        // the app can call this, and restarting the track would make it stutter back
        // to the beginning.
        if (ringingFor == orderId && player != null) return

        // A DIFFERENT order replaces the current ring rather than layering a second
        // player on top of it — two ringtones at once is worse than either.
        stopInternal()

        ringingFor = orderId
        Log.i(TAG, "starting ring for $orderId (${ringMillis}ms)")

        val attributes = AudioAttributes.Builder()
            // Ringtone usage, not notification: it follows RING volume, which stays
            // up, rather than notification volume, which is often turned down.
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        requestAudioFocus(context, attributes)

        try {
            val afd = context.resources.openRawResourceFd(R.raw.tujh_bin)
            player = MediaPlayer().apply {
                setAudioAttributes(attributes)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                isLooping = true
                setOnPreparedListener {
                    Log.i(TAG, "ringtone prepared, starting loop")
                    it.start()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "ringtone error what=$what extra=$extra")
                    true
                }
                prepareAsync()
            }
        } catch (t: Throwable) {
            Log.e(TAG, "ringtone failed with raw descriptor, falling back to MediaPlayer.create", t)
            try {
                player = MediaPlayer.create(context, R.raw.tujh_bin)?.apply {
                    setAudioAttributes(attributes)
                    isLooping = true
                    start()
                }
            } catch (e2: Throwable) {
                Log.e(TAG, "MediaPlayer.create also failed", e2)
                player = null
            }
        }

        startVibration(context)

        handler.removeCallbacks(stopRunnable)
        handler.postDelayed(stopRunnable, ringMillis.coerceIn(5_000L, MAX_RING_MS))
    }

    /**
     * Stop the ring for [orderId], or unconditionally when it is null.
     *
     * Scoped by id so a late stop for an order that already expired cannot cut off the
     * ring of the order that replaced it.
     */
    @Synchronized
    fun stop(orderId: String?) {
        if (orderId != null && ringingFor != null && ringingFor != orderId) return
        stopInternal()
    }

    @Synchronized
    fun isRinging(): Boolean = player != null

    private fun stopInternal() {
        handler.removeCallbacks(stopRunnable)
        ringingFor = null

        try {
            player?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Throwable) {
            // Already released, or never got as far as being prepared.
        }
        player = null

        try {
            vibrator?.cancel()
        } catch (_: Throwable) {
        }
        vibrator = null

        abandonAudioFocus()
    }

    private fun startVibration(context: Context) {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager =
                    context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 600, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // repeat = 0: restart the pattern from index 0 forever, until cancel().
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (_: Throwable) {
            vibrator = null
        }
    }

    /**
     * Duck whatever else is playing. A phone playing music or a video in the shop
     * would otherwise mix the alert underneath it, which is how it gets missed.
     */
    private fun requestAudioFocus(context: Context, attributes: AudioAttributes) {
        try {
            val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager = manager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest
                    .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(attributes)
                    .build()
                focusRequest = request
                manager.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                manager.requestAudioFocus(
                    null,
                    AudioManager.STREAM_RING,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
                )
            }
        } catch (_: Throwable) {
            audioManager = null
        }
    }

    private fun abandonAudioFocus() {
        try {
            val manager = audioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { manager.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                manager.abandonAudioFocus(null)
            }
        } catch (_: Throwable) {
        }
        focusRequest = null
        audioManager = null
    }
}
