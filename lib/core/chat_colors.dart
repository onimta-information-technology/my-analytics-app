import 'package:flutter/material.dart';

/// The chat's own palette, matching WhatsApp's current light and dark themes
/// (the 2023 refresh, not the older dark-teal one).
///
/// Kept apart from the app's amber Bally's chrome for the same reason the chat
/// font is: the conversation is meant to read like a messenger, and pulling
/// every value from one place means the two never drift.
///
/// Dark mode and the colour theme are the chat's alone — the rest of the app
/// stays light amber. They are set by `chatDarkModeProvider` and
/// `chatThemeProvider`, and `ChatFontScope` rebuilds every chat widget below
/// it when either changes, so each value here is a getter rather than a
/// `const`.
class ChatColors {
  const ChatColors._();

  /// Set by `chatDarkModeProvider` only.
  static bool isDark = false;

  /// Set by `chatThemeProvider` only.
  static ChatTheme theme = ChatTheme.green;

  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  static ChatThemePalette get _palette => isDark ? theme.dark : theme.light;

  // ── Chrome ────────────────────────────────────────────────────────────────
  /// Tab indicators, primary buttons, spinners, selected radios.
  static Color get primary => _palette.primary;

  /// The deeper shade: pressed states, and theme-coloured text on the
  /// screen's ground.
  static Color get primaryDark => _palette.primaryDark;

  /// The brighter shade — FAB, online dot, send button.
  static Color get accent => _palette.accent;

  /// App bar background. The theme colour in light mode; WhatsApp's dark mode
  /// drops the coloured bar for a dark grey one.
  static Color get appBar =>
      isDark ? const Color(0xFF1F2C34) : _palette.primary;

  /// Screen ground behind lists (chat list, settings, profile).
  static Color get background =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF111B21));

  /// Ground for grouped settings-style screens.
  static Color get groupedBackground =>
      _pick(const Color(0xFFF5F5F5), const Color(0xFF0B141A));

  /// Cards, sheets, dialogs, the composer bar.
  static Color get surface =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF1F2C34));

  /// Search boxes and other filled fields.
  static Color get inputFill =>
      _pick(const Color(0xFFEEEEEE), const Color(0xFF2A3942));

  // Text and icon tones, darkest first. The light values are the greys the
  // chat screens always used, so light mode looks exactly as before.
  /// Main text on [background] / [surface].
  static Color get textPrimary =>
      _pick(const Color(0xDD000000), const Color(0xFFE9EDEF));

  static Color get textStrong =>
      _pick(const Color(0xFF424242), const Color(0xFFE9EDEF));

  static Color get textMuted =>
      _pick(const Color(0xFF616161), const Color(0xFFD1D7DB));

  /// Subtitles, previews, timestamps in the list.
  static Color get textSecondary =>
      _pick(const Color(0xFF757575), const Color(0xFF8696A0));

  /// Faint icons and hints.
  static Color get textHint =>
      _pick(const Color(0xFF9E9E9E), const Color(0xFF8696A0));

  static Color get textFaint =>
      _pick(const Color(0xFFBDBDBD), const Color(0xFF3B4A54));

  /// Hairlines, sheet grab handles, and the grey behind a loading picture.
  static Color get divider =>
      _pick(const Color(0xFFE0E0E0), const Color(0xFF2A3942));

  /// The wash over a selected chat in the list.
  static Color get listSelection => _palette.listSelection;

  // ── Conversation ──────────────────────────────────────────────────────────
  /// Behind the message list.
  static Color get chatBackground => _palette.chatBackground;

  /// The doodle pattern drawn over that ground. Barely a shade off it — it is
  /// texture, and must never compete with a bubble sitting on top of it.
  static Color get wallpaperDoodle => _palette.wallpaperDoodle;

  /// Your own messages.
  static Color get outgoingBubble => _palette.outgoingBubble;

  /// Everyone else's.
  static Color get incomingBubble =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF202C33));

  /// The same two while the message is selected.
  static Color get outgoingBubbleSelected => _palette.outgoingBubbleSelected;
  static Color get incomingBubbleSelected =>
      _pick(const Color(0xFFEDEDED), const Color(0xFF2A3942));

  /// The wash over a whole selected row.
  static Color get selectionOverlay => _palette.accent.withAlpha(0x33);

  /// Message text. Both bubbles share one colour in each mode, so nothing here
  /// is keyed to "is this mine".
  static Color get bubbleText =>
      _pick(const Color(0xFF111B21), const Color(0xFFE9EDEF));

  /// Timestamps, "edited", the forwarded tag, delivered ticks.
  static Color get bubbleMeta =>
      _pick(const Color(0xFF667781), const Color(0xFF8696A0));

  /// Read receipt.
  static Color get readTick =>
      _pick(const Color(0xFF53BDEB), const Color(0xFF53BDEB));

  /// Links and @mentions inside a bubble.
  static Color get link =>
      _pick(const Color(0xFF027EB5), const Color(0xFF53BDEB));

  /// Quoted (replied-to) block inside a bubble, and its left stripe.
  static Color get quoteOnOutgoing => _palette.quoteOnOutgoing;
  static Color get quoteOnIncoming =>
      _pick(const Color(0x0F000000), const Color(0xFF1D282F));

  /// Attachment tile inside a bubble — a shade off the bubble it sits on.
  static Color get attachmentOnOutgoing => _palette.attachmentOnOutgoing;
  static Color get attachmentOnIncoming =>
      _pick(const Color(0xFFF0F0F0), const Color(0xFF1D282F));

  /// Date separator and system notices ("Nimal added Kasun").
  static Color get systemPill => _palette.systemPill;
  static Color get systemPillText =>
      _pick(const Color(0xFF3B4A54), const Color(0xFF8696A0));
}

/// The colours that give a chat theme its character, for one mode. Everything
/// else in [ChatColors] — text greys, surfaces, the incoming bubble — is
/// neutral and stays the same under every theme.
class ChatThemePalette {
  const ChatThemePalette({
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.listSelection,
    required this.chatBackground,
    required this.wallpaperDoodle,
    required this.outgoingBubble,
    required this.outgoingBubbleSelected,
    required this.quoteOnOutgoing,
    required this.attachmentOnOutgoing,
    required this.systemPill,
  });

  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color listSelection;
  final Color chatBackground;
  final Color wallpaperDoodle;
  final Color outgoingBubble;
  final Color outgoingBubbleSelected;
  final Color quoteOnOutgoing;
  final Color attachmentOnOutgoing;
  final Color systemPill;
}

// Dark mode keeps WhatsApp's neutral grey for these under every theme — a
// tinted wash reads as a stain on the near-black ground.
const _darkListSelection = Color(0xFF2A3942);
const _darkSystemPill = Color(0xFF182229);

/// The colour themes the chat settings screen offers. [green] is WhatsApp's
/// own and the default; its values are the ones the chat always used.
enum ChatTheme {
  green(
    'Green',
    light: ChatThemePalette(
      primary: Color(0xFF008069),
      primaryDark: Color(0xFF005C4B),
      accent: Color(0xFF25D366),
      listSelection: Color(0xFFE8F5E9),
      chatBackground: Color(0xFFEFE7DE),
      wallpaperDoodle: Color(0xFFDDD2C6),
      outgoingBubble: Color(0xFFD9FDD3),
      outgoingBubbleSelected: Color(0xFFC5F0BE),
      quoteOnOutgoing: Color(0xFFCFF0C6),
      attachmentOnOutgoing: Color(0xFFC5F0BE),
      systemPill: Color(0xFFE1F3E8),
    ),
    dark: ChatThemePalette(
      primary: Color(0xFF00A884),
      primaryDark: Color(0xFF00A884),
      accent: Color(0xFF00A884),
      listSelection: _darkListSelection,
      chatBackground: Color(0xFF0B141A),
      wallpaperDoodle: Color(0xFF162127),
      outgoingBubble: Color(0xFF005C4B),
      outgoingBubbleSelected: Color(0xFF006B57),
      quoteOnOutgoing: Color(0xFF025144),
      attachmentOnOutgoing: Color(0xFF025144),
      systemPill: _darkSystemPill,
    ),
  ),
  blue(
    'Blue',
    light: ChatThemePalette(
      primary: Color(0xFF0B6BCB),
      primaryDark: Color(0xFF084C91),
      accent: Color(0xFF2D8CFF),
      listSelection: Color(0xFFE3F0FD),
      chatBackground: Color(0xFFE6EEF5),
      wallpaperDoodle: Color(0xFFD3DEE9),
      outgoingBubble: Color(0xFFD6E9FF),
      outgoingBubbleSelected: Color(0xFFC2DCFA),
      quoteOnOutgoing: Color(0xFFC9E0FA),
      attachmentOnOutgoing: Color(0xFFC2DCFA),
      systemPill: Color(0xFFDDEBFA),
    ),
    dark: ChatThemePalette(
      primary: Color(0xFF4A9EFF),
      primaryDark: Color(0xFF4A9EFF),
      accent: Color(0xFF4A9EFF),
      listSelection: _darkListSelection,
      chatBackground: Color(0xFF0B121A),
      wallpaperDoodle: Color(0xFF152230),
      outgoingBubble: Color(0xFF144D85),
      outgoingBubbleSelected: Color(0xFF1A5C9E),
      quoteOnOutgoing: Color(0xFF113F6E),
      attachmentOnOutgoing: Color(0xFF113F6E),
      systemPill: _darkSystemPill,
    ),
  ),
  purple(
    'Purple',
    light: ChatThemePalette(
      primary: Color(0xFF6A3FB5),
      primaryDark: Color(0xFF4E2A8E),
      accent: Color(0xFF8E5CF0),
      listSelection: Color(0xFFF0EAFB),
      chatBackground: Color(0xFFEEE9F5),
      wallpaperDoodle: Color(0xFFDDD5EA),
      outgoingBubble: Color(0xFFE9DDFF),
      outgoingBubbleSelected: Color(0xFFDACBF7),
      quoteOnOutgoing: Color(0xFFDFD1FA),
      attachmentOnOutgoing: Color(0xFFDACBF7),
      systemPill: Color(0xFFEBE3F8),
    ),
    dark: ChatThemePalette(
      primary: Color(0xFFA98AF5),
      primaryDark: Color(0xFFA98AF5),
      accent: Color(0xFFA98AF5),
      listSelection: _darkListSelection,
      chatBackground: Color(0xFF100D18),
      wallpaperDoodle: Color(0xFF1D1828),
      outgoingBubble: Color(0xFF4A2F82),
      outgoingBubbleSelected: Color(0xFF573894),
      quoteOnOutgoing: Color(0xFF3E276E),
      attachmentOnOutgoing: Color(0xFF3E276E),
      systemPill: _darkSystemPill,
    ),
  ),
  pink(
    'Pink',
    light: ChatThemePalette(
      primary: Color(0xFFC2185B),
      primaryDark: Color(0xFF8E1145),
      accent: Color(0xFFE84A8A),
      listSelection: Color(0xFFFCE8F0),
      chatBackground: Color(0xFFF6EAEE),
      wallpaperDoodle: Color(0xFFEAD6DD),
      outgoingBubble: Color(0xFFFFDDEA),
      outgoingBubbleSelected: Color(0xFFF7C9DA),
      quoteOnOutgoing: Color(0xFFFAD1E0),
      attachmentOnOutgoing: Color(0xFFF7C9DA),
      systemPill: Color(0xFFFADDE8),
    ),
    dark: ChatThemePalette(
      primary: Color(0xFFF06C9B),
      primaryDark: Color(0xFFF06C9B),
      accent: Color(0xFFF06C9B),
      listSelection: _darkListSelection,
      chatBackground: Color(0xFF170D12),
      wallpaperDoodle: Color(0xFF26161E),
      outgoingBubble: Color(0xFF7A2348),
      outgoingBubbleSelected: Color(0xFF8C2954),
      quoteOnOutgoing: Color(0xFF661D3C),
      attachmentOnOutgoing: Color(0xFF661D3C),
      systemPill: _darkSystemPill,
    ),
  ),
  amber(
    'Amber',
    light: ChatThemePalette(
      primary: Color(0xFFB35600),
      primaryDark: Color(0xFF803D00),
      accent: Color(0xFFF57C00),
      listSelection: Color(0xFFFFF0E0),
      chatBackground: Color(0xFFF5ECE1),
      wallpaperDoodle: Color(0xFFE8DACA),
      outgoingBubble: Color(0xFFFFE5CC),
      outgoingBubbleSelected: Color(0xFFF7D3B0),
      quoteOnOutgoing: Color(0xFFFADBBC),
      attachmentOnOutgoing: Color(0xFFF7D3B0),
      systemPill: Color(0xFFFCE9D4),
    ),
    dark: ChatThemePalette(
      primary: Color(0xFFFF9A3C),
      primaryDark: Color(0xFFFF9A3C),
      accent: Color(0xFFFF9A3C),
      listSelection: _darkListSelection,
      chatBackground: Color(0xFF15100B),
      wallpaperDoodle: Color(0xFF251C14),
      outgoingBubble: Color(0xFF7A4210),
      outgoingBubbleSelected: Color(0xFF8C4D14),
      quoteOnOutgoing: Color(0xFF66370D),
      attachmentOnOutgoing: Color(0xFF66370D),
      systemPill: _darkSystemPill,
    ),
  ),
  graphite(
    'Graphite',
    light: ChatThemePalette(
      primary: Color(0xFF54656F),
      primaryDark: Color(0xFF3B4A54),
      accent: Color(0xFF667781),
      listSelection: Color(0xFFECEFF1),
      chatBackground: Color(0xFFEEF0F1),
      wallpaperDoodle: Color(0xFFDCE0E3),
      outgoingBubble: Color(0xFFDCE3E8),
      outgoingBubbleSelected: Color(0xFFCBD4DA),
      quoteOnOutgoing: Color(0xFFD2DAE0),
      attachmentOnOutgoing: Color(0xFFCBD4DA),
      systemPill: Color(0xFFE4E8EB),
    ),
    dark: ChatThemePalette(
      primary: Color(0xFF8FA3AE),
      primaryDark: Color(0xFF8FA3AE),
      accent: Color(0xFF8FA3AE),
      listSelection: _darkListSelection,
      chatBackground: Color(0xFF0F1214),
      wallpaperDoodle: Color(0xFF1B2024),
      outgoingBubble: Color(0xFF3B4A54),
      outgoingBubbleSelected: Color(0xFF46565F),
      quoteOnOutgoing: Color(0xFF323F47),
      attachmentOnOutgoing: Color(0xFF323F47),
      systemPill: _darkSystemPill,
    ),
  );

  const ChatTheme(this.label, {required this.light, required this.dark});

  final String label;
  final ChatThemePalette light;
  final ChatThemePalette dark;
}
