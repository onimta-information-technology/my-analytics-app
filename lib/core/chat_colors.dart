import 'package:flutter/material.dart';

/// The chat's own palette, matching WhatsApp's current light and dark themes
/// (the 2023 refresh, not the older dark-teal one).
///
/// Kept apart from the app's amber Bally's chrome for the same reason the chat
/// font is: the conversation is meant to read like a messenger, and pulling
/// every value from one place means the two never drift.
///
/// Dark mode is the chat's alone — the rest of the app stays light. The flag is
/// flipped by `chatDarkModeProvider`, and `ChatFontScope` rebuilds every chat
/// widget below it when it does, so each value here is a getter rather than a
/// `const`.
class ChatColors {
  const ChatColors._();

  /// Set by `chatDarkModeProvider` only.
  static bool isDark = false;

  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  // ── Chrome ────────────────────────────────────────────────────────────────
  /// Tab indicators, primary buttons, spinners, selected radios.
  static Color get primary =>
      _pick(const Color(0xFF008069), const Color(0xFF00A884));

  /// The deeper green: pressed states, and green text on the screen's ground.
  static Color get primaryDark =>
      _pick(const Color(0xFF005C4B), const Color(0xFF00A884));

  /// The brighter green — FAB, online dot, send button.
  static Color get accent =>
      _pick(const Color(0xFF25D366), const Color(0xFF00A884));

  /// App bar background. Green in light mode; WhatsApp's dark mode drops the
  /// green bar for a dark grey one.
  static Color get appBar =>
      _pick(const Color(0xFF008069), const Color(0xFF1F2C34));

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
  static Color get listSelection =>
      _pick(const Color(0xFFE8F5E9), const Color(0xFF2A3942));

  // ── Conversation ──────────────────────────────────────────────────────────
  /// Behind the message list.
  static Color get chatBackground =>
      _pick(const Color(0xFFEFE7DE), const Color(0xFF0B141A));

  /// The doodle pattern drawn over that ground. Barely a shade off it — it is
  /// texture, and must never compete with a bubble sitting on top of it.
  static Color get wallpaperDoodle =>
      _pick(const Color(0xFFDDD2C6), const Color(0xFF162127));

  /// Your own messages.
  static Color get outgoingBubble =>
      _pick(const Color(0xFFD9FDD3), const Color(0xFF005C4B));

  /// Everyone else's.
  static Color get incomingBubble =>
      _pick(const Color(0xFFFFFFFF), const Color(0xFF202C33));

  /// The same two while the message is selected.
  static Color get outgoingBubbleSelected =>
      _pick(const Color(0xFFC5F0BE), const Color(0xFF006B57));
  static Color get incomingBubbleSelected =>
      _pick(const Color(0xFFEDEDED), const Color(0xFF2A3942));

  /// The wash over a whole selected row.
  static Color get selectionOverlay =>
      _pick(const Color(0x3325D366), const Color(0x3300A884));

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
  static Color get quoteOnOutgoing =>
      _pick(const Color(0xFFCFF0C6), const Color(0xFF025144));
  static Color get quoteOnIncoming =>
      _pick(const Color(0x0F000000), const Color(0xFF1D282F));

  /// Attachment tile inside a bubble — a shade off the bubble it sits on.
  static Color get attachmentOnOutgoing =>
      _pick(const Color(0xFFC5F0BE), const Color(0xFF025144));
  static Color get attachmentOnIncoming =>
      _pick(const Color(0xFFF0F0F0), const Color(0xFF1D282F));

  /// Date separator and system notices ("Nimal added Kasun").
  static Color get systemPill =>
      _pick(const Color(0xFFE1F3E8), const Color(0xFF182229));
  static Color get systemPillText =>
      _pick(const Color(0xFF3B4A54), const Color(0xFF8696A0));
}
