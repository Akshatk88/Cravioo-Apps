package com.cravioo.delivery

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Rings until the delivery partner accepts or rejects.
 *
 * Owned in Kotlin process-wide so the alert rings reliably when the app is
 * closed or screen is locked, and stops the moment there is a decision.
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

    private const val MAX_RING_MS = 90_000L
    private const val TAG = "DeliveryOrderRingtone"

    @Synchronized
    fun start(context: Context, orderId: String, ringMillis: Long) {
        if (ringingFor == orderId && player != null) return

        stopInternal()

        ringingFor = orderId
        Log.i(TAG, "starting ring for $orderId (${ringMillis}ms)")

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        requestAudioFocus(context, attributes)

        // Try tujh_bin1 first, fallback to neworder
        var started = false
        val soundResIds = listOf(
            context.resources.getIdentifier("tujh_bin1", "raw", context.packageName),
            context.resources.getIdentifier("neworder", "raw", context.packageName)
        ).filter { it != 0 }

        for (resId in soundResIds) {
            try {
                val afd = context.resources.openRawResourceFd(resId)
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
                started = true
                break
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to load raw resource fd $resId: $t")
                try {
                    player = MediaPlayer.create(context, resId)?.apply {
                        setAudioAttributes(attributes)
                        isLooping = true
                        start()
                    }
                    if (player != null) {
                        started = true
                        break
                    }
                } catch (t2: Throwable) {
                    Log.w(TAG, "Failed MediaPlayer.create for $resId: $t2")
                }
            }
        }

        startVibration(context)

        handler.removeCallbacks(stopRunnable)
        val ceiling = ringMillis.coerceIn(5_000L, MAX_RING_MS)
        handler.postDelayed(stopRunnable, ceiling)
    }

    @Synchronized
    fun stop(orderId: String?) {
        if (orderId != null && ringingFor != null && ringingFor != orderId) {
            Log.i(TAG, "ignoring stop for $orderId — current ring belongs to $ringingFor")
            return
        }
        stopInternal()
    }

    private fun stopInternal() {
        handler.removeCallbacks(stopRunnable)
        ringingFor = null

        try {
            player?.apply {
                if (isPlaying) stop()
                reset()
                release()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "error releasing player", t)
        } finally {
            player = null
        }

        try {
            vibrator?.cancel()
        } catch (_: Throwable) {
        } finally {
            vibrator = null
        }

        abandonAudioFocus()
    }

    private fun startVibration(context: Context) {
        try {
            val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            } ?: return

            vibrator = v
            val pattern = longArrayOf(0, 1000, 500, 1000, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(pattern, 0)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "vibration failed", t)
        }
    }

    private fun requestAudioFocus(context: Context, attributes: AudioAttributes) {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            audioManager = am

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(attributes)
                    .setOnAudioFocusChangeListener { focus ->
                        if (focus == AudioManager.AUDIOFOCUS_LOSS) stop(null)
                    }
                    .build()
                focusRequest = request
                am.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    { focus -> if (focus == AudioManager.AUDIOFOCUS_LOSS) stop(null) },
                    AudioManager.STREAM_RING,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
                )
            }
        } catch (t: Throwable) {
            Log.w(TAG, "audio focus request failed", t)
        }
    }

    private fun abandonAudioFocus() {
        try {
            val am = audioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { am.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)
            }
        } catch (_: Throwable) {
        } finally {
            focusRequest = null
            audioManager = null
        }
    }
}
