import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/data/services/call_manager.dart';
import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:flutter/material.dart';

/// WhatsApp's "Add participant" during a call: everyone in the directory who
/// is not already on (or ringing into) the call. Picking someone rings them
/// in through [CallManager.addParticipant] — they do not need to be in the
/// chat the call started from.
Future<void> showAddCallParticipantSheet(
  BuildContext context,
  CallController controller,
) async {
  final picked = await showModalBottomSheet<ChatContact>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1F2C34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AddCallParticipantSheet(controller: controller),
  );
  if (picked == null) return;
  await CallManager.instance.addParticipant(
    userUuid: picked.userUuid,
    appType: picked.appType,
    name: picked.name,
    avatarUrl: picked.avatarUrl,
  );
}

class _AddCallParticipantSheet extends StatefulWidget {
  final CallController controller;
  const _AddCallParticipantSheet({required this.controller});

  @override
  State<_AddCallParticipantSheet> createState() =>
      _AddCallParticipantSheetState();
}

class _AddCallParticipantSheetState extends State<_AddCallParticipantSheet> {
  final TextEditingController _search = TextEditingController();
  List<ChatContact> _all = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await FirebaseApiService.fetchAllUsers();
      final users = (data['users'] as List<dynamic>?) ?? [];
      final contacts = users
          .whereType<Map<String, dynamic>>()
          .map((user) {
            final name = user['name'] ?? user['firstName'] ?? 'Unknown';
            return ChatContact(
              id: user['id'] ?? user['userUuid'] ?? '',
              chatUuid: '',
              userUuid: (user['userUuid'] ?? user['id'] ?? '').toString(),
              name: name,
              firstName: user['firstName'] ?? name,
              lastMessage: '',
              time: '',
              avatarColor: ChatContact.generateColorFromName(name),
              initials: ChatContact.generateInitials(name),
              participants: const [],
              createdAt: DateTime.now(),
              lastMessageSenderName: null,
              appType: ChatContact.parseAppType(user['appType']),
              avatarUrl: ChatContact.parseAvatarUrl(user),
            );
          })
          .where((c) => c.userUuid.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _all = contacts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load contacts';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add to call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: ChatColors.accent,
                  decoration: InputDecoration(
                    hintText: 'Search name',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white10,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: ChatColors.accent),
      );
    }
    if (_error != null) return _message(_error!);

    // Read on every build so someone who joins while the sheet is open drops
    // out of the list.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final onCall = widget.controller.identitiesOnCall;
        final q = _search.text.trim().toLowerCase();
        final visible = _all.where((c) {
          if (onCall.contains('${c.userUuid}|${c.appType}')) return false;
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) ||
              c.firstName.toLowerCase().contains(q);
        }).toList();
        if (visible.isEmpty) {
          return _message(q.isEmpty ? 'No one else to add' : 'No contacts found');
        }
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: visible.length,
          itemBuilder: (context, i) {
            final c = visible[i];
            final url = c.avatarUrl;
            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: c.avatarColor,
                foregroundImage: url == null ? null : NetworkImage(url),
                child: Text(
                  c.initials,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: Icon(Icons.add_call, color: ChatColors.accent),
              onTap: () => Navigator.of(context).pop(c),
            );
          },
        );
      },
    );
  }

  Widget _message(String text) => Center(
        child: Text(text, style: const TextStyle(color: Colors.white54)),
      );
}
