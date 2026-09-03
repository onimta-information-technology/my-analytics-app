import 'dart:io';

import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat runs on its own typography.
///
/// The rest of the app is ABCArizonaFlare at whatever size
/// `fontSettingsProvider` holds — a display face that reads well on forms and
/// reports but poorly on a wall of messages. Chat instead uses the platform's
/// own UI face (Roboto on Android, SF on iOS — the families WhatsApp reads in)
/// at a size the user picks from the chat's own settings screen, so changing
/// the app font leaves the conversation alone and the other way round.
final String kChatFontFamily = Platform.isIOS ? '.SF Pro Text' : 'Roboto';

/// The size steps the chat settings screen offers, WhatsApp's three.
class ChatFontSize {
  static const double small = 14.0;
  static const double medium = 16.0;
  static const double large = 19.0;

  static const List<double> all = <double>[small, medium, large];

  static String labelFor(double size) {
    if (size <= small) return 'Small';
    if (size >= large) return 'Large';
    return 'Medium';
  }
}

/// Same shape as the app-wide settings — the chat widgets already take a
/// [FontSettings], so only the source of the value changes here — but stored
/// under its own keys so the two never overwrite each other.
class ChatFontSettingsNotifier extends StateNotifier<FontSettings> {
  ChatFontSettingsNotifier()
    : super(
        FontSettings(
          fontSize: ChatFontSize.medium,
          fontWeight: FontWeight.normal,
        ),
      ) {
    _loadSettings();
  }

  static const _sizeKey = 'chatFontSize';
  static const _weightKey = 'chatFontWeight';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final fontSize = prefs.getDouble(_sizeKey) ?? ChatFontSize.medium;
    final fontWeightIndex =
        prefs.getInt(_weightKey) ?? FontWeight.normal.index;

    state = FontSettings(
      fontSize: fontSize,
      fontWeight: FontWeight.values[fontWeightIndex],
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sizeKey, state.fontSize);
    await prefs.setInt(_weightKey, state.fontWeight.index);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _saveSettings();
  }

  void setFontWeight(FontWeight weight) {
    state = state.copyWith(fontWeight: weight);
    _saveSettings();
  }

  void resetToDefaults() {
    state = FontSettings(
      fontSize: ChatFontSize.medium,
      fontWeight: FontWeight.normal,
    );
    _saveSettings();
  }
}

final chatFontSettingsProvider =
    StateNotifierProvider<ChatFontSettingsNotifier, FontSettings>((ref) {
      return ChatFontSettingsNotifier();
    });

/// Puts [kChatFontFamily] on every text style below it, so chat text picks up
/// the messenger face without each of the hundreds of `TextStyle`s in the chat
/// screens having to name a family. Wrap a chat screen's body with it, and also
/// the content of any sheet or dialog the chat opens — those get their own
/// route, so they would otherwise fall back to the app-wide theme.
class ChatFontScope extends StatelessWidget {
  const ChatFontScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: kChatFontFamily),
        primaryTextTheme: base.primaryTextTheme.apply(
          fontFamily: kChatFontFamily,
        ),
      ),
      child: child,
    );
  }
}
