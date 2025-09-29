package com.app.ballys_reservation

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "developer_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isDeveloperMode") {
                try {
                    // Try to read development-settings flag.
                    // Use Settings.Global / Settings.Secure depending on device; try one then fallback.
                    val devEnabled = try {
                        Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
                    } catch (e: Exception) {
                        Settings.Secure.getInt(contentResolver, Settings.Secure.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
                    }
                    result.success(devEnabled)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not check developer mode: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}