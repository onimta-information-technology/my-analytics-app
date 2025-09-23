import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSettings {
  final double fontSize;
  final FontWeight fontWeight;

  FontSettings({required this.fontSize, required this.fontWeight});

  FontSettings copyWith({double? fontSize, FontWeight? fontWeight}) {
    return FontSettings(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
    );
  }

  Map<String, dynamic> toMap() {
    return {'fontSize': fontSize, 'fontWeight': fontWeight.index};
  }

  factory FontSettings.fromMap(Map<String, dynamic> map) {
    return FontSettings(
      fontSize: map['fontSize'] as double,
      fontWeight: FontWeight.values[map['fontWeight'] as int],
    );
  }
}

class FontSettingsNotifier extends StateNotifier<FontSettings> {
  FontSettingsNotifier()
    : super(FontSettings(fontSize: 18.0, fontWeight: FontWeight.w900)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final fontSize = prefs.getDouble('fontSize') ?? 18.0;
    final fontWeightIndex = prefs.getInt('fontWeight') ?? FontWeight.w900.index;

    state = FontSettings(
      fontSize: fontSize,
      fontWeight: FontWeight.values[fontWeightIndex],
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', state.fontSize);
    await prefs.setInt('fontWeight', state.fontWeight.index);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _saveSettings();
  }

  void setFontWeight(FontWeight weight) {
    state = state.copyWith(fontWeight: weight);
    _saveSettings();
  }
}

final fontSettingsProvider =
    StateNotifierProvider<FontSettingsNotifier, FontSettings>((ref) {
      return FontSettingsNotifier();
    });
