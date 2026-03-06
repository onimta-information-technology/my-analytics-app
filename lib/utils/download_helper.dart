import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  static final Dio _dio = Dio();

  /// Download any file (image or PDF) and save it locally, then open it.
  static Future<void> downloadAndOpen(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    try {
      // Request storage permission
      final bool granted = await _requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show downloading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Downloading $fileName...'),
              ],
            ),
            duration: const Duration(seconds: 30),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Determine save directory
      final Directory dir = await _getSaveDirectory();
      final String savePath = '${dir.path}/$fileName';

      // Download
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          // optional: hook for progress
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(savePath),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      // Use Downloads folder on Android
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    // Fallback: app documents directory
    return getApplicationDocumentsDirectory();
  }

  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidSdkVersion();
      if (androidVersion >= 33) {
        // Android 13+ uses granular media permissions
        final photos = await Permission.photos.request();
        return photos.isGranted || photos.isLimited;
      } else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }
    // iOS doesn't need explicit permission for app documents dir
    return true;
  }

  static Future<int> _getAndroidSdkVersion() async {
    try {
      if (Platform.isAndroid) {
        // Read from system property
        final result = await Process.run('getprop', ['ro.build.version.sdk']);
        return int.tryParse(result.stdout.toString().trim()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}