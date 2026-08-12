import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { myData, overallData }

class AppModeSettings {
  final AppMode appMode;
  final bool isFirstLogin;

  AppModeSettings({required this.appMode, this.isFirstLogin = false});

  AppModeSettings copyWith({AppMode? appMode, bool? isFirstLogin}) {
    return AppModeSettings(
      appMode: appMode ?? this.appMode,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
    );
  }

  Map<String, dynamic> toMap() {
    return {'appMode': appMode.index, 'isFirstLogin': isFirstLogin};
  }

  factory AppModeSettings.fromMap(Map<String, dynamic> map) {
    return AppModeSettings(
      appMode: AppMode.values[map['appMode'] ?? 0],
      isFirstLogin: map['isFirstLogin'] ?? false,
    );
  }
}

class AppModeSettingsNotifier extends StateNotifier<AppModeSettings> {
  String? _currentSalesCode;
  bool _isAdminSalesCode = false;
  bool _hasMarketingPermission = false;
  bool _hasOwnMarketingGroup = false;

  AppModeSettingsNotifier() : super(AppModeSettings(appMode: AppMode.myData));

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (_currentSalesCode == null) {

      return;
    }

    _isAdminSalesCode = await StorageUtil.isAdminSalesCode();
    _hasMarketingPermission = await StorageUtil.getMarketingP();
    _hasOwnMarketingGroup = await StorageUtil.hasOwnMarketingGroup();

    // Check if this is the first login for this user
    final isFirstLogin =
        prefs.getBool('isFirstLogin_$_currentSalesCode') ?? true;
    final savedAppModeIndex = prefs.getInt('appMode_$_currentSalesCode');

    if (!_isAdminSalesCode) {
      // Overall data is the AD001 admin login's alone. Everyone else stays on
      // their own numbers — Settings shows them a locked "Show My Data" box, so
      // any saved overallData index would contradict the UI. Overwrite it.
      state = AppModeSettings(appMode: AppMode.myData, isFirstLogin: false);

      await prefs.setInt('appMode_$_currentSalesCode', AppMode.myData.index);
      await prefs.setBool('isFirstLogin_$_currentSalesCode', false);
    } else if (!_hasOwnMarketingGroup) {
      // Marketing_Code 0 — the user is in no marketing group, so "my data"
      // would come back empty. Pin them to overall data and ignore any saved
      // preference. Applies whether or not MArketing_P is set.
      state = AppModeSettings(appMode: AppMode.overallData, isFirstLogin: false);

      await prefs.setInt(
        'appMode_$_currentSalesCode',
        AppMode.overallData.index,
      );
      await prefs.setBool('isFirstLogin_$_currentSalesCode', false);
    } else if (_hasMarketingPermission && isFirstLogin) {
      // Marketing-permission user logging in for the first time - overallData
      state = AppModeSettings(
        appMode: AppMode.overallData,
        isFirstLogin: false, // Mark as no longer first login
      );

      // Save the settings immediately
      await prefs.setInt(
        'appMode_$_currentSalesCode',
        AppMode.overallData.index,
      );
      await prefs.setBool('isFirstLogin_$_currentSalesCode', false);
    } else if (_hasMarketingPermission && savedAppModeIndex != null) {
      // Only users with the switch get to keep a saved preference — without
      // MArketing_P a stale overallData index would contradict the locked
      // "Show My Data" box in Settings.
      state = AppModeSettings(
        appMode: AppMode.values[savedAppModeIndex],
        isFirstLogin: false,
      );
    } else {
      // Default case for other users or if no saved preference
      state = AppModeSettings(appMode: AppMode.myData, isFirstLogin: false);

      // Save default setting
      await prefs.setInt('appMode_$_currentSalesCode', AppMode.myData.index);
      await prefs.setBool('isFirstLogin_$_currentSalesCode', false);
    }
  }

  Future<void> _saveSettings(AppMode mode) async {
    if (_currentSalesCode == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appMode_$_currentSalesCode', mode.index);
    await prefs.setBool('isFirstLogin_$_currentSalesCode', false);
  }

  void setAppMode(AppMode mode) {
    state = state.copyWith(appMode: mode, isFirstLogin: false);
    _saveSettings(mode);
  }

  void setSalesCode(String salesCode) async {
    if (_currentSalesCode != salesCode) {
      _currentSalesCode = salesCode;
      await _loadSettings(); // Reload settings for new user
    }
  }

  /// Overall data is reserved for the AD001 admin login — see [_loadSettings].
  bool canShowOverallData() {
    if (!_isAdminSalesCode) return false;
    return _hasMarketingPermission || !_hasOwnMarketingGroup;
  }

  /// Both modes are offered only to the admin login when it is a marketing
  /// user in a group. Without one there is nothing to switch between.
  bool canToggleAppMode() {
    return _isAdminSalesCode &&
        _hasMarketingPermission &&
        _hasOwnMarketingGroup;
  }

  String? get currentSalesCode => _currentSalesCode;
}

final appmodeSettingsProvider =
    StateNotifierProvider<AppModeSettingsNotifier, AppModeSettings>((ref) {
      return AppModeSettingsNotifier();
    });
