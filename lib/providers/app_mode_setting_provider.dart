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
    return {
      'appMode': appMode.index,
      'isFirstLogin': isFirstLogin,
    };
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

  AppModeSettingsNotifier() : super(AppModeSettings(appMode: AppMode.myData)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current user's sales code from storage
    _currentSalesCode = prefs.getString('sales_code');
    
    final appModeIndex = prefs.getInt('appMode_$_currentSalesCode');
    final isFirstLogin = prefs.getBool('isFirstLogin_$_currentSalesCode') ?? true;

    // For AD001 users on first login, default to overallData
    if (_currentSalesCode == 'AD001' && isFirstLogin) {
      state = AppModeSettings(
        appMode: AppMode.overallData,
        isFirstLogin: true,
      );
      // Mark as no longer first login
      await prefs.setBool('isFirstLogin_$_currentSalesCode', false);
    } else {
      state = AppModeSettings(
        appMode: AppMode.values[appModeIndex ?? 0],
        isFirstLogin: false,
      );
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appMode_$_currentSalesCode', state.appMode.index);
  }

  void setAppMode(AppMode mode) {
    state = state.copyWith(appMode: mode, isFirstLogin: false);
    _saveSettings();
  }

  void setSalesCode(String salesCode) {
    _currentSalesCode = salesCode;
    _loadSettings(); // Reload settings for new user
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