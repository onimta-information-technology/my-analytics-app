import 'dart:io';

import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/providers/chat_theme_provider.dart';
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
    final fontWeightIndex = prefs.getInt(_weightKey) ?? FontWeight.normal.index;

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
///
/// It also carries the chat's own light / dark mode ([chatDarkModeProvider]):
/// in dark mode the Material defaults below it (text, dialogs, sheets, list
/// tiles) switch to a dark theme, and when the mode flips every widget under
/// the scope is rebuilt so the [ChatColors] getters are read afresh.
class ChatFontScope extends ConsumerStatefulWidget {
  const ChatFontScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatFontScope> createState() => _ChatFontScopeState();
}

class _ChatFontScopeState extends ConsumerState<ChatFontScope> {
  /// Most chat widgets read [ChatColors] directly rather than through the
  /// theme, so a theme change alone would leave them stale — mark the whole
  /// subtree dirty instead. Runs only when the user flips the switch.
  void _rebuildSubtree() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    final element = context as Element;
    element.visitChildren(rebuild);

    // The widgets handed to this scope (a screen's app bar, search box, tabs)
    // were built — colours and all — by whichever widget built the scope, so
    // re-running only the descendants would reuse those stale values. Rebuild
    // that owner too: the nearest component ancestor.
    element.visitAncestorElements((ancestor) {
      if (ancestor is ComponentElement) {
        ancestor.markNeedsBuild();
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = ref.watch(chatDarkModeProvider);
    ref.listen<bool>(chatDarkModeProvider, (previous, next) {
      if (previous != next) _rebuildSubtree();
    });

    final base = Theme.of(context);
    return Theme(
      data: dark ? _darkTheme(base) : _lightTheme(base),
      child: widget.child,
    );
  }

  ThemeData _lightTheme(ThemeData base) => base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: kChatFontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: kChatFontFamily),
  );

  ThemeData _darkTheme(ThemeData base) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ChatColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: ChatColors.primary,
          surface: ChatColors.surface,
          onSurface: ChatColors.textPrimary,
        );
    final dark = ThemeData(
      useMaterial3: base.useMaterial3,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ChatColors.background,
      canvasColor: ChatColors.background,
      cardColor: ChatColors.surface,
      dividerColor: ChatColors.divider,
      dialogTheme: DialogThemeData(backgroundColor: ChatColors.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ChatColors.surface,
        modalBackgroundColor: ChatColors.surface,
      ),
      popupMenuTheme: PopupMenuThemeData(color: ChatColors.surface),
      listTileTheme: ListTileThemeData(
        iconColor: ChatColors.textSecondary,
        textColor: ChatColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: ChatColors.textSecondary),
    );
    return dark.copyWith(
      textTheme: dark.textTheme.apply(
        fontFamily: kChatFontFamily,
        bodyColor: ChatColors.textPrimary,
        displayColor: ChatColors.textPrimary,
      ),
      primaryTextTheme: dark.primaryTextTheme.apply(
        fontFamily: kChatFontFamily,
      ),
    );
  }
}
