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
  bool _hasMarketingPermission = false;

  AppModeSettingsNotifier() : super(AppModeSettings(appMode: AppMode.myData));

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (_currentSalesCode == null) {

      return;
    }

    _hasMarketingPermission = await StorageUtil.getMarketingP();

    // Check if this is the first login for this user
    final isFirstLogin =
        prefs.getBool('isFirstLogin_$_currentSalesCode') ?? true;
    final savedAppModeIndex = prefs.getInt('appMode_$_currentSalesCode');

    if (_hasMarketingPermission && isFirstLogin) {
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
    } else if (savedAppModeIndex != null) {
      // User has saved preferences
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

  bool canShowOverallData() {
    return _hasMarketingPermission;
  }

  String? get currentSalesCode => _currentSalesCode;
}

final appmodeSettingsProvider =
    StateNotifierProvider<AppModeSettingsNotifier, AppModeSettings>((ref) {
      return AppModeSettingsNotifier();
    });
