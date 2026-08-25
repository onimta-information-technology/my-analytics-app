import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Puts an image on the system clipboard so it can be pasted into other apps.
///
/// Flutter's own [Clipboard] only carries text, so the bytes go across a
/// MethodChannel to `ClipData` on Android and `UIPasteboard` on iOS.
class ImageClipboard {
  static const MethodChannel _channel = MethodChannel('image_clipboard');
  static final Dio _dio = Dio();

  /// Copies the image at [url] (or [localPath]) and reports the outcome in a
  /// snackbar. Exactly one source is needed; [url] wins when both are given.
  static Future<void> copyImage(
    BuildContext context, {
    String? url,
    String? localPath,
    String? fileName,
  }) async {
    // Captured up front so the messenger survives the awaits below.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final Uint8List? bytes = await _loadBytes(url: url, localPath: localPath);
      if (bytes == null || bytes.isEmpty) {
        _snack(messenger, 'Could not load the image', Colors.red);
        return;
      }

      await _channel.invokeMethod<bool>('copyImage', {
        'bytes': bytes,
        'extension': _extensionFor(fileName ?? url ?? localPath),
      });

      _snack(messenger, 'Image copied', Colors.green);
    } on PlatformException catch (e) {
      _snack(messenger, 'Copy failed: ${e.message}', Colors.red);
    } catch (e) {
      _snack(messenger, 'Copy failed: $e', Colors.red);
    }
  }

  /// Whether the system clipboard is currently holding an image.
  static Future<bool> hasImage() async {
    try {
      return await _channel.invokeMethod<bool>('hasImage') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Writes the clipboard image out to a temp file and returns its path, so it
  /// can go through the same upload path as a picked file. Null when the
  /// clipboard holds no image.
  static Future<String?> pasteImageToFile() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'readImage',
    );
    if (result == null) return null;

    final bytes = result['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;

    final extension = (result['extension'] as String?) ?? 'png';
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/pasted_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// True when the image can be read at all — used to decide whether to offer
  /// a copy action before the user taps it.
  static bool canCopy({String? url, String? localPath}) {
    if (url != null && url.isNotEmpty) return true;
    return localPath != null && File(localPath).existsSync();
  }

  static Future<Uint8List?> _loadBytes({
    String? url,
    String? localPath,
  }) async {
    if (url != null && url.isNotEmpty) {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    }
    if (localPath != null) {
      final file = File(localPath);
      if (await file.exists()) return file.readAsBytes();
    }
    return null;
  }

  static String _extensionFor(String? source) {
    if (source == null) return 'png';
    // Strip any query string before looking at the suffix.
    final path = source.split('?').first.toLowerCase();
    for (final ext in const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp']) {
      if (path.endsWith('.$ext')) return ext;
    }
    return 'png';
  }

  static void _snack(
    ScaffoldMessengerState messenger,
    String message,
    Color color,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
