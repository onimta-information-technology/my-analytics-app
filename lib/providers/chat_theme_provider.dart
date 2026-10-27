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

/// The chat's colour theme, picked on the chat settings screen. Independent of
/// [chatDarkModeProvider]: every theme has a light and a dark variant, and the
/// mode switch chooses between them.
///
/// Mirrors [ChatDarkModeNotifier] — it keeps [ChatColors.theme] in step, and
/// `ChatFontScope` watches it to rebuild the chat widgets when it changes.
class ChatThemeNotifier extends StateNotifier<ChatTheme> {
  ChatThemeNotifier() : super(ChatColors.theme) {
    _load();
  }

  static const _key = 'chatTheme';

  static ChatTheme _parse(String? name) =>
      ChatTheme.values.asNameMap()[name] ?? ChatTheme.green;

  /// Reads the saved theme into [ChatColors.theme] before the first frame, so
  /// the first chat opened after launch does not flash green.
  static Future<void> preload() async {
    final prefs = await SharedPreferences.getInstance();
    ChatColors.theme = _parse(prefs.getString(_key));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = _parse(prefs.getString(_key));
    if (!mounted) return;
    ChatColors.theme = stored;
    state = stored;
  }

  Future<void> select(ChatTheme theme) async {
    if (state == theme) return;
    ChatColors.theme = theme;
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.name);
  }
}

final chatThemeProvider = StateNotifierProvider<ChatThemeNotifier, ChatTheme>(
  (ref) => ChatThemeNotifier(),
);
