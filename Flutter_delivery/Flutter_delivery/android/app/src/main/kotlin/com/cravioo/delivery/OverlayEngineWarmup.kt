package com.cravioo.delivery

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Makes sure the Flutter engine that draws the new-order overlay exists.
 *
 * flutter_overlay_window only creates that engine (entrypoint `overlayMain`,
 * cache key "myCachedEngine") in onAttachedToActivity, i.e. once MainActivity
 * has been opened in this process. When an order push starts the app from a
 * killed state there is no activity, the engine is never created, and
 * OverlayService crashes on the missing engine, so the rider got only a plain
 * notification instead of the overlay. Creating it here, as soon as the push
 * lands, lets the Dart background handler's showOverlay() work.
 */
object OverlayEngineWarmup {

    private const val TAG = "OverlayEngineWarmup"

    /** Must match flutter_overlay_window's OverlayConstants.CACHED_TAG. */
    private const val CACHED_TAG = "myCachedEngine"

    fun ensure(context: Context) {
        val app = context.applicationContext
        val main = Handler(Looper.getMainLooper())
        main.post {
            try {
                if (FlutterEngineCache.getInstance().get(CACHED_TAG) != null) return@post
                val loader = FlutterInjector.instance().flutterLoader()
                if (!loader.initialized()) {
                    loader.startInitialization(app)
                    loader.ensureInitializationComplete(app, null)
                }
                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "overlayMain",
                )
                val engine = FlutterEngineGroup(app).createAndRunEngine(app, entrypoint)
                FlutterEngineCache.getInstance().put(CACHED_TAG, engine)
                Log.i(TAG, "overlay engine created (app was not opened in this process)")
            } catch (t: Throwable) {
                Log.w(TAG, "could not create overlay engine", t)
            }
        }
    }
}
