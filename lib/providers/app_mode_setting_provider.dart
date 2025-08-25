import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { myData, overallData }

class AppModeSettings {
  final AppMode appMode;

  AppModeSettings({required this.appMode});

  AppModeSettings copyWith({AppMode? appMode}) {
    return AppModeSettings(appMode: appMode ?? this.appMode);
  }

  Map<String, dynamic> toMap() {
    return {'appMode': appMode.index};
  }

  factory AppModeSettings.fromMap(Map<String, dynamic> map) {
    return AppModeSettings(appMode: AppMode.values[map['appMode'] ?? 0]);
  }
}

class AppModeSettingsNotifier extends StateNotifier<AppModeSettings> {
  AppModeSettingsNotifier() : super(AppModeSettings(appMode: AppMode.myData)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final appModeIndex = prefs.getInt('appMode');
    state = AppModeSettings(appMode: AppMode.values[appModeIndex ?? 0]);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('appMode', state.appMode.index);
  }

  void setAppMode(AppMode mode) {
    state = state.copyWith(appMode: mode);
    _saveSettings();
  }
}

final appmodeSettingsProvider =
    StateNotifierProvider<AppModeSettingsNotifier, AppModeSettings>((ref) {
      return AppModeSettingsNotifier();
    });
