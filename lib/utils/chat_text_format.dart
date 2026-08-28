/// WhatsApp-style inline formatting for chat message text.
///
/// A message typed as "that was *great*" is sent verbatim — the markers stay
/// in the stored text, the way WhatsApp does it — and only the rendering
/// strips them and applies the style. That keeps the wire format unchanged and
/// means an older client simply shows the asterisks.
library;

/// A run of message text and whether it is emphasised.
class ChatTextRun {
  const ChatTextRun(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

/// Matches "*bold*": no whitespace just inside either marker, and no other
/// "*" in between. The whitespace rule is what keeps "3 * 4 = 12" and a
/// bulleted "* item" line out of it.
final RegExp _boldPattern = RegExp(r'\*([^\s*](?:[^*]*[^\s*])?)\*');

/// [text] split into plain and bold runs, markers removed.
///
/// Returns a single plain run when nothing in [text] is marked up, so callers
/// can keep their existing fast path.
List<ChatTextRun> splitChatFormatting(String text) {
  if (!text.contains('*')) return [ChatTextRun(text)];

  final runs = <ChatTextRun>[];
  var last = 0;
  for (final match in _boldPattern.allMatches(text)) {
    if (match.start > last) {
      runs.add(ChatTextRun(text.substring(last, match.start)));
    }
    runs.add(ChatTextRun(match.group(1)!, bold: true));
    last = match.end;
  }
  if (runs.isEmpty) return [ChatTextRun(text)];
  if (last < text.length) runs.add(ChatTextRun(text.substring(last)));
  return runs;
}

/// [text] with the formatting markers taken out, for the one-line previews
/// (chat list, reply quote) that render as a plain [Text] and would otherwise
/// show the raw asterisks.
String stripChatFormatting(String text) {
  if (!text.contains('*')) return text;
  return text.replaceAllMapped(_boldPattern, (m) => m.group(1)!);
}
