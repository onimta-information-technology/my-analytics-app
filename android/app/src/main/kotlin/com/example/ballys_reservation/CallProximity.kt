package com.app.ballys_reservation

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Blanks the screen while the phone is held to the ear during a call, the
/// way the system dialer does. The system does the sensing itself once the
/// proximity wake lock is held; Dart only says when it should be.
object CallProximity {
    private const val CHANNEL = "call_proximity"

    /// Lives outside the Activity, like the engine it serves (see
    /// [CallKeepAlive]), so a recreated Activity can still release it.
    private var wakeLock: PowerManager.WakeLock? = null

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        setEnabled(appContext, call.arguments as? Boolean ?: false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setEnabled(context: Context, enabled: Boolean) {
        if (enabled) {
            val lock = wakeLock ?: run {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
                    return
                }
                pm.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "ballys:call_proximity")
                    .also {
                        it.setReferenceCounted(false)
                        wakeLock = it
                    }
            }
            if (!lock.isHeld) lock.acquire()
        } else {
            // Waiting for the phone to leave the ear keeps the screen from
            // lighting up against the cheek when the call ends mid-sentence.
            wakeLock?.takeIf { it.isHeld }
                ?.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
        }
    }
}
