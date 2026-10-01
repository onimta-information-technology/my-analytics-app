package com.app.ballys_reservation

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/// Screen sharing during a call. Android 10+ only lets an app capture the
/// screen while a foreground service of type `mediaProjection` is running —
/// on 14+ it throws without one — so Dart starts [ScreenShareService] right
/// after the user consents and before WebRTC starts capturing, and stops it
/// once sharing is over.
object CallScreenShare {
    private const val CHANNEL = "call_screen_share"

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val intent = Intent(appContext, ScreenShareService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                appContext.startForegroundService(intent)
                            } else {
                                appContext.startService(intent)
                            }
                            // The capture must not begin until the service is in
                            // the foreground; give onStartCommand its turn first.
                            Handler(Looper.getMainLooper()).postDelayed({ result.success(true) }, 300)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        appContext.stopService(Intent(appContext, ScreenShareService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// "Stop sharing" from the notification: Dart unpublishes the track and
    /// then stops the service itself.
    fun requestStopFromNotification() {
        val engine = FlutterEngineCache.getInstance().get(CallKeepAlive.ENGINE_ID) ?: return
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("stopRequested", null)
    }
}

class ScreenShareService : Service() {
    companion object {
        private const val CHANNEL_ID = "call_screen_share"
        private const val NOTIFICATION_ID = 7341
        private const val ACTION_STOP = "com.app.ballys_reservation.STOP_SCREEN_SHARE"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            CallScreenShare.requestStopFromNotification()
            return START_NOT_STICKY
        }
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(CHANNEL_ID) == null
        ) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Screen sharing", NotificationManager.IMPORTANCE_LOW),
            )
        }
        val immutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            immutable or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, ScreenShareService::class.java).setAction(ACTION_STOP),
            immutable or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentTitle("You're sharing your screen")
            .setContentText("Everyone on the call can see your screen")
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(0, "Stop sharing", stop)
            .build()
    }
}
