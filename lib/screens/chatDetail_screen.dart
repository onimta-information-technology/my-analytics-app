import 'dart:async';
import 'package:ballys_reservation_app/components/group_avatar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:ballys_reservation_app/components/badge_service.dart';
import 'package:ballys_reservation_app/components/forward_message_sheet.dart';
import 'package:ballys_reservation_app/components/group_details_sheet.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_group.dart';
import 'package:ballys_reservation_app/models/chat_message.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/current_chat_state.dart';
import 'package:ballys_reservation_app/utils/device_id.dart';
import 'package:ballys_reservation_app/utils/download_helper.dart';
import 'package:ballys_reservation_app/utils/image_clipboard.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Compression applied to camera/gallery images before upload, to keep chat
// attachments small.
const int _kImageQuality = 50;
const double _kImageMaxDimension = 1280;

// Colour the composer paints an "@Name" in once it has been picked from the
// suggestion list.
const Color _kMentionColor = Color.fromARGB(255, 12, 59, 121);

/// The same blue lightened for the green outgoing bubble, where [_kMentionColor]
/// on green would be too dark to read.
const Color _kMentionColorOnGreen =Color.fromARGB(255, 12, 59, 121);

/// Links in an incoming bubble read as the usual web blue; on the green
/// outgoing bubble that blue goes muddy, so links there stay white and lean
/// on the underline instead.
const Color _kLinkColor = Color(0xFF1B6BC0);
const Color _kLinkColorOnGreen = Colors.white;

/// Composer controller that paints picked "@Name" tokens in [_kMentionColor].
///
/// Only names in [mentionNames] are highlighted, so a half-typed "@que" or an
/// "@" someone typed by hand stays plain until it is actually a mention.
class _MentionTextEditingController extends TextEditingController {
  final Set<String> mentionNames = {};

  /// Rebuilds the field with the current [mentionNames] even when the text
  /// itself did not change — picking or dropping a mention repaints it.
  void refreshHighlights() => notifyListeners();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (mentionNames.isEmpty || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final mentionStyle = (style ?? const TextStyle()).copyWith(
      color: _kMentionColor,
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      // The earliest "@Name" from here on, and on a tie the longest one, so
      // "@John Smith" is coloured whole instead of only its "@John".
      var start = -1;
      var length = 0;
      for (final name in mentionNames) {
        if (name.isEmpty) continue;
        final token = '@$name';
        final at = text.indexOf(token, index);
        if (at == -1) continue;
        if (start == -1 || at < start || (at == start && token.length > length)) {
          start = at;
          length = token.length;
        }
      }
      if (start == -1) break;

      if (start > index) {
        spans.add(TextSpan(text: text.substring(index, start), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(start, start + length),
        style: mentionStyle,
      ));
      index = start + length;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}

class IndividualChatScreen extends ConsumerStatefulWidget {
  final ChatContact contact;
  final Function(String)? onMessageSent;

  /// Group conversation mode. The group's id is carried in
  /// [contact].chatUuid — the backend treats a groupId as a chatId, so
  /// fetching, uploading and read receipts all work unchanged; only sending
  /// and the sender labelling differ.
  final bool isGroup;
  final int groupMemberCount;

  /// False for a member of an admin-only group: the composer is replaced by a
  /// notice, since the backend would reject anything they typed.
  final bool canSendMessages;

  /// Unread messages naming the user, oldest first, as counted by the chat
  /// list. When non-empty the screen offers a jump to each of them in turn.
  final List<String> mentionMessageIds;

  /// Land on the oldest of [mentionMessageIds] instead of at the end of the
  /// conversation. True when the "@" marker was tapped; opening the same
  /// conversation by its row keeps the usual "newest message" landing, with
  /// the "@" button still there to jump.
  final bool jumpToMentionOnOpen;

  const IndividualChatScreen({
    super.key,
    required this.contact,
    this.onMessageSent,
    this.isGroup = false,
    this.groupMemberCount = 0,
    this.canSendMessages = true,
    this.mentionMessageIds = const [],
    this.jumpToMentionOnOpen = false,
  });

  @override
  ConsumerState<IndividualChatScreen> createState() =>
      _IndividualChatScreenState();
}

class _IndividualChatScreenState extends ConsumerState<IndividualChatScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _MentionTextEditingController _messageController =
      _MentionTextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _messageFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  String? _currentUserName;
  String? _currentUserUuid;

  /// Picture shown in the app bar. Seeded from the row we were opened with and
  /// re-fetched for groups, since a chat opened from a notification carries no
  /// avatar url of its own.
  String? _avatarUrl;

  // ── @mentions ──
  /// Group roster, used both to suggest names while typing and to highlight
  /// mentions in bubbles. Empty for 1:1 chats.
  List<GroupMember> _groupMembers = [];

  /// People picked from the suggestion list, keyed by uuid. Kept until send so
  /// their uuid/appType can be attached; entries whose "@Name" no longer
  /// appears in the text are dropped at that point.
  final Map<String, GroupMember> _pickedMentions = {};

  /// Currently offered suggestions, and where in the text the "@" that
  /// triggered them sits. Null anchor means no mention is being typed.
  List<GroupMember> _mentionSuggestions = [];
  int? _mentionAnchor;
  bool _isLoadingMessages = false;
  bool _isUploading = false;

  // ── Multi-select ──
  final Set<String> _selectedMessageIds = {};
  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;

  /// Message the composer is currently quoting, or null for a plain send.
  ChatMessage? _replyingTo;

  Timer? _readStatusPollTimer;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  // ── Jump to a mention ──
  /// One key per rendered message, so a message can be scrolled to by name.
  final Map<String, GlobalKey> _messageKeys = {};

  /// Mentions still to be visited, oldest first — seeded from
  /// [IndividualChatScreen.mentionMessageIds] and drained by the "@" button.
  late final List<String> _pendingMentions = List<String>.from(
    widget.mentionMessageIds,
  );

  /// The message currently flashing after being jumped to.
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  /// The opening jump is made once, on the first load that has the message.
  bool _initialMentionJumpDone = false;

  // ── Message search ──
  /// Search bar in place of the app bar title. The conversation itself is left
  /// whole; the arrows below it walk the messages that matched.
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Trimmed and lower-cased. Empty means the bar is open but nothing typed.
  String _searchQuery = '';

  /// Ids of the matching messages, newest first, and which of them is being
  /// shown. Recomputed every build rather than cached, so a message arriving
  /// or being deleted with the bar open cannot leave a stale hit behind.
  List<String> _searchHits = const [];
  int _searchIndex = 0;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CurrentChatState().setCurrentChat(widget.contact.chatUuid);
    _avatarUrl = widget.contact.avatarUrl;
    if (widget.isGroup) _loadGroupInfo();
    _getCurrentUserName();
    _fetchMessagesFromApi();
    _setupForegroundMessageListener();
    _startReadStatusPolling();
    _messageFocusNode.addListener(_onFocusChange);
    BadgeService().clearBadge();
  }

  @override
  void dispose() {
    _readStatusPollTimer?.cancel();
    _highlightTimer?.cancel();
    _foregroundMessageSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    CurrentChatState().clearCurrentChat();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (final recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    _linkRecognizers.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchMessagesFromApi(silent: true);
      BadgeService().clearBadge();
    }
  }

  // ─── Setup ─────────────────────────────────────────────────────────────────

  void _startReadStatusPolling() {
    _readStatusPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchMessagesFromApi(silent: true, updateReadStatusOnly: true);
      }
    });
  }

  void _onFocusChange() {
    if (_messageFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
    }
  }

  void _setupForegroundMessageListener() {
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      final chatId =
          message.data['chatId'] ??
          message.data['chat_id'] ??
          message.data['ChatId'] ??
          message.data['Chat_Id'];
      final msgType = message.data['msg_type'] ?? message.data['type'];
      final bool isChatMessage =
          msgType == '11' ||
          msgType == 'chat' ||
          message.data.containsKey('message') ||
          message.data.containsKey('Details');
      // Silent edit/reaction pings carry no message body — they only tell the
      // client the thread changed, so the list has to be pulled again.
      final bool isSilentUpdate =
          msgType == 'message_reaction' ||
          msgType == 'message_edit' ||
          msgType == 'message_edited';
      if (isChatMessage || isSilentUpdate) {
        if (chatId == null ||
            chatId.isEmpty ||
            chatId == widget.contact.chatUuid) {
          _fetchMessagesFromApi(silent: true);
        }
      }
    });
  }

  Future<void> _getCurrentUserName() async {
    try {
      final userName = await StorageUtil.getUserName();
      final deviceId = await DeviceId.get();
      if (!mounted) return;
      setState(() {
        _currentUserName = userName;
        _currentUserUuid = deviceId;
      });
    } catch (_) {}
  }

  /// Pulls the group's avatar and roster: the avatar so the app bar matches
  /// the group list (including after it is changed elsewhere), the roster so
  /// @mentions can be suggested and highlighted. Failures are silent — the
  /// initials fallback still renders, and mentions simply stay unavailable.
  Future<void> _loadGroupInfo() async {
    try {
      final group = await FirebaseApiService.fetchGroupDetails(
        widget.contact.chatUuid,
      );
      final details = GroupDetails.fromApiJson(group);
      if (!mounted) return;
      if (details.groupAvatarUrl == _avatarUrl &&
          details.members.length == _groupMembers.length) {
        return;
      }
      setState(() {
        _avatarUrl = details.groupAvatarUrl;
        _groupMembers = details.members;
      });
    } catch (_) {
      // Keep whatever we were opened with.
    }
  }

  void _openGroupInfo() {
    showGroupDetailsSheet(
      context: context,
      groupId: widget.contact.chatUuid,
      avatarColor: widget.contact.avatarColor,
      fontSettings: ref.read(fontSettingsProvider),
      currentUserUuid: _currentUserUuid,
      // Avatar/name edits in the sheet reflect back into the app bar.
      onGroupChanged: _loadGroupInfo,
      // Left or deleted: this conversation no longer exists for us.
      onGroupLeftOrDeleted: () {
        if (!mounted) return;
        FocusManager.instance.primaryFocus?.unfocus();
        _readStatusPollTimer?.cancel();
        _foregroundMessageSubscription?.cancel();
        CurrentChatState().clearCurrentChat();
        Navigator.pop(context);
      },
    );
  }

  // ─── Fetch messages ─────────────────────────────────────────────────────────

  Future<void> _fetchMessagesFromApi({
    bool silent = false,
    bool updateReadStatusOnly = false,
  }) async {
    if (_isLoadingMessages && !silent) return;
    if (!silent && !updateReadStatusOnly) {
      setState(() => _isLoadingMessages = true);
    }

    try {
      final response = await FirebaseApiService.fetchMessages(
        widget.contact.chatUuid,
      );
      final deviceId = await DeviceId.get();

      if (response['success'] == true && response['data'] != null) {
        final rd = response['data'];
        if (rd['success'] == true && rd['messages'] != null) {
          final List<dynamic> raw = rd['messages'];

          final flat = raw
              .map((j) => ChatMessage.fromApiResponse(j, deviceId ?? ''))
              .toList();
          final grouped = ChatMessage.groupImageMessages(flat);

          if (updateReadStatusOnly) {
            // ── Only update read-status fields, don't disturb the list ──
            bool changed = false;
            for (int i = 0; i < _messages.length; i++) {
              final updated = grouped.firstWhere(
                (m) => m.apiMessageId == _messages[i].apiMessageId,
                orElse: () => _messages[i],
              );
              if (_messages[i].isRead != updated.isRead) {
                changed = true;
                _messages[i] = updated;
              }
            }
            if (changed && mounted) setState(() {});
          } else {
            final hadMessages = _messages.isNotEmpty;
            final countChanged = _messages.length != grouped.length;

            // ── FIX: Preserve optimistic/local messages not yet confirmed by server ──
            // Local messages that were added optimistically (e.g. during upload)
            // have apiMessageId == null. Keep them until the server confirms them.
            final pendingLocal = _messages.where((m) {
              return m.apiMessageId == null &&
                  !grouped.any((g) => g.id == m.id);
            }).toList();

            // The chat endpoint does not always hand back the new messageId,
            // so an optimistic bubble can stay id-less — for group sends and
            // for 1:1 replies alike. Drop it once the server echoes the same
            // text back, otherwise it shows up twice.
            pendingLocal.removeWhere(
              (m) =>
                  m.isMe &&
                  m.text.isNotEmpty &&
                  grouped.any(
                    (g) =>
                        g.isMe &&
                        g.text == m.text &&
                        g.timestamp.difference(m.timestamp).abs() <
                            const Duration(minutes: 2),
                  ),
            );

            final merged = [...grouped, ...pendingLocal]
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

            setState(() {
              _messages = merged;
              if (!silent) _isLoadingMessages = false;
            });
            await _markMessagesAsRead();
            // Opened from the "@" marker: the mention is where the reader
            // wants to be, not the end of the conversation.
            if (!_consumeInitialMentionJump() &&
                (!hadMessages || (!silent && countChanged))) {
              await Future.delayed(const Duration(milliseconds: 100));
              _scrollToBottom();
            }
          }
        } else {
          if (!silent && !updateReadStatusOnly) {
            setState(() => _isLoadingMessages = false);
          }
        }
      }
    } catch (_) {
      if (!silent && !updateReadStatusOnly) {
        setState(() => _isLoadingMessages = false);
      }
    }
  }

  // Future<void> _markMessagesAsRead() async {
  //   try {
  //     if (_currentUserName == null || _messages.isEmpty) return;
  //     final ids = _messages
  //         .where((m) => !m.isMe && m.apiMessageId != null)
  //         .map((m) => m.apiMessageId!)
  //         .toList();
  //     if (ids.isEmpty) return;
  //     await FirebaseApiService.markMessagesAsRead(widget.contact.chatUuid, ids);
  //   } catch (_) {}
  // }
Future<void> _markMessagesAsRead() async {
  try {
    if (_currentUserName == null || _messages.isEmpty) return;

    final ids = <String>[];

    for (final m in _messages) {
      if (m.isMe) continue;

      // Add the top-level message ID
      if (m.apiMessageId != null) {
        ids.add(m.apiMessageId!);
      }

      // ── FIX: Also add each individual image's messageId from grouped attachments ──
      // Grouped images are collapsed into one ChatMessage but each has its own
      // server messageId stored in AttachmentItem.messageId — those were being skipped.
      for (final attachment in m.groupedAttachments) {
        if (attachment.messageId != null &&
            attachment.messageId != m.apiMessageId) {
          ids.add(attachment.messageId!);
        }
      }
    }

    if (ids.isEmpty) return;
    await FirebaseApiService.markMessagesAsRead(widget.contact.chatUuid, ids);
  } catch (_) {}
}
  // ─── @mentions ──────────────────────────────────────────────────────────────

  /// Longest names first, so "@John Smith" wins over a member also called
  /// "John" when both could match the same text.
  List<GroupMember> get _mentionableMembers {
    final list = _groupMembers
        .where((m) => m.name.isNotEmpty && m.userUuid != _currentUserUuid)
        .toList();
    list.sort((a, b) => b.name.length.compareTo(a.name.length));
    return list;
  }

  void _hideMentionSuggestions() {
    if (_mentionAnchor == null && _mentionSuggestions.isEmpty) return;
    setState(() {
      _mentionAnchor = null;
      _mentionSuggestions = [];
    });
  }

  /// Works out whether the caret sits inside an "@..." token and, if so, which
  /// members match what has been typed so far.
  void _onComposerChanged(String value) {
    if (!widget.isGroup || _groupMembers.isEmpty) return;

    final selection = _messageController.selection;
    final caret = selection.baseOffset;
    if (!selection.isCollapsed || caret < 0 || caret > value.length) {
      _hideMentionSuggestions();
      return;
    }

    final before = value.substring(0, caret);
    final at = before.lastIndexOf('@');
    // Only a fresh word starts a mention, so "email@host" never triggers one.
    if (at == -1 || (at > 0 && !RegExp(r'\s').hasMatch(before[at - 1]))) {
      _hideMentionSuggestions();
      return;
    }

    final query = before.substring(at + 1);
    // Names may contain spaces, so the query does too — but a newline or a
    // long run of text means the user has moved on from the mention.
    if (query.contains('\n') || query.length > 24) {
      _hideMentionSuggestions();
      return;
    }

    final lower = query.toLowerCase();
    final matches = _mentionableMembers
        .where((m) => m.name.toLowerCase().contains(lower))
        .toList();

    if (matches.isEmpty) {
      _hideMentionSuggestions();
      return;
    }
    setState(() {
      _mentionAnchor = at;
      _mentionSuggestions = matches;
    });
  }

  /// Swaps the half-typed "@que" for the full "@Name " and remembers who was
  /// picked, so the uuid can be sent even though the text only carries a name.
  void _insertMention(GroupMember member) {
    final anchor = _mentionAnchor;
    if (anchor == null) return;

    final text = _messageController.text;
    final caret = _messageController.selection.baseOffset;
    if (caret < anchor || caret > text.length) return;

    final token = '@${member.name} ';
    final head = text.substring(0, anchor) + token;
    final newText = head + text.substring(caret);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: head.length),
    );

    setState(() {
      _pickedMentions[member.userUuid] = member;
      _mentionAnchor = null;
      _mentionSuggestions = [];
    });
    _syncMentionHighlights();
  }

  /// Keeps the composer's highlighted names in step with what has been picked.
  void _syncMentionHighlights() {
    _messageController.mentionNames
      ..clear()
      ..addAll(_pickedMentions.values.map((m) => m.name).where((n) => n.isNotEmpty));
    _messageController.refreshHighlights();
  }

  /// The picked mentions still present in [text], in the wire format the
  /// backend wants. Someone the user picked and then deleted drops out here.
  List<Map<String, dynamic>> _mentionsIn(String text) {
    return _pickedMentions.values
        .where((m) => text.contains('@${m.name}'))
        .map((m) => {'userUuid': m.userUuid, 'appType': m.appType})
        .toList();
  }

  /// [text] with every picked "@Name" taken out — that is what goes on the
  /// wire. Who was named travels in `mentionedUserIds` instead, and the bubble
  /// redraws the name from the roster, so the stored text stays clean and a
  /// later rename cannot leave a stale name behind in it.
  String _stripPickedMentions(String text) {
    // Longest name first, so "@John Smith" is removed whole instead of
    // "@John" going and leaving " Smith" behind.
    final byLength = _pickedMentions.values.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    var out = text;
    for (final member in byLength) {
      if (member.name.isEmpty) continue;
      // The trailing space belongs to the token — dropping it too keeps
      // "hi @John ok" as "hi ok" rather than "hi  ok".
      out = out.replaceAll('@${member.name} ', '');
      out = out.replaceAll('@${member.name}', '');
    }
    return out.trim();
  }

  /// The people named in [message] whose "@Name" is no longer in its text.
  ///
  /// Sent text carries no "@Name" at all — only `mentions` says who was named
  /// — so the names are rebuilt from the roster and drawn ahead of the text.
  /// Older messages that still have the name inline are skipped here, since
  /// the inline highlighter already draws those.
  List<GroupMember> _rebuiltMentions(ChatMessage message) {
    if (message.mentions.isEmpty || _groupMembers.isEmpty) return const [];

    final out = <GroupMember>[];
    for (final mention in message.mentions) {
      for (final member in _groupMembers) {
        if (member.name.isEmpty ||
            member.appType != mention.appType ||
            member.userUuid.toLowerCase() != mention.userUuid.toLowerCase()) {
          continue;
        }
        if (!message.text.contains('@${member.name}')) out.add(member);
        break;
      }
    }
    return out;
  }

  /// One "@Name" chip. Being named yourself is worth spotting in a busy
  /// group, so it sits in a rounded tint rather than just reading blue.
  InlineSpan _mentionSpan(
    String label,
    String userUuid,
    TextStyle baseStyle, {
    required bool onGreen,
  }) {
    final style = baseStyle.copyWith(
      color: onGreen ? _kMentionColorOnGreen : _kMentionColor,
      fontWeight: FontWeight.bold,
    );

    final isMe = _currentUserUuid != null &&
        userUuid.toLowerCase() == _currentUserUuid!.toLowerCase();
    if (!isMe) return TextSpan(text: label, style: style);

    // A span's backgroundColor can only be a hard rectangle, so the pill is a
    // widget instead.
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: onGreen
              ? Colors.white.withValues(alpha: 0.25)
              : _kMentionColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: style),
      ),
    );
  }

  // ─── Links ──────────────────────────────────────────────────────────────────

  /// Endings a bare "academy.bcqr.lk" is allowed to have. A written-out
  /// scheme or a leading "www." is linkified whatever it ends in, but a bare
  /// domain needs one of these — otherwise "etc.the" in a sentence someone
  /// forgot to put a space in becomes a link.
  static const String _linkTlds =
      'com|net|org|edu|gov|int|mil|info|biz|io|ai|app|dev|me|co|tv|fm|gg|xyz|'
      'site|online|store|shop|blog|news|link|page|tech|cloud|live|pro|top|'
      'lk|uk|us|ca|au|nz|in|pk|bd|np|mv|sg|my|th|vn|ph|id|hk|tw|kr|jp|cn|'
      'ae|sa|qa|kw|om|bh|za|ke|ng|eg|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|'
      'ie|pt|pl|cz|gr|tr|ru|ua|br|mx|ar|cl|eu';

  /// Matches, in order: anything with a scheme or a leading "www.", an email
  /// address, and a bare domain ending in [_linkTlds] with an optional path.
  static final RegExp _linkPattern = RegExp(
    r'(?:https?://|www\.)[^\s<>"]+'
    r'|[\w.+-]+@[\w-]+(?:\.[\w-]+)+'
    r'|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
    '(?:$_linkTlds)'
    r'(?![a-zA-Z0-9])(?:[/?#][^\s<>"]*)?',
    caseSensitive: false,
  );

  /// Punctuation a link picks up from the sentence around it: "see
  /// https://academy.bcqr.lk." must not open a url ending in a full stop.
  static String _trimLinkTail(String link) {
    var end = link.length;
    while (end > 0) {
      final ch = link[end - 1];
      if ('.,;:!?"\''.contains(ch)) {
        end--;
        continue;
      }
      // A closing bracket only comes off when nothing inside the link opened
      // it — some urls really do end in one.
      if (ch == ')' || ch == ']' || ch == '}') {
        final open = ch == ')' ? '(' : (ch == ']' ? '[' : '{');
        final body = link.substring(0, end);
        if (body.split(open).length < body.split(ch).length) {
          end--;
          continue;
        }
      }
      break;
    }
    return link.substring(0, end);
  }

  /// What a tap actually opens. Text carries a domain far more often than a
  /// full url, so a missing scheme is assumed to be https, and an address
  /// with an @ in it is a mailto.
  static Uri? _linkUri(String raw) {
    final trimmed = _trimLinkTail(raw);
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed)) {
      return Uri.tryParse(trimmed);
    }
    if (trimmed.contains('@')) return Uri.tryParse('mailto:$trimmed');
    return Uri.tryParse('https://$trimmed');
  }

  Future<void> _openLink(String raw) async {
    final uri = _linkUri(raw);
    if (uri == null) {
      _showErrorSnack('That link is not valid.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showErrorSnack('Could not open $raw');
    } catch (_) {
      if (mounted) _showErrorSnack('Could not open $raw');
    }
  }

  /// One recognizer per distinct link, because a [TextSpan]'s recognizer has
  /// to outlive the build that made it and has to be disposed by hand — a
  /// fresh one per build would leak on every rebuild of the list.
  final Map<String, TapGestureRecognizer> _linkRecognizers = {};

  TapGestureRecognizer _linkRecognizer(String link) =>
      _linkRecognizers.putIfAbsent(
        link,
        () => TapGestureRecognizer()..onTap = () => _openLink(link),
      );

  /// Message text split into tappable links and everything else, with the
  /// runs in between still going through the search highlighter.
  List<InlineSpan> _linkAwareSpans(
    String text,
    TextStyle baseStyle, {
    required bool onGreen,
  }) {
    if (text.isEmpty) return _searchHighlightedSpans(text, baseStyle);

    final linkColor = onGreen ? _kLinkColor : _kLinkColor;
    final linkStyle = baseStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _linkPattern.allMatches(text)) {
      // A match that starts inside the previous link (its trimmed tail) is
      // already covered.
      if (match.start < last) continue;
      final link = _trimLinkTail(text.substring(match.start, match.end));
      if (link.isEmpty) continue;
      if (match.start > last) {
        spans.addAll(
          _searchHighlightedSpans(
            text.substring(last, match.start),
            baseStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: link,
          style: linkStyle,
          recognizer: _linkRecognizer(link),
        ),
      );
      last = match.start + link.length;
    }

    if (spans.isEmpty) return _searchHighlightedSpans(text, baseStyle);
    if (last < text.length) {
      spans.addAll(_searchHighlightedSpans(text.substring(last), baseStyle));
    }
    return spans;
  }

  /// A message bubble's text: the "@Name" chips rebuilt from `mentions` first,
  /// then the text itself with any inline "@Name" still in it drawn in bold.
  Widget _buildMessageText(ChatMessage message, TextStyle baseStyle) {
    final text = message.text;
    final onGreen = message.isMe;
    final rebuilt = _rebuiltMentions(message);
    if (rebuilt.isEmpty) {
      return _buildInlineMentionText(text, baseStyle, onGreen: onGreen);
    }

    final spans = <InlineSpan>[];
    for (var i = 0; i < rebuilt.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: baseStyle));
      spans.add(
        _mentionSpan(
          '@${rebuilt[i].name}',
          rebuilt[i].userUuid,
          baseStyle,
          onGreen: onGreen,
        ),
      );
    }
    if (text.isNotEmpty) {
      spans.add(TextSpan(text: ' ', style: baseStyle));
      spans.addAll(_inlineMentionSpans(text, baseStyle, onGreen: onGreen) ??
          _linkAwareSpans(text, baseStyle, onGreen: onGreen));
    }
    return RichText(text: TextSpan(children: spans));
  }

  /// Message text with any "@Name" that matches a current group member drawn
  /// in bold. Matching against the roster rather than a server field means
  /// both sent and received messages highlight without extra payload.
  Widget _buildInlineMentionText(
    String text,
    TextStyle baseStyle, {
    required bool onGreen,
  }) {
    final spans = _inlineMentionSpans(text, baseStyle, onGreen: onGreen);
    if (spans == null) {
      return RichText(
        text: TextSpan(
          children: _linkAwareSpans(text, baseStyle, onGreen: onGreen),
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }

  /// The spans for [text] with its inline "@Name"s highlighted, or null when there
  /// is no mention in it to highlight.
  List<InlineSpan>? _inlineMentionSpans(
    String text,
    TextStyle baseStyle, {
    required bool onGreen,
  }) {
    if (!widget.isGroup || _groupMembers.isEmpty || !text.contains('@')) {
      return null;
    }

    // Longest first so "@John Smith" is preferred over a member named "John".
    final byLength = _groupMembers.where((m) => m.name.isNotEmpty).toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    final spans = <InlineSpan>[];
    final plain = StringBuffer();
    var i = 0;
    var matched = false;

    void flush() {
      if (plain.isEmpty) return;
      spans.addAll(
        _linkAwareSpans(plain.toString(), baseStyle, onGreen: onGreen),
      );
      plain.clear();
    }

    while (i < text.length) {
      if (text[i] == '@') {
        final rest = text.substring(i + 1).toLowerCase();
        GroupMember? hit;
        for (final member in byLength) {
          if (rest.startsWith(member.name.toLowerCase())) {
            hit = member;
            break;
          }
        }
        if (hit != null) {
          flush();
          spans.add(
            _mentionSpan(
              text.substring(i, i + 1 + hit.name.length),
              hit.userUuid,
              baseStyle,
              onGreen: onGreen,
            ),
          );
          i += 1 + hit.name.length;
          matched = true;
          continue;
        }
      }
      plain.write(text[i]);
      i++;
    }

    if (!matched) return null;
    flush();
    return spans;
  }

  /// True when this message names the signed-in user. Read from the server's
  /// `mentions` rather than the text, so a rename or a "@Name" someone typed
  /// by hand cannot produce a false positive.
  bool _mentionsMe(ChatMessage message) =>
      !message.isMe &&
      message.mentionsUser(_currentUserUuid, FirebaseApiService.appType);

  Widget _buildMentionSuggestions(FontSettings fontSettings) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final member = _mentionSuggestions[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: member.avatarColor,
              child: Text(
                member.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSettings.fontSize - 5,
                ),
              ),
            ),
            title: Text(
              member.name,
              style: TextStyle(
                fontSize: fontSettings.fontSize - 2,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            trailing: member.isAdmin
                ? Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: fontSettings.fontSize - 5,
                    ),
                  )
                : null,
            onTap: () => _insertMention(member),
          );
        },
      ),
    );
  }

  // ─── Send text ──────────────────────────────────────────────────────────────

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Exit selection mode if active
    if (_isSelectionMode) {
      setState(() {
        _selectedMessageIds.clear();
        _reactionTargetId = null;
      });
    }

    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    // Taken before the composer is cleared, so the optimistic bubble and the
    // request agree on what is being quoted.
    final replyTo = _replyingTo;
    // Resolved before the composer is cleared — the text is what decides which
    // picked mentions actually survived.
    final mentions = _mentionsIn(text);
    // The "@Name" itself never goes on the wire — `mentions` says who was
    // named and the bubble redraws the name. A mention with nothing else
    // typed keeps the name, so there is still something to send.
    final stripped = _stripPickedMentions(text);
    final outgoing = mentions.isEmpty || stripped.isEmpty ? text : stripped;

    // Groups always use POST /api/chats/:chatId/messages. A 1:1 message
    // normally goes through send-message-with-notification instead (that is
    // what pushes to the recipient), but that endpoint does not persist
    // replyToMessageId — the quote came back null on the next fetch — so a
    // 1:1 *reply* is sent on the chat endpoint, which does store it.
    final viaChatEndpoint = widget.isGroup || replyTo != null;

    setState(() {
      _messages.add(
        ChatMessage(
          id: localId,
          text: outgoing,
          isMe: true,
          timestamp: now,
          isRead: false,
          replyToMessageId: replyTo?.apiMessageId,
          replyToText: replyTo == null ? null : _quotedPreviewText(replyTo),
          replyToSenderName: replyTo == null ? null : _senderLabel(replyTo),
          mentions: mentions
              .map(
                (m) => MessageMention(
                  userUuid: m['userUuid'] as String,
                  appType: m['appType'] as int,
                ),
              )
              .toList(),
        ),
      );
      _replyingTo = null;
    });
    _messageController.clear();
    _pickedMentions.clear();
    _syncMentionHighlights();
    _hideMentionSuggestions();
    if (widget.onMessageSent != null) widget.onMessageSent!(outgoing);

    try {
      final response = viaChatEndpoint
          ? await FirebaseApiService.sendChatMessage(
              chatId: widget.contact.chatUuid,
              text: outgoing,
              replyToMessageId: replyTo?.apiMessageId,
              mentionedUserIds: mentions.isEmpty ? null : mentions,
            )
          : await FirebaseApiService.sendMessage(
              recipientUuid: widget.contact.userUuid,
              message: outgoing,
              title: _currentUserName ?? '',
              body: outgoing,
              chatId: widget.contact.chatUuid,
              recipientAppType: widget.contact.appType,
            );
      if (response['success'] == true) {
        final rd = response['data'];
        if (rd != null && rd['success'] == true && rd['data'] != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == localId);
            if (idx != -1) {
              _messages[idx] = _messages[idx].copyWith(
                apiMessageId: rd['data']['messageId'],
                apiChatId: rd['data']['chatId'],
                isRead: false,
              );
            }
          });
        }
        // The chat endpoint answers with the created message at the top
        // level, so pick the ids up from there when they are not nested.
        if (viaChatEndpoint && rd is Map && rd['messageId'] != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == localId);
            if (idx != -1) {
              _messages[idx] = _messages[idx].copyWith(
                apiMessageId: rd['messageId']?.toString(),
                apiChatId: widget.contact.chatUuid,
                isRead: false,
              );
            }
          });
        }
        if (viaChatEndpoint) {
          // Pull the server copy so the message carries its real id.
          _fetchMessagesFromApi(silent: true);
        }
      } else {
        _showErrorSnack('Failed to send message. Please try again.');
      }
    } catch (_) {
      _showErrorSnack('Error sending message.');
    }
  }

  // ─── Upload files ───────────────────────────────────────────────────────────

  Future<void> _uploadAndSendFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    final now = DateTime.now();
    final localId = now.millisecondsSinceEpoch.toString();

    final imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    final localItems = filePaths.map((p) {
      final ext = p.split('.').last.toLowerCase();
      return AttachmentItem(
        localPath: p,
        fileName: p.split('/').last,
        mimeType: imageExts.contains(ext) ? 'image/$ext' : null,
      );
    }).toList();

    final allImages = localItems.every((a) => a.isImage);

    setState(() {
      _isUploading = true;
      if (allImages && localItems.length > 1) {
        _messages.add(
          ChatMessage(
            id: localId,
            text: '',
            isMe: true,
            timestamp: now,
            isRead: false,
            groupedAttachments: localItems,
          ),
        );
      } else {
        for (int i = 0; i < localItems.length; i++) {
          final item = localItems[i];
          final ext = (item.localPath ?? '').split('.').last.toLowerCase();
          _messages.add(
            ChatMessage(
              id: '${localId}_$i',
              text: item.fileName ?? '',
              isMe: true,
              timestamp: now,
              isRead: false,
              filePath: item.localPath,
              fileType: item.isImage ? 'image' : 'document',
              fileName: item.fileName,
              groupedAttachments: item.isImage ? [item] : [],
            ),
          );
        }
      }
    });
    _scrollToBottom();

    try {
      final result = await FirebaseApiService.uploadFiles(
        chatId: widget.contact.chatUuid,
        filePaths: filePaths,
      );

      if (result['success'] == true) {
        final files = (result['data']['files'] as List<dynamic>?) ?? [];

        setState(() {
          if (allImages && localItems.length > 1) {
            final idx = _messages.indexWhere((m) => m.id == localId);
            if (idx != -1) {
              final updatedItems = <AttachmentItem>[];
              for (int i = 0; i < localItems.length; i++) {
                final f = i < files.length
                    ? files[i] as Map<String, dynamic>
                    : <String, dynamic>{};
                updatedItems.add(
                  localItems[i].copyWith(
                    url: f['url'] as String?,
                    messageId: f['messageId'] as String?,
                    mimeType: f['type'] as String?,
                    fileName: f['filename'] as String?,
                  ),
                );
              }
              _messages[idx] = _messages[idx].copyWith(
                apiMessageId: files.isNotEmpty
                    ? files[0]['messageId'] as String?
                    : null,
                apiChatId: widget.contact.chatUuid,
                groupedAttachments: updatedItems,
                isRead: false,
              );
            }
          } else {
            for (int i = 0; i < filePaths.length; i++) {
              final bubbleId = '${localId}_$i';
              final idx = _messages.indexWhere((m) => m.id == bubbleId);
              if (idx != -1 && i < files.length) {
                final f = files[i] as Map<String, dynamic>;
                final mime = f['type'] as String? ?? '';
                final isImg = mime.startsWith('image/');
                _messages[idx] = _messages[idx].copyWith(
                  apiMessageId: f['messageId'] as String?,
                  apiChatId: widget.contact.chatUuid,
                  attachmentUrl: f['url'] as String?,
                  attachmentType: mime,
                  fileType: isImg ? 'image' : 'document',
                  fileName: f['filename'] as String?,
                  groupedAttachments: isImg
                      ? [
                          AttachmentItem(
                            url: f['url'] as String?,
                            mimeType: mime,
                            fileName: f['filename'] as String?,
                            messageId: f['messageId'] as String?,
                          ),
                        ]
                      : [],
                  isRead: false,
                );
              }
            }
          }
          _isUploading = false;
        });

        if (widget.onMessageSent != null) {
          widget.onMessageSent!('📎 ${filePaths.length} file(s) sent');
        }

        // ── FIX: Give the server a moment to index the upload, then sync ──
        // This ensures the next silent fetch sees the confirmed messages,
        // so the merge logic above can match them and drop the local copies.
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _fetchMessagesFromApi(silent: true);
        });
      } else {
        setState(() => _isUploading = false);
        _showErrorSnack('Upload failed: ${result['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showErrorSnack('Upload error: $e');
    }
  }

  // ─── Pickers ────────────────────────────────────────────────────────────────

  void _onCameraPressed() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: _kImageQuality,
        maxWidth: _kImageMaxDimension,
        maxHeight: _kImageMaxDimension,
      );
      if (photo != null) await _uploadAndSendFiles([photo.path]);
    } catch (e) {
      _showErrorSnack('Error taking photo: $e');
    }
  }

  void _onAttachFilePressed() async {
    // Checked up front so the sheet only offers Paste when there is actually
    // an image waiting on the clipboard.
    final bool clipboardHasImage = await ImageClipboard.hasImage();
    if (!mounted) return;

    final fontSettings = ref.read(fontSettingsProvider);
    final optionStyle = TextStyle(
      fontSize: fontSettings.fontSize - 2,
      fontWeight: fontSettings.fontWeight,
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
             if (clipboardHasImage)
              ListTile(
                leading: const Icon(Icons.content_paste, color: Colors.green),
                title: Text('Paste image', style: optionStyle),
                onTap: () {
                  Navigator.pop(ctx);
                  _pasteImageFromClipboard();
                },
              ),
            if (clipboardHasImage)
              Container(
                width: MediaQuery.of(ctx).size.width,
                height: 1,
                color: Colors.black,
              ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text('Gallery', style: optionStyle),
              onTap: () {
                Navigator.pop(ctx);
                _pickImagesFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: Colors.orange,
              ),
              title: Text('Document', style: optionStyle),
              onTap: () {
                Navigator.pop(ctx);
                _pickDocuments();
              },
            ),
           
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text('Cancel', style: optionStyle),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: _kImageQuality,
        maxWidth: _kImageMaxDimension,
        maxHeight: _kImageMaxDimension,
      );
      if (images.isNotEmpty) {
        await _uploadAndSendFiles(images.map((x) => x.path).toList());
      }
    } catch (e) {
      _showErrorSnack('Error selecting image: $e');
    }
  }

  /// Sends whatever image is sitting on the clipboard, through the same
  /// upload path as a file picked from the gallery.
  Future<void> _pasteImageFromClipboard() async {
    try {
      final path = await ImageClipboard.pasteImageToFile();
      if (path == null) {
        _showErrorSnack('No image on the clipboard');
        return;
      }
      await _uploadAndSendFiles([path]);
    } catch (e) {
      _showErrorSnack('Error pasting image: $e');
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final paths = result.files
            .map((f) => f.path!)
            .where((p) => p.isNotEmpty)
            .toList();
        await _uploadAndSendFiles(paths);
      }
    } catch (e) {
      _showErrorSnack('Error selecting document: $e');
    }
  }

  // ─── Multi-select helpers ───────────────────────────────────────────────────

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      // A reaction is one message's business: the moment the selection is no
      // longer exactly the message the emoji row was opened for, the row goes.
      // The long-press path re-opens it right after this call.
      if (_reactionTargetId != null &&
          (_selectedMessageIds.length != 1 ||
              !_selectedMessageIds.contains(_reactionTargetId))) {
        _reactionTargetId = null;
      }
    });
  }

  void _selectAll() {
    setState(() {
      // System notices cannot be replied to, forwarded or deleted, so they
      // stay out of the selection.
      _selectedMessageIds.addAll(
        _messages.where((m) => !m.isSystem).map((m) => m.id),
      );
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
      _reactionTargetId = null;
    });
  }

  /// One button in the selection action bar. Compact by design — the bar
  /// carries up to four of these plus the count.
  Widget _selectionAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required FontSettings fontSettings,
    bool destructive = false,
  }) {
    final labelStyle = TextStyle(fontSize: fontSettings.fontSize - 3);
    final padding = const EdgeInsets.symmetric(horizontal: 10);
    // Picking any action means the user is done reacting, so the emoji half
    // of the panel goes right away — the actions themselves finish (and drop
    // the selection) asynchronously.
    void handlePress() {
      _closeReactionPicker();
      onPressed();
    }

    if (destructive) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: padding,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: handlePress,
        icon: Icon(icon, size: 18),
        label: Text(label, style: labelStyle),
      );
    }

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.green,
        padding: padding,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: handlePress,
      icon: Icon(icon, size: 18),
      label: Text(label, style: labelStyle),
    );
  }

  // ─── Reply ──────────────────────────────────────────────────────────────────

  /// Who sent [msg], as shown on a quoted preview.
  String _senderLabel(ChatMessage msg) {
    if (msg.isMe) return 'You';
    final name = msg.senderName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return widget.contact.name;
  }

  /// One-line stand-in for a message inside a quote block.
  ///
  /// Attachment messages carry an upload placeholder as their text
  /// ("📎 scaled_b7edf13a-….jpg"), which reads as noise in a quote — so
  /// describe the attachment instead.
  String _quotedPreviewText(ChatMessage msg) {
    if (msg.hasGroupedAttachments) {
      final count = msg.groupedAttachments.length;
      if (msg.isImageGroup) return count > 1 ? '\$count photos' : 'Photo';
      return count > 1 ? '\$count attachments' : 'Attachment';
    }
    if (msg.fileType == 'image') return 'Photo';
    if (msg.fileType != null) return msg.fileName ?? 'Attachment';
    return _quoteTextOrAttachmentLabel(msg.text);
  }

  /// Same tidy-up for a quote the server sent back: `replyToText` is a
  /// snapshot of the original's text, so an attachment original arrives as the
  /// "📎 filename" placeholder with no attachment metadata alongside it.
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  };

  String _quoteTextOrAttachmentLabel(String? raw) {
    final text = raw?.trim() ?? '';
    if (!text.startsWith('📎')) return text.isEmpty ? 'Message' : text;

    final fileName = text.substring('📎'.length).trim();
    if (fileName.isEmpty) return 'Attachment';
    return _imageExtensions.contains(fileName.split('.').last.toLowerCase())
        ? 'Photo'
        : fileName;
  }

  /// Only messages the server already knows about can be quoted — the backend
  /// rejects a replyToMessageId it cannot find in this chat.
  bool _canReplyTo(ChatMessage msg) => !msg.isSystem && msg.apiMessageId != null;

  // ─── Reactions ──────────────────────────────────────────────────────────────

  /// Emojis offered by the double-tap picker. One reaction per person, so this
  /// is a pick-one row rather than a multi-select.
  static const List<String> _reactionEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  /// A message can be reacted to once the server knows about it — an
  /// optimistic bubble still waiting for its messageId has nothing to react
  /// to yet.
  bool _canReactTo(ChatMessage msg) =>
      msg.apiMessageId != null && msg.apiChatId != null;

  /// The message whose emoji row is open, or null when no row is showing.
  ///
  /// The row is drawn inline above the selection action bar instead of in a
  /// modal sheet, so reacting no longer covers the reply/edit/copy/forward/
  /// delete bar — both sit at the same level, stacked above the bottom edge.
  String? _reactionTargetId;

  /// Long-press and double-tap both land here; [_buildReactionBar] draws the
  /// row itself as part of the normal layout.
  void _showReactionPicker(ChatMessage message) {
    if (!_canReactTo(message)) return;
    HapticFeedback.lightImpact();
    setState(() => _reactionTargetId = message.id);
  }

  void _closeReactionPicker() {
    if (_reactionTargetId == null) return;
    setState(() => _reactionTargetId = null);
  }

  /// The message whose emoji row is open, or null when nothing is targeted
  /// or the target has left the conversation since it was picked.
  ChatMessage? get _reactionTarget {
    final id = _reactionTargetId;
    if (id == null) return null;
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return null;
    final message = _messages[index];
    return _canReactTo(message) ? message : null;
  }

  /// The one bar above the composer: the emoji row and the selection actions
  /// share a single card, so reacting and reply/edit/copy/forward/delete read
  /// as one surface instead of two stacked sheets. Either half can be absent —
  /// a double-tap opens the emoji row on its own, and selecting without
  /// reacting shows only the actions.
  Widget _buildBottomActionPanel(FontSettings fontSettings) {
    final target = _reactionTarget;
    if (target == null && !_isSelectionMode) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null) _buildReactionRow(target, fontSettings),
          // Only when both halves are showing — the card stays one surface,
          // the rule just keeps the emoji row off the action labels.
          if (target != null && _isSelectionMode)
            Divider(
              height: 14,
              thickness: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
          if (_isSelectionMode) ...[
            Text(
              '${_selectedMessageIds.length} message'
              '${_selectedMessageIds.length > 1 ? 's' : ''} selected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: fontSettings.fontSize - 3,
              ),
            ),
            const SizedBox(height: 6),
            // Wrapped rather than a Row: five actions at a large font size do
            // not fit one line on a narrow phone.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                if (_selectedMessageIds.length == 1)
                  _selectionAction(
                    icon: Icons.reply,
                    label: 'Reply',
                    onPressed: _replyToSelectedMessage,
                    fontSettings: fontSettings,
                  ),
                if (_editableSelection != null)
                  _selectionAction(
                    icon: Icons.edit,
                    label: 'Edit',
                    onPressed: _editSelectedMessage,
                    fontSettings: fontSettings,
                  ),
                _selectionAction(
                  icon: Icons.copy,
                  label: 'Copy',
                  onPressed: _copySelectedMessages,
                  fontSettings: fontSettings,
                ),
                _selectionAction(
                  icon: Icons.forward,
                  label: 'Forward',
                  onPressed: _forwardSelectedMessages,
                  fontSettings: fontSettings,
                ),
                _selectionAction(
                  icon: Icons.delete,
                  label: 'Delete',
                  onPressed: _deleteSelectedMessages,
                  fontSettings: fontSettings,
                  destructive: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The emoji half of the panel. The emoji this user already has is ringed,
  /// and tapping it again removes it — the same toggle the backend applies.
  Widget _buildReactionRow(ChatMessage message, FontSettings fontSettings) {
    final mine = message.reactionOf(
      _currentUserUuid,
      FirebaseApiService.appType,
    );

    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _reactionEmojis.map((emoji) {
              final isMine = emoji == mine;
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  // The long-press that opened this also selected the
                  // message; reacting is the whole action, so let it go.
                  _closeReactionPicker();
                  _clearSelection();
                  _toggleReaction(message, emoji);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMine ? Colors.green.withOpacity(0.15) : null,
                  ),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: fontSettings.fontSize + 10),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Selection mode already has the app bar's close to back out of, so
        // the extra one would only be ambiguous inside the shared card.
        if (!_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
            tooltip: 'Close',
            onPressed: _closeReactionPicker,
          ),
      ],
    );
  }

  /// Applies the toggle locally first so the chip appears under the thumb,
  /// then tells the server. A rejected call (the message was deleted, the
  /// network is down) puts the old reactions back and says so.
  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    if (!_canReactTo(message)) return;
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    final previous = _messages[index].reactions;
    final mine = _messages[index].reactionOf(
      _currentUserUuid,
      FirebaseApiService.appType,
    );

    // Same emoji removes it, a different one replaces it — mirror of what the
    // backend does, so the optimistic list matches what comes back.
    final next = previous
        .where((r) => !r.matches(_currentUserUuid, FirebaseApiService.appType))
        .toList();
    if (mine != emoji && (_currentUserUuid ?? '').isNotEmpty) {
      next.add(MessageReaction(
        userUuid: _currentUserUuid!,
        appType: FirebaseApiService.appType,
        emoji: emoji,
      ));
    }

    setState(() {
      _messages[index] = _messages[index].copyWith(reactions: next);
    });

    final response = await FirebaseApiService.reactToMessage(
      chatId: message.apiChatId!,
      messageId: message.apiMessageId!,
      emoji: emoji,
    );

    if (!mounted) return;
    if (response['success'] == true) {
      // The other participants are told over push; pull the authoritative
      // list back so a reaction that landed at the same time is not lost.
      _fetchMessagesFromApi(silent: true);
      return;
    }

    // The message may have been deleted under us — the list is refetched
    // either way, but the bubble should not keep a reaction the server
    // refused.
    final revertIndex = _messages.indexWhere((m) => m.id == message.id);
    if (revertIndex != -1) {
      setState(() {
        _messages[revertIndex] =
            _messages[revertIndex].copyWith(reactions: previous);
      });
    }
    _showErrorSnack(
      response['statusCode'] == 400
          ? 'This message is no longer available.'
          : 'Could not save your reaction.',
    );
  }

  /// The summary pill under a bubble: every emoji on the message in one
  /// rounded pill with the total count, the way WhatsApp shows it. Tapping it
  /// opens the per-person breakdown, where this user's own reaction can be
  /// taken back.
  Widget _buildReactionPill(ChatMessage message, FontSettings fontSettings) {
    final counts = message.reactionCounts;
    if (counts.isEmpty) return const SizedBox.shrink();
    final total = message.reactions.length;

    // Pulled up so the pill overlaps the bottom edge of the bubble instead of
    // floating under it — it is drawn after the bubble, so it sits on top.
    return Transform.translate(
      offset: const Offset(0, -12),
      // heightFactor claims only half the pill's height in the column, so the
      // half that lies over the bubble does not also push the next message
      // down — the row keeps its normal spacing.
      child: Align(
        alignment: message.isMe ? Alignment.topRight : Alignment.topLeft,
        widthFactor: 1,
        heightFactor: 0.5,
        child: Padding(
          padding: EdgeInsets.only(
            left: message.isMe ? 4 : 12,
            right: message.isMe ? 12 : 4,
          ),
          child: GestureDetector(
            onTap:
                _isSelectionMode ? null : () => _showReactionDetails(message),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                // A ring the colour of the chat ground keeps the pill legible
                // where it crosses the bubble.
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // One of each distinct emoji, in the order it was first
                  // used, so the pill does not reshuffle as people react.
                  ...counts.keys.map(
                    (emoji) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: fontSettings.fontSize - 2),
                      ),
                    ),
                  ),
                  // A lone reaction reads fine as just the emoji.
                  if (total > 1)
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: fontSettings.fontSize - 4,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Who reacted, in the order the sheet lists them: this user first, then
  /// everyone else as the backend returned them.
  List<MessageReaction> _orderedReactions(ChatMessage message) {
    final mine = <MessageReaction>[];
    final others = <MessageReaction>[];
    for (final r in message.reactions) {
      (r.matches(_currentUserUuid, FirebaseApiService.appType) ? mine : others)
          .add(r);
    }
    return [...mine, ...others];
  }

  /// A reaction's owner. The wire format carries only a uuid, so the name is
  /// looked up in the group roster, then among the senders of messages
  /// already loaded, then — in a 1:1 chat — the other party.
  ({String name, bool isMe}) _reactorIdentity(MessageReaction reaction) {
    if (reaction.matches(_currentUserUuid, FirebaseApiService.appType)) {
      return (name: 'You', isMe: true);
    }
    final uuid = reaction.userUuid.toLowerCase();

    // The same uuid under another app is a different person, so an appType
    // match wins; a roster row without one is only a last resort.
    GroupMember? loose;
    for (final member in _groupMembers) {
      if (member.userUuid.toLowerCase() != uuid) continue;
      if (member.appType == reaction.appType) {
        return (name: member.name, isMe: false);
      }
      loose ??= member;
    }
    if (loose != null) return (name: loose.name, isMe: false);

    for (final message in _messages) {
      if ((message.senderId ?? '').toLowerCase() == uuid &&
          (message.senderName ?? '').isNotEmpty) {
        return (name: message.senderName!, isMe: false);
      }
    }

    if (!widget.isGroup &&
        widget.contact.userUuid.toLowerCase() == uuid) {
      return (name: widget.contact.name, isMe: false);
    }
    return (name: 'Unknown', isMe: false);
  }

  /// The breakdown behind the summary pill: a chip per emoji that filters the
  /// list, and a row per person. This user's own row says so — tapping it
  /// takes the reaction back, the same toggle the picker applies.
  void _showReactionDetails(ChatMessage message) {
    final fontSettings = ref.read(fontSettingsProvider);
    final reactions = _orderedReactions(message);
    if (reactions.isEmpty) return;
    final counts = message.reactionCounts;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Which emoji is being filtered on is the sheet's own business —
        // nothing outside it changes when a chip is picked.
        String? filter;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final shown = filter == null
                ? reactions
                : reactions.where((r) => r.emoji == filter).toList();

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '${reactions.length} reaction'
                        '${reactions.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Back to the emoji row, so another reaction can be
                          // picked without closing the sheet by hand.
                          _reactionFilterChip(
                            selected: false,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showReactionPicker(message);
                            },
                            child: Icon(
                              Icons.add_reaction_outlined,
                              size: fontSettings.fontSize + 2,
                              color: Colors.grey[700],
                            ),
                          ),
                          // Tapping the chip already filtering clears it, so
                          // there is always a way back to the full list.
                          ...counts.entries.map(
                            (entry) => _reactionFilterChip(
                              selected: filter == entry.key,
                              onTap: () => setSheetState(
                                () => filter =
                                    filter == entry.key ? null : entry.key,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize - 2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${entry.value}',
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize - 4,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: shown.length,
                        itemBuilder: (context, index) {
                          final reaction = shown[index];
                          final who = _reactorIdentity(reaction);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: who.isMe
                                  ? Colors.grey[400]
                                  : ChatContact.generateColorFromName(
                                      who.name,
                                    ),
                              child: who.isMe
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 22,
                                    )
                                  : Text(
                                      ChatContact.generateInitials(who.name),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: fontSettings.fontSize - 4,
                                      ),
                                    ),
                            ),
                            title: Text(
                              who.name,
                              style: TextStyle(
                                fontSize: fontSettings.fontSize - 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: who.isMe
                                ? Text(
                                    'Tap to remove',
                                    style: TextStyle(
                                      fontSize: fontSettings.fontSize - 6,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                : null,
                            trailing: Text(
                              reaction.emoji,
                              style: TextStyle(
                                fontSize: fontSettings.fontSize + 6,
                              ),
                            ),
                            // Only your own reaction is yours to remove; the
                            // sheet closes so the pill updating is visible.
                            onTap: who.isMe
                                ? () {
                                    Navigator.pop(ctx);
                                    _toggleReaction(message, reaction.emoji);
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// One chip in the sheet's emoji row — the leading add-reaction button and
  /// the per-emoji filters share the shape.
  Widget _reactionFilterChip({
    required Widget child,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.green.withOpacity(0.12)
                : Colors.grey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.green : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }


  void _startReply(ChatMessage msg) {
    setState(() {
      _replyingTo = msg;
      _selectedMessageIds.clear();
      _reactionTargetId = null;
    });
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  /// Reply from the selection bar. Quoting is one-to-one, so this is only
  /// offered while exactly one message is selected.
  void _replyToSelectedMessage() {
    if (_selectedMessageIds.length != 1) return;
    final id = _selectedMessageIds.first;
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final msg = _messages[index];
    if (!_canReplyTo(msg)) {
      _showErrorSnack('This message cannot be replied to yet.');
      return;
    }
    _startReply(msg);
  }

  // ─── Copy ──────────────────────────────────────────────────────────────

  /// Body text worth putting on the clipboard, or null when there is none.
  ///
  /// Attachment messages carry the upload placeholder as their text
  /// ("📎 scaled_b7edf13a-….jpg"), which is noise on the clipboard — so
  /// they contribute nothing and are skipped.
  String? _copyableText(ChatMessage msg) {
    if (msg.hasGroupedAttachments || msg.fileType != null) return null;
    final text = msg.text.trim();
    if (text.isEmpty || text.startsWith('📎')) return null;
    return text;
  }

  /// The one image a message carries, or null when it has none or carries
  /// several — copying just one of a grid would be a guess.
  AttachmentItem? _singleImageAttachment(ChatMessage msg) {
    if (msg.groupedAttachments.isNotEmpty) {
      if (msg.groupedAttachments.length != 1) return null;
      final item = msg.groupedAttachments.first;
      return _isImageItem(item) ? item : null;
    }
    if (msg.fileType != 'image') return null;
    if (msg.attachmentUrl == null && msg.filePath == null) return null;
    return AttachmentItem(
      url: msg.attachmentUrl,
      localPath: msg.filePath,
      fileName: msg.fileName,
      mimeType: msg.attachmentType,
    );
  }

  bool _isImageItem(AttachmentItem item) {
    final mime = item.mimeType?.toLowerCase();
    if (mime != null && mime.isNotEmpty) return mime.startsWith('image');
    final source = (item.fileName ?? item.url ?? '').toLowerCase();
    return const ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp']
        .any(source.split('?').first.endsWith);
  }

  /// Copies the selected messages to the clipboard. One message goes across as
  /// its bare text; several are stamped with time and sender so the copied
  /// block still reads as a conversation.
  Future<void> _copySelectedMessages() async {
    final selectedIds = Set<String>.from(_selectedMessageIds);

    // A lone image has no text to copy, but the picture itself can go on the
    // clipboard, so handle that before the text path calls it uncopyable.
    if (selectedIds.length == 1) {
      ChatMessage? msg;
      for (final m in _messages) {
        if (m.id == selectedIds.first) {
          msg = m;
          break;
        }
      }
      if (msg != null && _copyableText(msg) == null) {
        final image = _singleImageAttachment(msg);
        if (image != null) {
          setState(() {
            _selectedMessageIds.clear();
            _reactionTargetId = null;
          });
          await ImageClipboard.copyImage(
            context,
            url: image.url,
            localPath: image.localPath,
            fileName: image.fileName,
          );
          return;
        }
      }
    }
    // _messages is oldest-first, so this keeps the reading order.
    final copyable = <ChatMessage>[];
    for (final msg in _messages) {
      if (selectedIds.contains(msg.id) && _copyableText(msg) != null) {
        copyable.add(msg);
      }
    }

    if (copyable.isEmpty) {
      _showErrorSnack('Nothing to copy — attachments cannot be copied.');
      return;
    }

    final String payload;
    if (copyable.length == 1) {
      payload = _copyableText(copyable.first)!;
    } else {
      payload = copyable
          .map((m) => '[${_formatTime(m.timestamp)}] ${_senderLabel(m)}: '
              '${_copyableText(m)}')
          .join('\n');
    }

    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;

    setState(() {
      _selectedMessageIds.clear();
      _reactionTargetId = null;
    });

    final skipped = selectedIds.length - copyable.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copyable.length == 1
              ? 'Message copied'
              : '${copyable.length} messages copied',
        ),
        backgroundColor: skipped > 0 ? Colors.orange[800] : Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// The composer's quoted-message banner.
  Widget _buildReplyPreview(ChatMessage msg, FontSettings fontSettings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_senderLabel(msg)}',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                    fontSize: fontSettings.fontSize - 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _quotedPreviewText(msg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: fontSettings.fontSize - 3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            tooltip: 'Cancel reply',
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  /// The quoted snippet rendered inside a reply bubble.
  /// Goes to the message [message] is quoting, the way every other chat app
  /// does it. The original can be older than what is loaded, or deleted since
  /// — the quote itself is a snapshot and survives either — so a miss says so
  /// rather than doing nothing.
  void _jumpToQuotedMessage(ChatMessage message) {
    final id = message.replyToMessageId;
    if (id == null) return;
    if (_indexOfMessage(id) == -1) {
      _showErrorSnack('Original message is not available');
      return;
    }
    _scrollToMessage(id);
  }

  Widget _buildQuotedMessage(ChatMessage message, FontSettings fontSettings) {
    final onGreen = message.isMe;
    final name = message.replyToSenderName?.trim();

    final quote = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: onGreen
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: onGreen ? Colors.white : Colors.green,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (name != null && name.isNotEmpty) ? name : 'Message',
            style: TextStyle(
              color: onGreen ? Colors.white : Colors.green[800],
              fontWeight: FontWeight.bold,
              fontSize: fontSettings.fontSize - 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            // The original may have been deleted since; the server keeps a
            // snapshot of its text, so this stays readable either way.
            _quoteTextOrAttachmentLabel(message.replyToText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onGreen ? Colors.white70 : Colors.grey[800],
              fontSize: fontSettings.fontSize - 4,
            ),
          ),
        ],
      ),
    );

    // A tap on the quote jumps; a long press still falls through to the
    // bubble's own recogniser, so selecting the message keeps working.
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(message.id);
          return;
        }
        _jumpToQuotedMessage(message);
      },
      child: quote,
    );
  }

  // ─── Forward selected ───────────────────────────────────────────────────────

  /// Server-side message ids covered by [msg]. A grouped image bubble is
  /// several server messages collapsed into one, so each attachment has to be
  /// forwarded on its own.
  List<String> _forwardableIds(ChatMessage msg) {
    if (msg.hasGroupedAttachments) {
      final ids = msg.groupedAttachments
          .map((a) => a.messageId)
          .whereType<String>()
          .toList();
      if (ids.isNotEmpty) return ids;
    }
    return msg.apiMessageId == null ? const [] : [msg.apiMessageId!];
  }

  Future<void> _forwardSelectedMessages() async {
    final selectedIds = Set<String>.from(_selectedMessageIds);
    // Oldest first, so a multi-message forward lands in the reading order.
    final selectedMsgs =
        _messages.where((m) => selectedIds.contains(m.id)).toList();

    final sendable =
        selectedMsgs.where((m) => _forwardableIds(m).isNotEmpty).toList();

    if (sendable.isEmpty) {
      _showErrorSnack('These messages cannot be forwarded yet.');
      return;
    }

    final targets = await showForwardMessageSheet(
      context: context,
      fontSettings: ref.read(fontSettingsProvider),
      messageCount: sendable.length,
      excludeChatId: widget.contact.chatUuid,
      excludeUserUuid: widget.isGroup ? null : widget.contact.userUuid,
    );

    if (targets == null || targets.isEmpty || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Forwarding to ${targets.length} '
                'chat${targets.length > 1 ? 's' : ''}...'),
          ],
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: Colors.grey[800],
      ),
    );

    int delivered = 0;
    int failed = 0;
    String? firstError;

    for (final msg in sendable) {
      for (final messageId in _forwardableIds(msg)) {
        final response = await FirebaseApiService.forwardMessage(
          chatId: msg.apiChatId ?? widget.contact.chatUuid,
          messageId: messageId,
          targetChatIds: targets.chatIds,
          targetUsers: targets.users,
        );

        if (response['success'] != true) {
          failed += targets.length;
          firstError ??= _forwardErrorText(response);
          continue;
        }

        // Best-effort per target: the call can succeed while individual
        // targets are rejected, so tally the per-target results.
        final results = response['data']?['results'];
        if (results is List) {
          for (final result in results.whereType<Map>()) {
            if (result['success'] == true) {
              delivered++;
            } else {
              failed++;
              final error = result['error'];
              if (error is String && error.isNotEmpty) firstError ??= error;
            }
          }
        } else {
          delivered += targets.length;
        }
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _selectedMessageIds.clear();
      _reactionTargetId = null;
    });

    final String message;
    if (delivered == 0) {
      message = firstError ?? 'Could not forward the message.';
    } else if (failed == 0) {
      message = targets.length == 1
          ? 'Forwarded to ${targets.names.first}'
          : 'Forwarded to ${targets.length} chats';
    } else {
      message = 'Forwarded, but $failed did not go through'
          '${firstError == null ? '' : ': $firstError'}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: delivered == 0
            ? Colors.red
            : (failed == 0 ? Colors.green[700] : Colors.orange[800]),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// The backend explains a rejected forward in the error body (not a
  /// participant, admin-only group, same chat) — surface that rather than a
  /// generic failure.
  String _forwardErrorText(Map<String, dynamic> response) {
    final body = response['responseBody'];
    if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final message = decoded['error'] ?? decoded['message'];
          if (message is String && message.isNotEmpty) return message;
        }
      } catch (_) {
        // Not JSON — fall through to the generic message.
      }
    }
    return 'Could not forward the message.';
  }

  // ─── Edit selected ──────────────────────────────────────────────────────────

  /// A message the user can still correct: one of their own, plain text, known
  /// to the server, and inside the 15-minute window the backend enforces.
  /// Read-only conversations cannot be edited either.
  bool _canEditMessage(ChatMessage msg) =>
      widget.canSendMessages && msg.isEditable && msg.isWithinEditWindow();

  /// The single selected message when it is editable, otherwise null — used
  /// both to decide whether the Edit action is offered and to act on it.
  ChatMessage? get _editableSelection {
    if (_selectedMessageIds.length != 1) return null;
    final id = _selectedMessageIds.first;
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return null;
    final msg = _messages[index];
    return _canEditMessage(msg) ? msg : null;
  }

  void _editSelectedMessage() {
    final msg = _editableSelection;
    if (msg == null) {
      _showErrorSnack(
        'This message can no longer be edited — edits are allowed for '
        '${ChatMessage.editWindow.inMinutes} minutes after sending.',
      );
      return;
    }
    _showEditDialog(msg);
  }

  /// The correction sheet: the current text, pre-filled and selected, with the
  /// time left in the window spelled out so a rejected save is no surprise.
  Future<void> _showEditDialog(ChatMessage message) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditMessageDialog(
        initialText: message.text,
        windowNote: _editWindowNote(message),
        fontSettings: ref.read(fontSettingsProvider),
      ),
    );

    if (!mounted || newText == null) return;

    if (newText.isEmpty) {
      _showErrorSnack('A message cannot be left empty — delete it instead.');
      return;
    }
    // Nothing to send, but the selection has served its purpose.
    if (newText == message.text.trim()) {
      _clearSelection();
      return;
    }

    await _performEdit(message, newText);
  }

  /// "13 minutes left to edit" — rounded up, so the last stretch reads as
  /// "1 minute left" rather than "0".
  String _editWindowNote(ChatMessage message) {
    final left = message.editWindowRemaining();
    if (left == Duration.zero) return 'The time to edit this message has run out.';
    final minutes = (left.inSeconds / 60).ceil();
    return '$minutes minute${minutes == 1 ? '' : 's'} left to edit this message.';
  }

  /// Shows the new text straight away, then tells the server. A rejected edit
  /// (window closed, message deleted under us, network down) puts the original
  /// back and says why.
  Future<void> _performEdit(ChatMessage message, String newText) async {
    final index = _indexOfMessage(message.id);
    if (index == -1) return;

    final previous = _messages[index];
    setState(() {
      _messages[index] = previous.copyWith(
        text: newText,
        isEdited: true,
        editedAt: DateTime.now(),
      );
      _selectedMessageIds.clear();
      _reactionTargetId = null;
      // The composer's quoted banner holds a copy of the message, so it would
      // otherwise keep showing the text that was just replaced.
      if (_replyingTo?.id == message.id) {
        _replyingTo = _messages[index];
      }
    });

    final response = await FirebaseApiService.editMessage(
      chatId: previous.apiChatId!,
      messageId: previous.apiMessageId!,
      text: newText,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      // Others are told over push; pull the authoritative row back so the
      // server's editedAt (and anything that landed alongside) is what shows.
      _fetchMessagesFromApi(silent: true);
      return;
    }

    final revertIndex = _indexOfMessage(message.id);
    if (revertIndex != -1) {
      setState(() {
        _messages[revertIndex] = previous;
        if (_replyingTo?.id == message.id) _replyingTo = previous;
      });
    }
    _showErrorSnack(_editErrorText(response));
  }

  /// Why an edit was refused. The backend explains itself in the error body;
  /// the two statuses it uses are spelled out here because "403" on its own
  /// tells the user nothing.
  String _editErrorText(Map<String, dynamic> response) {
    final body = response['responseBody'];
    if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          final message = decoded['error'] ?? decoded['message'];
          if (message is String && message.isNotEmpty) return message;
        }
      } catch (_) {
        // Not JSON — fall through to the status-based message.
      }
    }
    switch (response['statusCode']) {
      case 403:
        return 'Only the sender can edit this message.';
      case 400:
        return 'This message can no longer be edited.';
      default:
        return 'Could not save your edit.';
    }
  }

  // ─── Delete selected ────────────────────────────────────────────────────────

  void _deleteSelectedMessages() {
    final selectedIds = List<String>.from(_selectedMessageIds);
    final selectedMsgs =
        _messages.where((m) => selectedIds.contains(m.id)).toList();
    final allMine = selectedMsgs.every((m) => m.isMe);
    final fontSettings = ref.read(fontSettingsProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text(
                    '${selectedIds.length} message${selectedIds.length > 1 ? 's' : ''} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSettings.fontSize,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Delete for Everyone (only if ALL selected are mine) ──
            if (allMine)
              ListTile(
                leading:
                    const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  'Delete for Everyone',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSettings.fontSize - 2,
                  ),
                ),
                subtitle: Text(
                  'Remove for all participants',
                  style: TextStyle(fontSize: fontSettings.fontSize - 4),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performDelete(
                    selectedMsgs: selectedMsgs,
                    selectedIds: selectedIds,
                    forEveryone: true,
                  );
                },
              ),

            // ── Delete for Me ──
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.orange),
              title: Text(
                'Delete for Me',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSettings.fontSize - 2,
                ),
              ),
              subtitle: Text(
                'Remove only from your view',
                style: TextStyle(fontSize: fontSettings.fontSize - 4),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _performDelete(
                  selectedMsgs: selectedMsgs,
                  selectedIds: selectedIds,
                  forEveryone: false,
                );
              },
            ),

            // ── Cancel ──
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: Text(
                'Cancel',
                style: TextStyle(fontSize: fontSettings.fontSize - 2),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performDelete({
    required List<ChatMessage> selectedMsgs,
    required List<String> selectedIds,
    required bool forEveryone,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Deleting ${selectedIds.length} message${selectedIds.length > 1 ? 's' : ''}...',
            ),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: Colors.grey[800],
      ),
    );

    bool hasError = false;

    for (final msg in selectedMsgs) {
      if (msg.apiChatId != null && msg.apiMessageId != null) {
        final response = forEveryone
            ? await FirebaseApiService.deleteMessageForEveryone(
                msg.apiChatId!,
                msg.apiMessageId!,
              )
            : await FirebaseApiService.softDeleteMessage(
                msg.apiChatId!,
                msg.apiMessageId!,
              );
        if (response['success'] != true) hasError = true;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      _messages.removeWhere((m) => selectedIds.contains(m.id));
      _selectedMessageIds.clear();
      _reactionTargetId = null;
      // Quoting a message that has just been deleted would be rejected on
      // send, so drop the pending reply with it.
      if (_replyingTo != null && selectedIds.contains(_replyingTo!.id)) {
        _replyingTo = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasError
              ? 'Some messages could not be deleted.'
              : forEveryone
                  ? '${selectedIds.length} message${selectedIds.length > 1 ? 's' : ''} deleted for everyone'
                  : '${selectedIds.length} message${selectedIds.length > 1 ? 's' : ''} deleted',
        ),
        backgroundColor: hasError ? Colors.red : Colors.green[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Jump to a mention ──────────────────────────────────────────────────────

  GlobalKey _keyForMessage(String id) =>
      _messageKeys.putIfAbsent(id, () => GlobalKey());

  /// The row for [messageId], matched on either id the server may have used
  /// for it, or -1 when this conversation has no such message.
  int _indexOfMessage(String messageId) => _messages.indexWhere(
        (m) => m.id == messageId || m.apiMessageId == messageId,
      );

  /// Mentions that are still ahead of the reader and actually in the loaded
  /// conversation — what the "@" button offers to jump to.
  List<String> get _reachableMentions =>
      _pendingMentions.where((id) => _indexOfMessage(id) != -1).toList();

  /// Opened from the "@" marker: land on the oldest mention instead of at the
  /// end. Answers false when there is nothing to jump to, so the caller falls
  /// back to its usual scroll.
  bool _consumeInitialMentionJump() {
    if (!widget.jumpToMentionOnOpen) return false;
    if (_initialMentionJumpDone || _reachableMentions.isEmpty) return false;
    _initialMentionJumpDone = true;
    _jumpToNextMention();
    return true;
  }

  /// Goes to the oldest mention not visited yet and takes it off the list, so
  /// tapping again walks through the rest in order.
  void _jumpToNextMention() {
    // Ids the conversation does not contain (deleted since the list scanned
    // it) would otherwise block the ones behind them.
    _pendingMentions.removeWhere((id) => _indexOfMessage(id) == -1);
    if (_pendingMentions.isEmpty) return;

    final target = _pendingMentions.removeAt(0);
    setState(() {});
    _scrollToMessage(target);
  }

  /// Brings [messageId] into view and flashes it.
  ///
  /// The list is built lazily, so a message far from the current position has
  /// no context to scroll to yet: jump to where the list estimates it sits,
  /// let that build, and look again. The estimate is drawn from the extent of
  /// the rows laid out so far, so it sharpens with every pass and normally
  /// lands within a couple of them.
  Future<void> _scrollToMessage(String messageId) async {
    final index = _indexOfMessage(messageId);
    if (index == -1) return;

    final id = _messages[index].id;
    // The list is reversed, so offset grows towards the older messages.
    final rowsFromEnd = _messages.length - 1 - index;
    final span = _messages.length - 1;

    for (var attempt = 0; attempt < 12; attempt++) {
      final ctx = _messageKeys[id]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        break;
      }
      if (!mounted) return;

      // The first pass can arrive before the list itself exists — an empty
      // conversation renders a placeholder instead — so a pass with no
      // scrollable attached simply waits for the next frame.
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final estimate = span == 0
            ? 0.0
            : position.maxScrollExtent * (rowsFromEnd / span);
        _scrollController.jumpTo(
          estimate.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      }

      // jumpTo does not always dirty anything, and endOfFrame only completes
      // once a frame actually runs.
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    _flashMessage(id);
  }

  /// Tints the message for a moment, so it is obvious which one was jumped to.
  void _flashMessage(String id) {
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = id);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  /// Round button offering the mentions still unvisited, mirroring the "@"
  /// marker the chat list was opened from.
  Widget _buildMentionJumpButton(FontSettings fontSettings) {
    final remaining = _reachableMentions.length;
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 12),
      child: Material(
        color: Colors.green,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _jumpToNextMention,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.alternate_email,
                  color: Colors.white,
                  size: 20,
                ),
                if (remaining > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$remaining',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSettings.fontSize - 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Message search ─────────────────────────────────────────────────────────

  bool get _hasSearchTerm => _isSearching && _searchQuery.isNotEmpty;

  /// The hit currently being shown, or null when nothing matched.
  String? get _currentSearchHit =>
      _searchIndex < _searchHits.length ? _searchHits[_searchIndex] : null;

  /// What a search looks at: the message text plus the names of anything
  /// attached, so "invoice.pdf" finds the message it was sent on.
  String _searchableText(ChatMessage message) {
    final parts = <String>[
      message.text,
      message.fileName ?? '',
      for (final item in message.groupedAttachments) item.fileName ?? '',
    ];
    return parts.join(' ').toLowerCase();
  }

  /// Hits newest first, matching the order the conversation is read in — the
  /// first one offered is the most recent.
  List<String> _computeSearchHits() {
    if (!_hasSearchTerm) return const [];
    final hits = <String>[];
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isSystem) continue;
      if (_searchableText(_messages[i]).contains(_searchQuery)) {
        hits.add(_messages[i].id);
      }
    }
    return hits;
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _highlightTimer?.cancel();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchHits = const [];
      _searchIndex = 0;
      _highlightedMessageId = null;
    });
  }

  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query == _searchQuery) return;
    setState(() {
      _searchQuery = query;
      _searchIndex = 0;
    });
    // The hits are recomputed by the build this setState schedules, so the
    // jump waits for it — before then the newest match is not known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hit = _currentSearchHit;
      if (mounted && hit != null) _scrollToMessage(hit);
    });
  }

  /// Walks the hits: 1 goes further back in the conversation, -1 back towards
  /// the newest. Stops at either end rather than wrapping around.
  void _stepSearch(int delta) {
    final next = _searchIndex + delta;
    if (next < 0 || next >= _searchHits.length) return;
    setState(() => _searchIndex = next);
    _scrollToMessage(_searchHits[next]);
  }

  /// [text] with every occurrence of the search term given a yellow ground, so
  /// the word that matched stands out inside a long message.
  List<InlineSpan> _searchHighlightedSpans(String text, TextStyle baseStyle) {
    if (!_hasSearchTerm || text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <InlineSpan>[];
    final lower = text.toLowerCase();
    var start = 0;
    while (true) {
      final at = lower.indexOf(_searchQuery, start);
      if (at == -1) break;
      if (at > start) {
        spans.add(TextSpan(text: text.substring(start, at), style: baseStyle));
      }
      final end = at + _searchQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(at, end),
          style: baseStyle.copyWith(
            backgroundColor: Colors.amber,
            color: Colors.black,
          ),
        ),
      );
      start = end;
    }

    if (spans.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return spans;
  }

  PreferredSizeWidget _buildSearchAppBar(FontSettings fontSettings) {
    return AppBar(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        cursorColor: Colors.white,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSettings.fontSize,
        ),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(
            color: Colors.white70,
            fontSize: fontSettings.fontSize,
          ),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Clear',
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
              _searchFocusNode.requestFocus();
            },
          ),
      ],
    );
  }

  /// Bar in place of the composer while searching: how many messages matched,
  /// and the arrows that walk them.
  Widget _buildSearchNavBar(FontSettings fontSettings) {
    final total = _searchHits.length;
    final label = _searchQuery.isEmpty
        ? 'Type to search this chat'
        : total == 0
            ? 'No messages found'
            : '${_searchIndex + 1} of $total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: fontSettings.fontSize - 3,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: 'Older match',
            color: Colors.green,
            onPressed: _searchIndex < total - 1 ? () => _stepSearch(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            tooltip: 'Newer match',
            color: Colors.green,
            onPressed: _searchIndex > 0 ? () => _stepSearch(-1) : null,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime ts) => DateFormat('HH:mm').format(ts);

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(date);
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final cur = _messages[index];
    final prev = _messages[index - 1];
    return DateTime(
          cur.timestamp.year,
          cur.timestamp.month,
          cur.timestamp.day,
        ) !=
        DateTime(
          prev.timestamp.year,
          prev.timestamp.month,
          prev.timestamp.day,
        );
  }

  // ─── Image grid widget ──────────────────────────────────────────────────────

  Widget _buildImageGrid(
    List<AttachmentItem> items,
    bool isMe,
    String messageId,
    FontSettings fontSettings,
  ) {
    const double gridSize = 220.0;
    const double gap = 3.0;
    const double cellSize = (gridSize - gap) / 2;

    final displayCount = items.length > 4 ? 4 : items.length;
    final extraCount = items.length - 4;

    Widget buildCell(int index, {bool showOverlay = false}) {
      final item = items[index];
      Widget img;

      if (item.url != null && item.url!.isNotEmpty) {
        img = Image.network(
          item.url!,
          width: cellSize,
          height: cellSize,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: cellSize,
              height: cellSize,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: cellSize,
            height: cellSize,
            color: Colors.grey[300],
            child:
                const Icon(Icons.broken_image, color: Colors.grey, size: 32),
          ),
        );
      } else if (item.localPath != null &&
          File(item.localPath!).existsSync()) {
        img = Image.file(
          File(item.localPath!),
          width: cellSize,
          height: cellSize,
          fit: BoxFit.cover,
          cacheHeight: 300,
        );
      } else {
        img = Container(
          width: cellSize,
          height: cellSize,
          color: Colors.grey[300],
          child: const Icon(Icons.image, color: Colors.grey, size: 32),
        );
      }

      Widget cell = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: img,
      );

      if (showOverlay && extraCount > 0) {
        cell = Stack(
          children: [
            cell,
            Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSettings.fontSize + 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(messageId);
          } else {
            _openGallery(items, index);
          }
        },
        child: cell,
      );
    }

    if (displayCount == 1) {
      return GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(messageId);
          } else {
            _openGallery(items, 0);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: items[0].url != null
              ? Image.network(
                  items[0].url!,
                  width: gridSize,
                  height: gridSize,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : Container(
                          width: gridSize,
                          height: gridSize,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.green,
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    width: gridSize,
                    height: gridSize,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 48,
                    ),
                  ),
                )
              : items[0].localPath != null
                  ? Image.file(
                      File(items[0].localPath!),
                      width: gridSize,
                      height: gridSize,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: gridSize,
                      height: gridSize,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 48,
                      ),
                    ),
        ),
      );
    }

    if (displayCount == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildCell(0),
          const SizedBox(width: gap),
          buildCell(1, showOverlay: extraCount > 0),
        ],
      );
    }

    return SizedBox(
      width: gridSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildCell(0),
              const SizedBox(width: gap),
              buildCell(1),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildCell(2),
              const SizedBox(width: gap),
              buildCell(
                displayCount == 4 ? 3 : 2,
                showOverlay: extraCount > 0 || displayCount == 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openGallery(List<AttachmentItem> items, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _GalleryView(items: items, initialIndex: initialIndex),
      ),
    );
  }

  // ─── Single attachment ──────────────────────────────────────────────────────

  Widget _buildSingleAttachment(
    ChatMessage message,
    FontSettings fontSettings,
  ) {
    if (message.fileType == 'image') {
      final item = AttachmentItem(
        url: message.attachmentUrl,
        localPath: message.filePath,
        fileName: message.fileName,
        mimeType: message.attachmentType,
      );
      return _buildImageGrid([item], message.isMe, message.id, fontSettings);
    }

    final name = message.fileName ?? message.text;
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(message.id);
        } else if (message.attachmentUrl != null) {
          DownloadHelper.downloadAndOpen(
            context,
            message.attachmentUrl!,
            name,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.green[700] : Colors.grey[400],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: message.isMe ? Colors.white : Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: message.isMe ? Colors.white : Colors.black87,
                  fontSize: fontSettings.fontSize - 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              color: message.isMe ? Colors.white70 : Colors.black54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Message bubble ─────────────────────────────────────────────────────────

  Widget _buildMessage(ChatMessage message, FontSettings fontSettings) {
    // Nobody wrote this one — the backend narrating a change to the chat
    // itself. It gets the centered notice, not a bubble, and none of the
    // gestures below.
    if (message.isSystem) return _buildSystemMessage(message, fontSettings);

    final isSelected = _selectedMessageIds.contains(message.id);
    final isHighlighted =
        _highlightedMessageId == message.id || _currentSearchHit == message.id;
    final hasGrouped = message.hasGroupedAttachments;
    final showText =
        message.text.isNotEmpty &&
        message.fileType != 'image' &&
        message.fileType != 'document' &&
        !hasGrouped;
    final isImageBubble =
        hasGrouped ? message.isImageGroup : message.fileType == 'image';
    final senderLabel = (message.senderName?.trim().isNotEmpty ?? false)
        ? message.senderName!.trim()
        : 'Unknown';
    // Name above the bubble, so a group conversation shows who is talking.
    final showSenderName = widget.isGroup && !message.isMe;

    // Swipe left-to-right to reply, the way every other chat app does it.
    // Selection mode owns the horizontal gesture instead, and a message the
    // server has not acknowledged yet cannot be quoted.
    final canSwipeToReply =
        !_isSelectionMode && widget.canSendMessages && _canReplyTo(message);

    final bubble = GestureDetector(
      // The first long-press selects the message *and* offers the emoji row,
      // so reacting and the reply/forward/copy/delete toolbar are both one
      // gesture away. Once selection is running a long-press is plain
      // multi-select, otherwise picking a second message would keep
      // re-opening the picker.
      onLongPress: () {
        final opensPicker = !_isSelectionMode;
        _toggleSelection(message.id);
        if (opensPicker) _showReactionPicker(message);
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(message.id);
        } else {
          // A tap anywhere in the list dismisses a stray emoji row.
          _closeReactionPicker();
        }
      },
      // Kept as a shortcut for reacting without entering selection mode.
      onDoubleTap: _isSelectionMode ? null : () => _showReactionPicker(message),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? Colors.green.withOpacity(0.15)
            : isHighlighted
                ? Colors.amber.withOpacity(0.35)
                : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: message.isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Checkbox (selection mode) ──
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Colors.green,
                      shape: const CircleBorder(),
                      side: const BorderSide(color: Colors.green, width: 2),
                      onChanged: (_) => _toggleSelection(message.id),
                    ),
                  ),
                ),

              // ── Avatar (other user) ──
              if (!message.isMe) ...[
                Stack(
                  children: [
                    CircleAvatar(
                      // In a group every incoming bubble can be a different
                      // person, so derive the avatar from that sender.
                      backgroundColor: widget.isGroup
                          ? ChatContact.generateColorFromName(senderLabel)
                          : widget.contact.avatarColor,
                      radius: 15,
                      child: Text(
                        widget.isGroup
                            ? ChatContact.generateInitials(senderLabel)
                            : widget.contact.initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSettings.fontSize - 4,
                        ),
                      ),
                    ),
                    if (!widget.isGroup && widget.contact.isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],

              // ── Bubble ──
              Flexible(
                child: Column(
                  crossAxisAlignment: message.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: isImageBubble
                          ? const EdgeInsets.all(4)
                          : const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                      decoration: BoxDecoration(
                        color: message.isMe
                            ? (isSelected
                                ? Colors.green[600]
                                : Colors.green)
                            : (isSelected
                                ? Colors.grey[350]
                                : const Color.fromARGB(255, 200, 199, 199)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sender (groups only)
                          if (showSenderName)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 2,
                                left: isImageBubble ? 8 : 0,
                                top: isImageBubble ? 4 : 0,
                              ),
                              child: Text(
                                senderLabel,
                                style: TextStyle(
                                  color: ChatContact.generateColorFromName(
                                    senderLabel,
                                  ),
                                  fontSize: fontSettings.fontSize - 4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // Quoted message (reply)
                          if (message.replyToMessageId != null)
                            Padding(
                              padding: EdgeInsets.only(
                                left: isImageBubble ? 8 : 0,
                                right: isImageBubble ? 8 : 0,
                                top: isImageBubble ? 4 : 0,
                              ),
                              child: _buildQuotedMessage(message, fontSettings),
                            ),

                          // Forwarded tag — the backend marks messages created
                          // by the forward endpoint, naming the original sender.
                          if (message.isForwarded)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 4,
                                left: isImageBubble ? 8 : 0,
                                top: isImageBubble ? 4 : 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forward,
                                    size: fontSettings.fontSize - 3,
                                    color: message.isMe
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      (message.forwardedFromSenderName
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false)
                                          ? 'Forwarded from '
                                              '${message.forwardedFromSenderName!.trim()}'
                                          : 'Forwarded',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: fontSettings.fontSize - 4,
                                        color: message.isMe
                                            ? Colors.white70
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // "Mentioned you" tag, driven by the server's mentions
                          // list so it is right even when the text is edited or a
                          // member was renamed.
                          // if (_mentionsMe(message))
                          //   Padding(
                          //     padding: EdgeInsets.only(
                          //       bottom: 2,
                          //       left: isImageBubble ? 8 : 0,
                          //       right: isImageBubble ? 8 : 0,
                          //     ),
                          //     child: Row(
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         Icon(
                          //           Icons.alternate_email,
                          //           size: fontSettings.fontSize - 4,
                          //           color: Colors.amber[800],
                          //         ),
                          //         const SizedBox(width: 4),
                          //         Text(
                          //           'Mentioned you',
                          //           style: TextStyle(
                          //             fontSize: fontSettings.fontSize - 5,
                          //             fontWeight: FontWeight.bold,
                          //             color: Colors.amber[800],
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),

                          // Attachment
                          if (hasGrouped) ...[
                            _buildImageGrid(
                              message.groupedAttachments,
                              message.isMe,
                              message.id,
                              fontSettings,
                            ),
                          ] else if (message.fileType != null) ...[
                            _buildSingleAttachment(message, fontSettings),
                          ],

                          if (hasGrouped || message.fileType != null)
                            const SizedBox(height: 4),

                          // Text
                          if (showText)
                            Padding(
                              padding: isImageBubble
                                  ? const EdgeInsets.symmetric(horizontal: 8)
                                  : EdgeInsets.zero,
                              child: _buildMessageText(
                                message,
                                TextStyle(
                                  color: message.isMe
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                            ),

                          // Time + read tick
                          Padding(
                            padding: isImageBubble
                                ? const EdgeInsets.only(
                                    right: 8,
                                    left: 8,
                                    bottom: 4,
                                  )
                                : EdgeInsets.zero,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    color: message.isMe
                                        ? Colors.white70
                                        : Colors.grey[600],
                                    fontSize: fontSettings.fontSize - 4,
                                  ),
                                ),
                                // Corrected after sending: say so, the way
                                // every other chat app does, so a changed
                                // message is never silently different.
                                if (message.isEdited) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    'edited',
                                    style: TextStyle(
                                      color: message.isMe
                                          ? Colors.white70
                                          : Colors.grey[600],
                                      fontSize: fontSettings.fontSize - 5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                if (message.isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    message.isRead == true
                                        ? Icons.done_all
                                        : Icons.done,
                                    color: message.isRead == true
                                        ? Colors.blue[200]
                                        : Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reaction summary, hung under the bubble rather than
                    // inside it so it reads the same on an image bubble.
                    if (message.hasReactions)
                      _buildReactionPill(message, fontSettings),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return _wrapSwipeToReply(
      message: message,
      bubble: bubble,
      enabled: canSwipeToReply,
      fontSettings: fontSettings,
    );
  }

  /// [bubble] wrapped in the swipe-to-reply gesture. Dismissible does the drag
  /// and the spring-back; confirmDismiss always answers false, so the row is
  /// never actually removed — the swipe is only a trigger.
  Widget _wrapSwipeToReply({
    required ChatMessage message,
    required Widget bubble,
    required bool enabled,
    required FontSettings fontSettings,
  }) {
    if (!enabled) return bubble;

    return Dismissible(
      key: ValueKey('swipe-reply-${message.id}'),
      direction: DismissDirection.startToEnd,
      // Deliberately short: a reply swipe is a flick, not a drag across the
      // screen, and the bubble springs back either way.
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        _startReply(message);
        return false;
      },
      background: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            Icons.reply,
            color: Colors.green[700],
            size: fontSettings.fontSize + 6,
          ),
        ),
      ),
      child: bubble,
    );
  }

  // ─── System message ─────────────────────────────────────────────────────────

  /// A chat event the backend narrates — "Pasindu added Tharindu", a rename,
  /// admin-only messaging toggled. Centered notice in the same style as the
  /// date separator, since both are the conversation talking about itself.
  Widget _buildSystemMessage(ChatMessage message, FontSettings fontSettings) {
    final text = message.text.trim().isNotEmpty
        ? message.text.trim()
        : _systemEventFallback(message.systemEvent);
    if (text.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 236, 236, 226),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color.fromARGB(255, 80, 80, 80),
            fontSize: fontSettings.fontSize - 4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Last resort when the backend sent the event but no sentence for it:
  /// `member_added` reads as "Member added" rather than as raw slug.
  String _systemEventFallback(String? event) {
    final slug = event?.trim() ?? '';
    if (slug.isEmpty) return '';
    final words = slug.replaceAll('_', ' ').trim();
    if (words.isEmpty) return '';
    return words[0].toUpperCase() + words.substring(1);
  }

  // ─── Date separator ─────────────────────────────────────────────────────────

  Widget _buildDateSeparator(DateTime date, FontSettings fontSettings) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 236, 236, 226),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _formatDateSeparator(date),
          style: TextStyle(
            color: const Color.fromARGB(255, 2, 2, 2),
            fontSize: fontSettings.fontSize - 4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fontSettings = ref.watch(fontSettingsProvider);

    // Derived from _messages, so recomputed here: a message arriving or being
    // deleted while the bar is open must not leave a hit pointing at something
    // the conversation no longer holds.
    _searchHits = _computeSearchHits();
    if (_searchIndex >= _searchHits.length) {
      _searchIndex = _searchHits.isEmpty ? 0 : _searchHits.length - 1;
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          _clearSelection();
          return false;
        }
        if (_isSearching) {
          _closeSearch();
          return false;
        }
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      },
      child: Scaffold(
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                title: Text(
                  '${_selectedMessageIds.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSettings.fontSize + 2,
                  ),
                ),
                actions: [
                  // IconButton(
                  //   icon: const Icon(Icons.select_all),
                  //   tooltip: 'Select All',
                  //   onPressed: _selectAll,
                  // ),
                  if (_selectedMessageIds.length == 1)
                    IconButton(
                      icon: const Icon(Icons.reply),
                      tooltip: 'Reply',
                      onPressed: _replyToSelectedMessage,
                    ),
                  // Own text messages only, and only while the 15-minute
                  // window the backend enforces is still open.
                  if (_editableSelection != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit',
                      onPressed: _editSelectedMessage,
                    ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy',
                    onPressed: _copySelectedMessages,
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward),
                    tooltip: 'Forward',
                    onPressed: _forwardSelectedMessages,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete',
                    onPressed: _deleteSelectedMessages,
                  ),
                ],
              )
            : _isSearching
            ? _buildSearchAppBar(fontSettings)
            : AppBar(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _readStatusPollTimer?.cancel();
                    _foregroundMessageSubscription?.cancel();
                    CurrentChatState().clearCurrentChat();
                    Navigator.pop(context);
                  },
                ),
                title: GestureDetector(
                  onTap: widget.isGroup ? _openGroupInfo : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                  children: [
                    Stack(
                      children: [
                        // Groups get the picture (or the group glyph); 1:1
                        // chats keep their coloured initials.
                        widget.isGroup
                            ? GroupAvatar(
                                avatarUrl: _avatarUrl,
                                radius: 18,
                                backgroundColor: widget.contact.avatarColor,
                              )
                            : CircleAvatar(
                                backgroundColor: widget.contact.avatarColor,
                                radius: 18,
                                child: Text(
                                  widget.contact.initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: fontSettings.fontSize - 4,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        if (!widget.isGroup && widget.contact.isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.contact.name,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.isGroup
                                ? (widget.groupMemberCount > 0
                                      ? '${widget.groupMemberCount} member${widget.groupMemberCount == 1 ? '' : 's'}'
                                      : 'Tap for group info')
                                : (widget.contact.isOnline
                                      ? 'Online'
                                      : 'Last seen recently'),
                            style: TextStyle(
                              fontSize: fontSettings.fontSize - 4,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ),
                ),
                actions: [
                  if (widget.isGroup)
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'Group info',
                      onPressed: _openGroupInfo,
                    ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search messages',
                    onPressed: _openSearch,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _fetchMessagesFromApi(silent: false),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  ),
                ],
              ),
        body: SafeArea(
          child: Column(
            children: [
              if (_isLoadingMessages)
                const LinearProgressIndicator(
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: Colors.green.shade50,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Uploading file(s)...',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 4,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Container(
                  color: const Color.fromARGB(255, 245, 245, 230),
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: fontSettings.fontSize,
                            ),
                          ),
                        )
                      : Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              reverse: true,
                              itemCount: _messages.length,
                              itemBuilder: (ctx, index) {
                                final ri = _messages.length - 1 - index;
                                final msg = _messages[ri];
                                return Column(
                                  children: [
                                    if (_shouldShowDateSeparator(ri))
                                      _buildDateSeparator(
                                        msg.timestamp,
                                        fontSettings,
                                      ),
                                    // Keyed so a mention can be scrolled to.
                                    KeyedSubtree(
                                      key: _keyForMessage(msg.id),
                                      child: _buildMessage(msg, fontSettings),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (_reachableMentions.isNotEmpty &&
                                !_isSearching)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child:
                                    _buildMentionJumpButton(fontSettings),
                              ),
                          ],
                        ),
                ),
              ),
              if (_isSearching) _buildSearchNavBar(fontSettings),

              // ── Read-only notice (admin-only group) ──
              if (!_isSelectionMode && !_isSearching && !widget.canSendMessages)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Only admins can send messages in this group',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: fontSettings.fontSize - 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Bottom action panel (emoji row + selection actions) ──
              // Sits on whatever is below it: nothing while selecting (the
              // composer is hidden then), the composer otherwise.
              if (!_isSearching) _buildBottomActionPanel(fontSettings),

              // ── Input bar (hidden in selection and search mode) ──
              if (!_isSelectionMode && !_isSearching && widget.canSendMessages) ...[
                if (_mentionSuggestions.isNotEmpty)
                  _buildMentionSuggestions(fontSettings),
                if (_replyingTo != null)
                  _buildReplyPreview(_replyingTo!, fontSettings),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.grey,
                        ),
                        onPressed: _onCameraPressed,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          style: TextStyle(fontSize: fontSettings.fontSize),
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            hintStyle: TextStyle(
                              fontSize: fontSettings.fontSize,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.attach_file,
                                color: Colors.grey,
                              ),
                              onPressed: _onAttachFilePressed,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          onChanged: _onComposerChanged,
                          onSubmitted: (_) => _sendMessage(),
                          onTap: () {
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) _scrollToBottom();
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        backgroundColor: Colors.green,
                        mini: true,
                        onPressed: _sendMessage,
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Full-screen gallery viewer ────────────────────────────────────────────────

class _GalleryView extends ConsumerStatefulWidget {
  final List<AttachmentItem> items;
  final int initialIndex;

  const _GalleryView({required this.items, required this.initialIndex});

  @override
  ConsumerState<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends ConsumerState<_GalleryView> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.items.length}',
          style: TextStyle(
            fontSize: fontSettings.fontSize,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy image',
            onPressed: () {
              final item = widget.items[_currentIndex];
              ImageClipboard.copyImage(
                context,
                url: item.url,
                localPath: item.localPath,
                fileName: item.fileName,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () {
              final item = widget.items[_currentIndex];
              final url = item.url;
              final name = item.fileName ??
                  'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
              if (url != null) {
                DownloadHelper.downloadAndOpen(context, url, name);
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (ctx, i) {
          final item = widget.items[i];
          Widget img;
          if (item.url != null && item.url!.isNotEmpty) {
            img = Image.network(
              item.url!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 80,
              ),
            );
          } else if (item.localPath != null &&
              File(item.localPath!).existsSync()) {
            img = Image.file(
              File(item.localPath!),
              fit: BoxFit.contain,
            );
          } else {
            img = const Icon(Icons.image, color: Colors.white, size: 80);
          }
          return InteractiveViewer(child: Center(child: img));
        },
      ),
    );
  }
}


/// The edit sheet owns its own controller so the field is disposed with the
/// dialog's element, not while the route is still animating away — disposing
/// it the moment `showDialog` returns tears the text field out from under the
/// exit transition and blows up the element tree.
class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({
    required this.initialText,
    required this.windowNote,
    required this.fontSettings,
  });

  final String initialText;
  final String windowNote;
  final FontSettings fontSettings;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = widget.fontSettings;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Edit message',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: fontSettings.fontSize,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: fontSettings.fontSize),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.green, width: 2),
              ),
              hintText: 'Message',
              hintStyle: TextStyle(fontSize: fontSettings.fontSize - 2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.windowNote,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: fontSettings.fontSize - 5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: fontSettings.fontSize - 2,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(
            'Save',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
              fontSize: fontSettings.fontSize - 2,
            ),
          ),
        ),
      ],
    );
  }
}
