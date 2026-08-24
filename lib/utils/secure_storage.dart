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
class SecureStorage {
  const SecureStorage._();

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );
}
