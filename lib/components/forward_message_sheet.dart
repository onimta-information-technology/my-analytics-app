import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/components/group_avatar.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_group.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';

/// Where the user chose to forward to, in the shape
/// `POST /api/chats/:chatId/messages/:messageId/forward` expects.
///
/// Groups go out as [chatIds] (the user is already a participant); people go
/// out as [users] — `{userUuid, appType}` pairs the backend resolves to an
/// existing 1:1 chat or creates one for.
class ForwardTargets {
  final List<String> chatIds;
  final List<Map<String, dynamic>> users;

  /// Names of the picked targets, in picking order, for the result message.
  final List<String> names;

  const ForwardTargets({
    required this.chatIds,
    required this.users,
    required this.names,
  });

  bool get isEmpty => chatIds.isEmpty && users.isEmpty;
  int get length => chatIds.length + users.length;
}

/// Target picker for forwarding. Pops with the chosen targets, or null when
/// cancelled.
///
/// [excludeChatId] and [excludeUserUuid] drop the conversation the message is
/// already in — the backend rejects forwarding a message back into its own
/// chat, so there is no point offering it.
Future<ForwardTargets?> showForwardMessageSheet({
  required BuildContext context,
  required FontSettings fontSettings,
  required int messageCount,
  String? excludeChatId,
  String? excludeUserUuid,
}) {
  return showModalBottomSheet<ForwardTargets>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _ForwardMessageSheet(
      fontSettings: fontSettings,
      messageCount: messageCount,
      excludeChatId: excludeChatId,
      excludeUserUuid: excludeUserUuid,
    ),
  );
}

class _ForwardMessageSheet extends StatefulWidget {
  final FontSettings fontSettings;
  final int messageCount;
  final String? excludeChatId;
  final String? excludeUserUuid;

  const _ForwardMessageSheet({
    required this.fontSettings,
    required this.messageCount,
    this.excludeChatId,
    this.excludeUserUuid,
  });

  @override
  State<_ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<_ForwardMessageSheet> {
  List<ChatGroup> _groups = const [];
  List<ChatContact> _contacts = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  /// Picked targets, keyed by groupId / userUuid so the order of picking is
  /// preserved for the confirmation message.
  final Map<String, ChatGroup> _selectedGroups = {};
  final Map<String, ChatContact> _selectedContacts = {};

  FontSettings get _fs => widget.fontSettings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // A failure on either list should not hide the other, so each is caught on
    // its own and only an empty result overall is reported as an error.
    List<ChatGroup> groups = const [];
    List<ChatContact> contacts = const [];
    Object? failure;

    try {
      final raw = await FirebaseApiService.fetchUserGroups();
      groups = raw
          .map(ChatGroup.fromApiJson)
          .where((g) => g.groupId.isNotEmpty && g.groupId != widget.excludeChatId)
          .toList();
    } catch (e) {
      failure = e;
    }

    try {
      final data = await FirebaseApiService.fetchAllUsers();
      final users = (data['users'] as List<dynamic>?) ?? [];
      contacts = users
          .whereType<Map<String, dynamic>>()
          .map((user) {
            final name = user['name'] ?? user['firstName'] ?? 'Unknown';
            return ChatContact(
              id: user['id'] ?? user['userUuid'] ?? '',
              chatUuid: '',
              userUuid: user['userUuid'] ?? user['id'] ?? '',
              name: name,
              firstName: user['firstName'] ?? name,
              lastMessage: '',
              time: '',
              isOnline: user['isOnline'] ?? false,
              avatarColor: ChatContact.generateColorFromName(name),
              initials: ChatContact.generateInitials(name),
              participants: const [],
              createdAt: DateTime.now(),
              lastMessageSenderName: null,
              appType: ChatContact.parseAppType(user['appType']),
            );
          })
          .where((c) =>
              c.userUuid.isNotEmpty && c.userUuid != widget.excludeUserUuid)
          .toList();
    } catch (e) {
      failure ??= e;
    }

    if (!mounted) return;
    setState(() {
      _groups = groups;
      _contacts = contacts;
      _loading = false;
      _error = (groups.isEmpty && contacts.isEmpty && failure != null)
          ? 'Could not load your chats and contacts'
          : null;
    });
  }

  bool _matches(String value) =>
      _query.isEmpty || value.toLowerCase().contains(_query.toLowerCase());

  List<ChatGroup> get _visibleGroups =>
      _groups.where((g) => _matches(g.groupName)).toList();

  List<ChatContact> get _visibleContacts => _contacts
      .where((c) => _matches(c.name) || _matches(c.firstName))
      .toList();

  int get _selectedCount => _selectedGroups.length + _selectedContacts.length;

  void _submit() {
    Navigator.pop(
      context,
      ForwardTargets(
        chatIds: _selectedGroups.keys.toList(),
        users: _selectedContacts.values
            .map((c) => {'userUuid': c.userUuid, 'appType': c.appType})
            .toList(),
        names: [
          ..._selectedGroups.values.map((g) => g.groupName),
          ..._selectedContacts.values.map((c) => c.name),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.forward, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.messageCount > 1
                          ? 'Forward ${widget.messageCount} messages'
                          : 'Forward message',
                      style: TextStyle(
                        fontSize: _fs.fontSize + 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                style: TextStyle(fontSize: _fs.fontSize - 2),
                decoration: InputDecoration(
                  hintText: 'Search groups and contacts...',
                  hintStyle: TextStyle(fontSize: _fs.fontSize - 2),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedCount == 0
                    ? 'Select where to send it'
                    : '$_selectedCount selected',
                style: TextStyle(
                  fontSize: _fs.fontSize - 3,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(child: _buildBody()),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: _fs.fontSize - 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedCount == 0 ? null : _submit,
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        'Send',
                        style: TextStyle(fontSize: _fs.fontSize - 2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: _fs.fontSize - 2),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final groups = _visibleGroups;
    final contacts = _visibleContacts;

    if (groups.isEmpty && contacts.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'Nowhere to forward to'
              : 'No groups or contacts match "$_query"',
          style: TextStyle(fontSize: _fs.fontSize - 2),
        ),
      );
    }

    return ListView(
      children: [
        if (groups.isNotEmpty) ...[
          _sectionHeader('Groups'),
          ...groups.map(_buildGroupTile),
        ],
        if (contacts.isNotEmpty) ...[
          _sectionHeader('Contacts'),
          ...contacts.map(_buildContactTile),
        ],
      ],
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: _fs.fontSize - 5,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _buildGroupTile(ChatGroup group) {
    // An admin-only group rejects forwards from ordinary members, so flag it
    // up front instead of letting the send come back as a per-target error.
    final blocked = group.adminOnlyMessaging && !group.isAdmin;

    return CheckboxListTile(
      value: _selectedGroups.containsKey(group.groupId),
      activeColor: Colors.green,
      controlAffinity: ListTileControlAffinity.trailing,
      onChanged: blocked
          ? null
          : (checked) {
              setState(() {
                if (checked == true) {
                  _selectedGroups[group.groupId] = group;
                } else {
                  _selectedGroups.remove(group.groupId);
                }
              });
            },
      secondary: GroupAvatar(
        avatarUrl: group.groupAvatarUrl,
        radius: 20,
        backgroundColor: group.avatarColor,
      ),
      title: Text(
        group.groupName,
        style: TextStyle(
          fontSize: _fs.fontSize,
          fontWeight: _fs.fontWeight,
        ),
      ),
      subtitle: Text(
        blocked
            ? 'Only admins can send messages'
            : '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
        style: TextStyle(
          fontSize: _fs.fontSize - 4,
          color: blocked ? Colors.orange[800] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildContactTile(ChatContact contact) {
    return CheckboxListTile(
      value: _selectedContacts.containsKey(contact.userUuid),
      activeColor: Colors.green,
      controlAffinity: ListTileControlAffinity.trailing,
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _selectedContacts[contact.userUuid] = contact;
          } else {
            _selectedContacts.remove(contact.userUuid);
          }
        });
      },
      secondary: CircleAvatar(
        backgroundColor: contact.avatarColor,
        child: Text(
          contact.initials,
          style: TextStyle(color: Colors.white, fontSize: _fs.fontSize - 4),
        ),
      ),
      title: Text(
        contact.name,
        style: TextStyle(
          fontSize: _fs.fontSize,
          fontWeight: _fs.fontWeight,
        ),
      ),
      subtitle: Text(
        contact.isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize: _fs.fontSize - 4,
          color: contact.isOnline ? Colors.green[700] : Colors.grey,
        ),
      ),
    );
  }
}
