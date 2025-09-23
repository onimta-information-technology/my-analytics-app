import 'package:flutter/material.dart';
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

  AppModeSettingsNotifier() : super(AppModeSettings(appMode: AppMode.myData));

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (_currentSalesCode == null) {
      print('Warning: Sales code not set when loading settings');
      return;
    }

    // Check if this is the first login for this user
    final isFirstLogin =
        prefs.getBool('isFirstLogin_$_currentSalesCode') ?? true;
    final savedAppModeIndex = prefs.getInt('appMode_$_currentSalesCode');

    print('Loading settings for user: $_currentSalesCode');
    print('Is first login: $isFirstLogin');
    print('Saved app mode index: $savedAppModeIndex');

    if (_currentSalesCode == 'AD001' && isFirstLogin) {
      // AD001 user logging in for the first time - set to overallData
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

      print('AD001 first login: Set to overallData');
    } else if (savedAppModeIndex != null) {
      // User has saved preferences
      state = AppModeSettings(
        appMode: AppMode.values[savedAppModeIndex],
        isFirstLogin: false,
      );
      print('Loaded saved preference: ${AppMode.values[savedAppModeIndex]}');
    } else {
      // Default case for other users or if no saved preference
      state = AppModeSettings(appMode: AppMode.myData, isFirstLogin: false);

      // Save default setting
      await prefs.setInt('appMode_$_currentSalesCode', AppMode.myData.index);
      await prefs.setBool('isFirstLogin_$_currentSalesCode', false);

      print('Set default: myData');
    }
  }

  Future<void> _saveSettings() async {
    if (_currentSalesCode == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appMode_$_currentSalesCode', state.appMode.index);
    await prefs.setBool('isFirstLogin_$_currentSalesCode', false);

    print('Saved settings: ${state.appMode} for user: $_currentSalesCode');
  }

  void setAppMode(AppMode mode) {
    state = state.copyWith(appMode: mode, isFirstLogin: false);
    _saveSettings();
  }

  void setSalesCode(String salesCode) async {
    if (_currentSalesCode != salesCode) {
      _currentSalesCode = salesCode;
      print('Sales code set to: $salesCode');
      await _loadSettings(); // Reload settings for new user
    }
  }

  bool canShowOverallData() {
    return _currentSalesCode == 'AD001';
  }

  String? get currentSalesCode => _currentSalesCode;
}

final appmodeSettingsProvider =
    StateNotifierProvider<AppModeSettingsNotifier, AppModeSettings>((ref) {
      return AppModeSettingsNotifier();
    });
