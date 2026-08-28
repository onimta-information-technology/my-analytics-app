/// WhatsApp-style inline formatting for chat message text.
///
/// A message typed as "that was *great*" is sent verbatim — the markers stay
/// in the stored text, the way WhatsApp does it — and only the rendering
/// strips them and applies the style. That keeps the wire format unchanged and
/// means an older client simply shows the asterisks.
///
/// Supported, and nestable in any order ("*_both_*", "~*_all three_*~"):
///   *bold*   _italic_   ~strikethrough~
library;

/// A run of message text and the emphasis it carries.
class ChatTextRun {
  const ChatTextRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool strike;

  bool get isPlain => !bold && !italic && !strike;
}

enum _Emphasis { bold, italic, strike }

/// Each marker: no whitespace just inside either end, and no other marker of
/// the same kind in between. The whitespace rule is what keeps "3 * 4 = 12"
/// and a bulleted "* item" line out of it.
///
/// Italic additionally needs a non-word character on the outside of each
/// underscore, so "my_file_name.pdf" and "snake_case" stay as typed — the one
/// place where being stricter than WhatsApp is worth it in a work chat.
final Map<_Emphasis, RegExp> _markers = {
  _Emphasis.bold: RegExp(r'\*([^\s*](?:[^*]*[^\s*])?)\*'),
  _Emphasis.italic: RegExp(
    r'(?<![A-Za-z0-9])_([^\s_](?:[^_]*[^\s_])?)_(?![A-Za-z0-9])',
  ),
  _Emphasis.strike: RegExp(r'~([^\s~](?:[^~]*[^\s~])?)~'),
};

/// Deep enough for every real combination — bold, italic and strike at once —
/// with room to spare, and a stop for text that is nothing but markers.
const int _maxNesting = 6;

ChatTextRun _run(String text, Set<_Emphasis> active) => ChatTextRun(
  text,
  bold: active.contains(_Emphasis.bold),
  italic: active.contains(_Emphasis.italic),
  strike: active.contains(_Emphasis.strike),
);

/// Walks [text] left to right, taking whichever marker opens first and
/// recursing into what it wraps, so nesting works whatever order it is
/// written in.
List<ChatTextRun> _runsIn(String text, Set<_Emphasis> active, int depth) {
  if (text.isEmpty) return const [];

  final runs = <ChatTextRun>[];
  var rest = text;

  while (rest.isNotEmpty) {
    _Emphasis? kind;
    RegExpMatch? hit;
    if (depth < _maxNesting) {
      for (final entry in _markers.entries) {
        // A mark already in force cannot be opened again inside itself.
        if (active.contains(entry.key)) continue;
        final match = entry.value.firstMatch(rest);
        if (match == null) continue;
        if (hit == null || match.start < hit.start) {
          kind = entry.key;
          hit = match;
        }
      }
    }

    if (hit == null) {
      runs.add(_run(rest, active));
      break;
    }

    if (hit.start > 0) runs.add(_run(rest.substring(0, hit.start), active));
    runs.addAll(_runsIn(hit.group(1)!, {...active, kind!}, depth + 1));
    rest = rest.substring(hit.end);
  }

  return runs;
}

/// [text] split into runs by emphasis, markers removed.
///
/// Returns a single plain run when nothing in [text] is marked up, so callers
/// can keep their existing fast path.
List<ChatTextRun> splitChatFormatting(String text) {
  if (!_hasMarker(text)) return [ChatTextRun(text)];
  final runs = _runsIn(text, const {}, 0);
  if (runs.isEmpty) return [ChatTextRun(text)];
  return runs;
}

/// [text] with the formatting markers taken out, for the one-line previews
/// (chat list, reply quote) that render as a plain [Text] and would otherwise
/// show the raw markers.
String stripChatFormatting(String text) {
  if (!_hasMarker(text)) return text;
  return splitChatFormatting(text).map((r) => r.text).join();
}

bool _hasMarker(String text) =>
    text.contains('*') || text.contains('_') || text.contains('~');
