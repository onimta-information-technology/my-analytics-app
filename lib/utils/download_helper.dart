import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  static final Dio _dio = Dio();
  static int? _cachedSdkInt;

  /// Download any file (image or PDF) and save it locally, then open it.
  static Future<void> downloadAndOpen(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    try {
      // Request storage permission (only needed on legacy Android)
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

      String savePath = '${(await _getSaveDirectory()).path}/$fileName';

      try {
        await _dio.download(url, savePath);
      } on FileSystemException {
        // Public Downloads folder is not writable (scoped storage) — fall back
        // to the app-specific directory, which never needs a permission.
        savePath = '${(await _appDirectory()).path}/$fileName';
        await _dio.download(url, savePath);
      }

      final String openPath = savePath;
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(openPath),
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
      // Use the public Downloads folder when it is actually writable.
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists() && await _isWritable(dir)) return dir;
    }
    return _appDirectory();
  }

  /// App-specific directory — readable/writable without any runtime permission.
  static Future<Directory> _appDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) return external;
    }
    return getApplicationDocumentsDirectory();
  }

  static Future<bool> _isWritable(Directory dir) async {
    final probe = File(
      '${dir.path}/.write_probe_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _requestPermission() async {
    if (!Platform.isAndroid) {
      // iOS doesn't need explicit permission for app documents dir
      return true;
    }

    final sdkInt = await _getAndroidSdkVersion();

    // Android 10+ (API 29) uses scoped storage: writing to Downloads or to the
    // app-specific directory needs no runtime permission. READ_MEDIA_* is also
    // stripped from the manifest, so requesting Permission.photos here would
    // always come back denied.
    if (sdkInt >= 29) return true;

    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  static Future<int> _getAndroidSdkVersion() async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cachedSdkInt = info.version.sdkInt;
    } catch (_) {
      _cachedSdkInt = 0;
    }
    return _cachedSdkInt!;
  }
}
