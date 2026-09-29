package com.app.ballys_reservation

import android.content.Context
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Rings for an incoming call with the phone's own ringtone.
///
/// Plays the symbolic [Settings.System.DEFAULT_RINGTONE_URI] rather than the
/// URI stored in the setting (`RingtoneManager.getActualDefaultRingtoneUri`,
/// which flutter_ringtone_player uses). Xiaomi keeps the ringtone the user
/// picked per SIM, and the stored URI can still point at the factory tone;
/// the symbolic one is resolved by the system when it plays.
object CallRingtone {
    private const val CHANNEL = "call_ringtone"
    private const val TAG = "CallRingtone"

    private var ringtone: Ringtone? = null

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        try {
                            play(appContext)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("PLAY_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun play(context: Context) {
        stop()
        logRingtoneSettings(context)
        val tone = RingtoneManager.getRingtone(context, Settings.System.DEFAULT_RINGTONE_URI)
            ?: throw IllegalStateException("no ringtone for the default URI")
        tone.audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) tone.isLooping = true
        Log.d(TAG, "playing: ${tone.getTitle(context)}")
        tone.play()
        ringtone = tone
    }

    private fun stop() {
        ringtone?.stop()
        ringtone = null
    }

    /// Where each ringtone setting points, to tell a phone whose stored
    /// setting disagrees with what the user picked (Xiaomi's per-SIM slots).
    private fun logRingtoneSettings(context: Context) {
        val resolver = context.contentResolver
        for (key in listOf("ringtone", "ringtone_sound_slot_1", "ringtone_sound_slot_2")) {
            val value = try {
                Settings.System.getString(resolver, key)
            } catch (e: Exception) {
                "unreadable: ${e.message}"
            }
            Log.d(TAG, "$key = $value")
        }
    }
}
