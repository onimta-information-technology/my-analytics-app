package com.app.ballys_reservation

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/// Keeps the Flutter engine — and with it the LiveKit room — alive while a
/// call is on, so swiping the app out of recents doesn't cut the call.
///
/// By default the engine belongs to [MainActivity] and dies with it. Here it
/// lives in [FlutterEngineCache] instead, and is only thrown away once the
/// Activity is gone *and* no call is active. flutter_callkit_incoming's
/// ongoing-call foreground service keeps the process itself running meanwhile.
object CallKeepAlive {
    const val ENGINE_ID = "main_engine"
    private const val CHANNEL = "call_keep_alive"

    /// Long enough for the hang-up request that follows the end of a call to
    /// go out before the engine running it is torn down.
    private const val RELEASE_DELAY_MS = 10_000L

    private var callActive = false
    private var activityAlive = false
    private val handler = Handler(Looper.getMainLooper())
    private val releaseIfIdle = Runnable {
        if (callActive || activityAlive) return@Runnable
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.destroy()
        FlutterEngineCache.getInstance().remove(ENGINE_ID)
    }

    /// The running engine, or a fresh one started the way the Activity would
    /// have started it (including a deep link's initial route).
    fun obtainEngine(context: Context, intent: Intent?): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val engine = FlutterEngine(context.applicationContext)
        intent?.data?.let { uri ->
            val route = buildString {
                append(uri.path?.takeIf { it.isNotEmpty() } ?: "/")
                uri.query?.takeIf { it.isNotEmpty() }?.let { append('?').append(it) }
                uri.fragment?.takeIf { it.isNotEmpty() }?.let { append('#').append(it) }
            }
            engine.navigationChannel.setInitialRoute(route)
        }
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    fun onActivityCreated() {
        activityAlive = true
        handler.removeCallbacks(releaseIfIdle)
    }

    fun onActivityDestroyed() {
        activityAlive = false
        scheduleRelease(0)
    }

    /// Dart side: `setActive(bool)` as a call starts and finishes.
    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setActive") {
                callActive = call.arguments as? Boolean ?: false
                if (callActive) handler.removeCallbacks(releaseIfIdle) else scheduleRelease(RELEASE_DELAY_MS)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun scheduleRelease(delayMs: Long) {
        handler.removeCallbacks(releaseIfIdle)
        handler.postDelayed(releaseIfIdle, delayMs)
    }
}
