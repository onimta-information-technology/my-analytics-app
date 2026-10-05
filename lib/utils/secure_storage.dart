import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one [FlutterSecureStorage] instance the app uses.
///
/// Android is pinned to EncryptedSharedPreferences. The plugin's legacy
/// default wraps an AES key with an AndroidKeyStore RSA key and keeps the
/// wrapped key in a plain preferences file; several OEM ROMs drop the keystore
/// entry across a Play Store update, and Android's Auto Backup restores that
/// preferences file onto a device whose keystore never held the key. Either
/// way every read afterwards fails — the API URL and the access token vanish
/// while the session in SharedPreferences still looks valid.
///
/// [AndroidOptions.resetOnError] turns an unreadable store into an empty one
/// instead of a fatal PlatformException. Nothing kept here is unrecoverable:
/// the device config is mirrored in SharedPreferences by `StorageUtil` and the
/// access token is re-fetched by `TokenManager`.
///
/// resetOnError alone is not enough, though: the plugin "resets" by calling
/// `EncryptedSharedPreferences.edit().clear()`, which first decrypts every key
/// in the file. When the file holds an entry EncryptedSharedPreferences cannot
/// decrypt (a legacy-format entry left by a failed migration, or one the plugin
/// wrote unencrypted after a transient keystore failure) that reset throws the
/// same "Could not decrypt key" error, and every later call — `deleteAll` on
/// login included — fails for good. [_SelfHealingSecureStorage] catches that,
/// wipes the raw preferences files natively and retries once.
class SecureStorage {
  const SecureStorage._();

  static const FlutterSecureStorage instance = _SelfHealingSecureStorage();
}

class _SelfHealingSecureStorage extends FlutterSecureStorage {
  const _SelfHealingSecureStorage()
    : super(
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
          resetOnError: true,
        ),
      );

  static const _channel = MethodChannel('secure_storage_recovery');

  /// Runs [op]; if Android reports a corrupt store, wipes it and runs [op]
  /// once more against the fresh, empty store.
  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PlatformException catch (e) {
      if (!Platform.isAndroid) rethrow;
      debugPrint('SecureStorage corrupt, wiping: ${e.message}');
      await _channel.invokeMethod<void>('wipe');
      return op();
    }
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _guard(
    () => super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _guard(
    () => super.read(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _guard(
    () => super.containsKey(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _guard(
    () => super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _guard(
    () => super.readAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _guard(
    () => super.deleteAll(
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );
}
