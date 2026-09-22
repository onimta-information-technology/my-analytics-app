import 'package:ballys_reservation_app/components/group_avatar.dart';
import 'package:ballys_reservation_app/components/user_avatar.dart';
import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_api_service.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:ballys_reservation_app/models/call_session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "Recents": every call this user was part of, across all chats, newest
/// first (`GET /api/calls/history/:userId`). Tapping the call icon on a row
/// calls that chat back with the same media.
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final List<CallHistoryEntry> _calls = [];
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = _calls.isEmpty;
      _error = null;
    });
    try {
      final page = await CallApiService.history();
      if (!mounted) return;
      setState(() {
        _calls
          ..clear()
          ..addAll(page.calls);
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _maybeLoadMore() {
    if (!_hasMore || _loadingMore || _nextCursor == null) return;
    if (_scroll.position.extentAfter > 400) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await CallApiService.history(before: _nextCursor);
      if (!mounted) return;
      setState(() {
        _calls.addAll(page.calls);
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
    } catch (_) {
      // The next scroll retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _callBack(CallHistoryEntry call) {
    if (call.chatId.isEmpty) return;
    CallManager.instance.startCall(
      chatId: call.chatId,
      title: call.title,
      media: call.media,
      isGroup: call.isGroupCall,
      avatarUrl: call.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        backgroundColor: ChatColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: ChatColors.primary,
        onRefresh: _refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ChatColors.primary),
      );
    }
    if (_error != null && _calls.isEmpty) {
      return _message(Icons.error_outline, 'Could not load calls', _error);
    }
    if (_calls.isEmpty) {
      return _message(Icons.call_outlined, 'No calls yet', null);
    }
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _calls.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) {
        if (i >= _calls.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: ChatColors.primary),
            ),
          );
        }
        return _CallRow(call: _calls[i], onCallBack: _callBack);
      },
    );
  }

  /// Scrollable, so pull-to-refresh still works on an empty or failed list.
  Widget _message(IconData icon, String title, String? detail) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 50, color: Colors.grey),
        const SizedBox(height: 12),
        Center(
          child: Text(title, style: const TextStyle(color: Colors.grey)),
        ),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _CallRow extends StatelessWidget {
  final CallHistoryEntry call;
  final void Function(CallHistoryEntry) onCallBack;

  const _CallRow({required this.call, required this.onCallBack});

  @override
  Widget build(BuildContext context) {
    final missedIncoming = !call.isOutgoing && (call.isMissed || call.isDeclined);
    final titleColor = missedIncoming ? Colors.red[700] : ChatColors.bubbleText;

    return ListTile(
      leading: call.isGroupCall
          ? GroupAvatar(
              avatarUrl: call.avatarUrl,
              radius: 24,
              backgroundColor: ChatColors.primary,
            )
          : UserAvatar(
              avatarUrl: call.avatarUrl,
              initials: _initials(call.title),
              backgroundColor: ChatColors.primary,
              radius: 24,
            ),
      title: Text(
        call.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Icon(
            call.isOutgoing ? Icons.call_made : Icons.call_received,
            size: 16,
            color: call.isMissed || call.isDeclined
                ? Colors.red[700]
                : ChatColors.accent,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _subtitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ChatColors.bubbleMeta),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: call.media == CallMedia.video ? 'Video call' : 'Voice call',
        icon: Icon(
          call.media == CallMedia.video ? Icons.videocam : Icons.call,
          color: ChatColors.primary,
        ),
        onPressed: call.chatId.isEmpty ? null : () => onCallBack(call),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[_when(call.createdAt)];
    if (call.isLive) {
      parts.add('In progress');
    } else if (call.isMissed) {
      parts.add('Missed');
    } else if (call.isDeclined) {
      parts.add('Declined');
    } else {
      final d = call.duration;
      if (d != null) parts.add(_duration(d));
    }
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }

  static String _when(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat('h:mm a').format(at);
    if (day == today) return 'Today, $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    if (now.difference(at).inDays < 7) {
      return '${DateFormat('EEEE').format(at)}, $time';
    }
    return DateFormat('d MMM yyyy, h:mm a').format(at);
  }

  static String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}
