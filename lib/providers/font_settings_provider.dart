import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { myData, overallData }

class FontSettings {
  final double fontSize;
  final FontWeight fontWeight;
  final AppMode appMode;

  FontSettings({
    required this.fontSize,
    required this.fontWeight,
    required this.appMode,
  });

  FontSettings copyWith({double? fontSize, FontWeight? fontWeight,AppMode? appMode}) {
    return FontSettings(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      appMode: appMode ?? this.appMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {'fontSize': fontSize, 'fontWeight': fontWeight.index,'appMode': appMode.index};
  }

  factory FontSettings.fromMap(Map<String, dynamic> map) {
    return FontSettings(
      fontSize: map['fontSize'] as double,
      fontWeight: FontWeight.values[map['fontWeight'] as int],
      appMode: AppMode.values[map['appMode'] ?? 0],
    );
  }
}

class FontSettingsNotifier extends StateNotifier<FontSettings> {
  FontSettingsNotifier()
    : super(FontSettings(fontSize: 14.0, fontWeight: FontWeight.normal, appMode: AppMode.myData)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final fontSize = prefs.getDouble('fontSize') ?? 14.0;
    final fontWeightIndex =
        prefs.getInt('fontWeight') ?? FontWeight.normal.index;
    final appModeIndex = prefs.getInt('appMode') ?? AppMode.myData.index;
    state = FontSettings(
      fontSize: fontSize,
      fontWeight: FontWeight.values[fontWeightIndex],
      appMode: AppMode.values[appModeIndex],
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', state.fontSize);
    await prefs.setInt('fontWeight', state.fontWeight.index);
    await prefs.setInt('appMode', state.appMode.index);

  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _saveSettings();
  }

  void setFontWeight(FontWeight weight) {
    state = state.copyWith(fontWeight: weight);
    _saveSettings();
  }
  void setAppMode(AppMode mode) {
  state = state.copyWith(appMode: mode);
  _saveSettings();
}

}

final fontSettingsProvider =
    StateNotifierProvider<FontSettingsNotifier, FontSettings>((ref) {
      return FontSettingsNotifier();
    });
