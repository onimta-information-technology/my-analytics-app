import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether chat runs in dark mode, as toggled on the chat settings screen.
///
/// Only the chat screens follow it — the rest of the app stays on its light
/// amber theme. The notifier keeps [ChatColors.isDark] in step so the palette
/// getters answer for the current mode, and `ChatFontScope` watches it to
/// rebuild the chat widgets when it flips.
class ChatDarkModeNotifier extends StateNotifier<bool> {
  ChatDarkModeNotifier() : super(ChatColors.isDark) {
    _load();
  }

  static const _key = 'chatDarkMode';

  /// Reads the saved mode into [ChatColors.isDark] before the first frame, so
  /// the first chat opened after launch does not flash light then dark.
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    ChatColors.isDark = prefs.getBool(_key) ?? false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key) ?? false;
    if (!mounted) return;
    ChatColors.isDark = stored;
    state = stored;
  }

  Future<void> setDark(bool dark) async {
    if (state == dark) return;
    ChatColors.isDark = dark;
    state = dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, dark);
  }
}

final chatDarkModeProvider = StateNotifierProvider<ChatDarkModeNotifier, bool>(
  (ref) => ChatDarkModeNotifier(),
);
