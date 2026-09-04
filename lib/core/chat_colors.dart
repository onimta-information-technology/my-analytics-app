import 'package:flutter/material.dart';

/// The chat's own palette, matching WhatsApp's current light theme (the 2023
/// refresh, not the older dark-teal one).
///
/// Kept apart from the app's amber Bally's chrome for the same reason the chat
/// font is: the conversation is meant to read like a messenger, and pulling
/// every value from one place means the two never drift.
class ChatColors {
  const ChatColors._();

  // ── Chrome ────────────────────────────────────────────────────────────────
  /// App bars, tab indicators, primary buttons, spinners.
  static const Color primary = Color(0xFF008069);

  /// The deeper green: pressed states, and green text on a light ground.
  static const Color primaryDark = Color(0xFF005C4B);

  /// The brighter green — FAB, online dot, send button.
  static const Color accent = Color(0xFF25D366);

  // ── Conversation ──────────────────────────────────────────────────────────
  /// Behind the message list.
  static const Color chatBackground = Color(0xFFEFE7DE);

  /// Your own messages.
  static const Color outgoingBubble = Color(0xFFD9FDD3);

  /// Everyone else's.
  static const Color incomingBubble = Color(0xFFFFFFFF);

  /// The same two while the message is selected.
  static const Color outgoingBubbleSelected = Color(0xFFC5F0BE);
  static const Color incomingBubbleSelected = Color(0xFFEDEDED);

  /// The wash over a whole selected row.
  static const Color selectionOverlay = Color(0x3325D366);

  /// Message text. WhatsApp reads dark on both bubbles — the outgoing one is
  /// pale enough that white would be unreadable, so nothing here is keyed to
  /// "is this mine".
  static const Color bubbleText = Color(0xFF111B21);

  /// Timestamps, "edited", the forwarded tag, delivered ticks.
  static const Color bubbleMeta = Color(0xFF667781);

  /// Read receipt.
  static const Color readTick = Color(0xFF53BDEB);

  /// Links and @mentions inside a bubble.
  static const Color link = Color(0xFF027EB5);

  /// Quoted (replied-to) block inside a bubble, and its left stripe.
  static const Color quoteOnOutgoing = Color(0xFFCFF0C6);
  static const Color quoteOnIncoming = Color(0x0F000000);

  /// Attachment tile inside a bubble — a shade off the bubble it sits on.
  static const Color attachmentOnOutgoing = Color(0xFFC5F0BE);
  static const Color attachmentOnIncoming = Color(0xFFF0F0F0);

  /// Date separator and system notices ("Nimal added Kasun").
  static const Color systemPill = Color(0xFFE1F3E8);
  static const Color systemPillText = Color(0xFF3B4A54);
}
