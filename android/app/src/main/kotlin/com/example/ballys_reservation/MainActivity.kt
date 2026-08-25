package com.app.ballys_reservation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "developer_mode"
    private val CLIPBOARD_CHANNEL = "image_clipboard"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copyImage" -> copyImageToClipboard(
                        call.argument<ByteArray>("bytes"),
                        call.argument<String>("extension") ?: "png",
                        result,
                    )
                    "hasImage" -> result.success(clipboardImageUri() != null)
                    "readImage" -> readImageFromClipboard(result)
                    else -> result.notImplemented()
                }
            }
    }

    /// The first image the primary clip points at, or null when the clipboard
    /// holds something else. The clip's own mime type is unreliable across
    /// apps, so the resolver gets the first say.
    private fun clipboardImageUri(): Uri? {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip ?: return null
        for (i in 0 until clip.itemCount) {
            val uri = clip.getItemAt(i).uri ?: continue
            val type = contentResolver.getType(uri)
                ?: clip.description?.takeIf { it.mimeTypeCount > 0 }?.getMimeType(0)
            if (type != null && type.startsWith("image")) return uri
        }
        return null
    }

    private fun readImageFromClipboard(result: MethodChannel.Result) {
        val uri = clipboardImageUri()
        if (uri == null) {
            result.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null || bytes.isEmpty()) {
                result.success(null)
                return
            }
            val mime = contentResolver.getType(uri) ?: "image/png"
            result.success(
                mapOf(
                    "bytes" to bytes,
                    "extension" to mime.substringAfterLast('/', "png").substringBefore('+'),
                ),
            )
        } catch (e: Exception) {
            result.error("PASTE_FAILED", "Could not read the clipboard image: ${e.message}", null)
        }
    }

    /// Android has no "put these bytes on the clipboard" API — a clip carries a
    /// content:// URI instead, so the bytes are staged in the app cache and
    /// handed out through a FileProvider. The system grants the pasting app
    /// temporary read access to that URI on its own.
    private fun copyImageToClipboard(
        bytes: ByteArray?,
        extension: String,
        result: MethodChannel.Result,
    ) {
        if (bytes == null || bytes.isEmpty()) {
            result.error("NO_DATA", "No image bytes were supplied", null)
            return
        }
        try {
            val dir = File(cacheDir, "clipboard_images")
            if (!dir.exists()) dir.mkdirs()
            // Only the most recent clip is reachable, so older staged files are dead weight.
            dir.listFiles()?.forEach { it.delete() }

            val file = File(dir, "clip_${System.currentTimeMillis()}.$extension")
            file.writeBytes(bytes)

            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.clipboardprovider",
                file,
            )
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newUri(contentResolver, "Image", uri))
            result.success(true)
        } catch (e: Exception) {
            result.error("COPY_FAILED", "Could not copy image: ${e.message}", null)
        }
    }
}
