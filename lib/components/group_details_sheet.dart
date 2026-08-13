import 'dart:convert';

import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/models/chat_group.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';

/// Group info sheet: name, settings and the member list with their roles.
///
/// Shared by the chat list and the group conversation screen, which know the
/// group by different models — so it takes only what it needs to render before
/// `GET /api/groups/:groupId` comes back.
///
/// Admins additionally get rename, admin-only messaging, add member and remove
/// member. [onGroupChanged] fires after any of those succeed, so the caller can
/// refresh its own list.
void showGroupDetailsSheet({
  required BuildContext context,
  required String groupId,
  required Color avatarColor,
  required FontSettings fontSettings,
  String? currentUserUuid,
  VoidCallback? onGroupChanged,
  VoidCallback? onGroupLeftOrDeleted,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _GroupDetailsSheet(
      groupId: groupId,
      avatarColor: avatarColor,
      fontSettings: fontSettings,
      currentUserUuid: currentUserUuid,
      onGroupChanged: onGroupChanged,
      onGroupLeftOrDeleted: onGroupLeftOrDeleted,
    ),
  );
}

class _GroupDetailsSheet extends StatefulWidget {
  final String groupId;
  final Color avatarColor;
  final FontSettings fontSettings;
  final String? currentUserUuid;
  final VoidCallback? onGroupChanged;

  /// Fired after leaving or deleting: the group is gone for this user, so a
  /// caller showing its conversation should close it.
  final VoidCallback? onGroupLeftOrDeleted;

  const _GroupDetailsSheet({
    required this.groupId,
    required this.avatarColor,
    required this.fontSettings,
    this.currentUserUuid,
    this.onGroupChanged,
    this.onGroupLeftOrDeleted,
  });

  @override
  State<_GroupDetailsSheet> createState() => _GroupDetailsSheetState();
}

class _GroupDetailsSheetState extends State<_GroupDetailsSheet> {
  late Future<Map<String, dynamic>> _detailsFuture;

  /// Set while a mutation is in flight, so the controls cannot be tapped twice.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = FirebaseApiService.fetchGroupDetails(widget.groupId);
  }

  FontSettings get _fs => widget.fontSettings;

  void _reload() {
    setState(() {
      _detailsFuture = FirebaseApiService.fetchGroupDetails(widget.groupId);
    });
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// The rules the backend enforces (last admin, sole admin leaving, creator
  /// only) come back as a 400 with an explanation — show that rather than a
  /// generic failure, otherwise the user cannot tell what to do about it.
  String _failureText(Map<String, dynamic> response, String fallback) {
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
    return fallback;
  }

  /// Runs one admin action, then reloads the sheet and tells the caller.
  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action, {
    required String successMessage,
    required String failureMessage,
  }) async {
    setState(() => _busy = true);
    final response = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    if (response['success'] == true) {
      _snack(successMessage);
      widget.onGroupChanged?.call();
      _reload();
    } else {
      _snack(_failureText(response, failureMessage), error: true);
    }
  }

  // ─── Admin actions ─────────────────────────────────────────────────────────

  Future<void> _renameGroup(String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Rename group',
          style: TextStyle(fontSize: _fs.fontSize + 2),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: _fs.fontSize - 2),
          decoration: InputDecoration(
            hintText: 'Group name',
            hintStyle: TextStyle(fontSize: _fs.fontSize - 2),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(fontSize: _fs.fontSize - 2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text('Save', style: TextStyle(fontSize: _fs.fontSize - 2)),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName == null || newName.isEmpty || newName == currentName) return;

    await _runAction(
      () => FirebaseApiService.updateGroupSettings(
        groupId: widget.groupId,
        name: newName,
      ),
      successMessage: 'Group renamed',
      failureMessage: 'Could not rename the group',
    );
  }

  Future<void> _setAdminOnlyMessaging(bool value) async {
    await _runAction(
      () => FirebaseApiService.updateGroupSettings(
        groupId: widget.groupId,
        adminOnlyMessaging: value,
      ),
      successMessage: value
          ? 'Only admins can send messages now'
          : 'Everyone can send messages now',
      failureMessage: 'Could not update the group settings',
    );
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Remove member',
          style: TextStyle(fontSize: _fs.fontSize + 2),
        ),
        content: Text(
          'Remove ${member.name} from this group?',
          style: TextStyle(fontSize: _fs.fontSize - 2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(fontSize: _fs.fontSize - 2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Remove',
              style: TextStyle(color: Colors.red, fontSize: _fs.fontSize - 2),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runAction(
      () => FirebaseApiService.removeGroupMember(
        groupId: widget.groupId,
        userUuid: member.userUuid,
        memberAppType: member.appType,
      ),
      successMessage: '${member.name} removed',
      failureMessage: 'Could not remove ${member.name}',
    );
  }

  Future<void> _setAdminRole(GroupMember member, {required bool promote}) async {
    await _runAction(
      () => promote
          ? FirebaseApiService.promoteGroupAdmin(
              groupId: widget.groupId,
              targetUserId: member.userUuid,
              targetAppType: member.appType,
            )
          : FirebaseApiService.demoteGroupAdmin(
              groupId: widget.groupId,
              userUuid: member.userUuid,
              memberAppType: member.appType,
            ),
      successMessage: promote
          ? '${member.name} is now an admin'
          : '${member.name} is no longer an admin',
      failureMessage: promote
          ? 'Could not make ${member.name} an admin'
          : 'Could not remove admin from ${member.name}',
    );
  }

  /// Leave or delete: both end this user's access, so the sheet closes and the
  /// caller is told the group is gone.
  Future<void> _exitGroup({required bool delete}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          delete ? 'Delete group' : 'Leave group',
          style: TextStyle(fontSize: _fs.fontSize + 2),
        ),
        content: Text(
          delete
              ? 'This permanently deletes the group along with its messages and '
                    'attachments, for everyone. This cannot be undone.'
              : 'You will stop receiving messages from this group.',
          style: TextStyle(fontSize: _fs.fontSize - 2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TextStyle(fontSize: _fs.fontSize - 2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              delete ? 'Delete' : 'Leave',
              style: TextStyle(color: Colors.red, fontSize: _fs.fontSize - 2),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    final response = delete
        ? await FirebaseApiService.deleteGroup(widget.groupId)
        : await FirebaseApiService.leaveGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _busy = false);

    if (response['success'] == true) {
      // Grab the messenger while this context is still mounted, close the
      // sheet, and only then let the caller close whatever sits behind it.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onGroupChanged?.call();
      widget.onGroupLeftOrDeleted?.call();
      messenger.showSnackBar(
        SnackBar(
          content: Text(delete ? 'Group deleted' : 'You left the group'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _snack(
        _failureText(
          response,
          delete ? 'Could not delete the group' : 'Could not leave the group',
        ),
        error: true,
      );
    }
  }

  Future<void> _addMembers(GroupDetails details) async {
    final existing = details.members.map((m) => m.userUuid).toSet();

    List<ChatContact> candidates;
    try {
      final data = await FirebaseApiService.fetchAllUsers();
      final users = (data['users'] as List<dynamic>?) ?? [];
      candidates = users
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
              avatarColor: ChatContact.generateColorFromName(name),
              initials: ChatContact.generateInitials(name),
              participants: const [],
              createdAt: DateTime.now(),
              lastMessageSenderName: null,
              appType: ChatContact.parseAppType(user['appType']),
            );
          })
          .where((c) => c.userUuid.isNotEmpty && !existing.contains(c.userUuid))
          .toList();
    } catch (_) {
      _snack('Could not load contacts', error: true);
      return;
    }

    if (!mounted) return;

    if (candidates.isEmpty) {
      _snack('Everyone is already in this group');
      return;
    }

    final selected = await showModalBottomSheet<List<ChatContact>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (pickerContext) => _MemberPicker(
        candidates: candidates,
        fontSettings: _fs,
      ),
    );

    if (selected == null || selected.isEmpty) return;

    await _runAction(
      () => FirebaseApiService.addGroupMembers(
        groupId: widget.groupId,
        members: selected
            .map((c) => {'userUuid': c.userUuid, 'appType': c.appType})
            .toList(),
      ),
      successMessage: selected.length == 1
          ? '${selected.first.name} added'
          : '${selected.length} members added',
      failureMessage: 'Could not add members',
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 44, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load group details',
                      style: TextStyle(
                        fontSize: _fs.fontSize,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _reload,
                      child: Text(
                        'Retry',
                        style: TextStyle(fontSize: _fs.fontSize - 2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final details = GroupDetails.fromApiJson(snapshot.data ?? {});
          // Admins first, then everyone else in the order the API returned.
          final members = [
            ...details.members.where((m) => m.isAdmin),
            ...details.members.where((m) => !m.isAdmin),
          ];
          final bool isAdmin =
              widget.currentUserUuid != null &&
              details.isAdmin(widget.currentUserUuid!);
          // Only the creator may delete the group; everyone else leaves.
          final bool isCreator =
              widget.currentUserUuid != null &&
              details.createdByUuid == widget.currentUserUuid;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_busy)
                const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: widget.avatarColor,
                      backgroundImage: details.groupAvatarUrl != null
                          ? NetworkImage(details.groupAvatarUrl!)
                          : null,
                      child: details.groupAvatarUrl == null
                          ? Text(
                              ChatContact.generateInitials(details.groupName),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _fs.fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            details.groupName,
                            style: TextStyle(
                              fontSize: _fs.fontSize + 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${members.length} member${members.length == 1 ? '' : 's'}'
                            '${details.adminOnlyMessaging ? ' • Only admins can message' : ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: _fs.fontSize - 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Rename group',
                        onPressed: _busy
                            ? null
                            : () => _renameGroup(details.groupName),
                      ),
                  ],
                ),
              ),

              // ── Admin-only settings ──
              if (isAdmin) ...[
                const Divider(height: 1),
                SwitchListTile(
                  value: details.adminOnlyMessaging,
                  activeColor: Colors.green,
                  dense: true,
                  title: Text(
                    'Only admins can send messages',
                    style: TextStyle(fontSize: _fs.fontSize - 2),
                  ),
                  onChanged: _busy ? null : _setAdminOnlyMessaging,
                ),
              ],

              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Members',
                        style: TextStyle(
                          fontSize: _fs.fontSize - 2,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: _busy ? null : () => _addMembers(details),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: Text(
                          'Add',
                          style: TextStyle(fontSize: _fs.fontSize - 3),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Text(
                          'No members',
                          style: TextStyle(
                            fontSize: _fs.fontSize - 2,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final bool isMe =
                              member.userUuid == widget.currentUserUuid;
                          // Admins can remove anyone but themselves; leaving a
                          // group is a separate flow.
                          final bool canRemove = isAdmin && !isMe;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: member.avatarColor,
                              child: Text(
                                member.initials,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: _fs.fontSize - 4,
                                ),
                              ),
                            ),
                            title: Text(
                              isMe ? '${member.name} (You)' : member.name,
                              style: TextStyle(
                                fontSize: _fs.fontSize,
                                fontWeight: _fs.fontWeight,
                              ),
                            ),
                            subtitle: member.userUuid == details.createdByUuid
                                ? Text(
                                    'Created this group',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: _fs.fontSize - 4,
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (member.isAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: _fs.fontSize - 5,
                                      ),
                                    ),
                                  ),
                                if (canRemove)
                                  PopupMenuButton<String>(
                                    enabled: !_busy,
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    tooltip: 'Member actions',
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'promote':
                                          _setAdminRole(member, promote: true);
                                          break;
                                        case 'demote':
                                          _setAdminRole(member, promote: false);
                                          break;
                                        case 'remove':
                                          _removeMember(member);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: member.isAdmin
                                            ? 'demote'
                                            : 'promote',
                                        child: Text(
                                          member.isAdmin
                                              ? 'Remove as admin'
                                              : 'Make admin',
                                          style: TextStyle(
                                            fontSize: _fs.fontSize - 2,
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          'Remove from group',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: _fs.fontSize - 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 1),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(fontSize: _fs.fontSize - 2),
                          ),
                        ),
                      ),
                      // The creator deletes; everyone else leaves. Both are
                      // destructive, so both sit behind a confirmation.
                      if (isCreator)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _exitGroup(delete: true),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(
                              'Delete group',
                              style: TextStyle(fontSize: _fs.fontSize - 2),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _exitGroup(delete: false),
                            icon: const Icon(Icons.logout, size: 18),
                            label: Text(
                              'Leave group',
                              style: TextStyle(fontSize: _fs.fontSize - 2),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Multi-select list of contacts who are not in the group yet. Pops with the
/// chosen contacts, or null when cancelled.
class _MemberPicker extends StatefulWidget {
  final List<ChatContact> candidates;
  final FontSettings fontSettings;

  const _MemberPicker({required this.candidates, required this.fontSettings});

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final Map<String, ChatContact> _selected = {};
  late List<ChatContact> _visible = widget.candidates;

  @override
  Widget build(BuildContext context) {
    final fs = widget.fontSettings;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add members',
                style: TextStyle(
                  fontSize: fs.fontSize + 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                style: TextStyle(fontSize: fs.fontSize - 2),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(fontSize: fs.fontSize - 2),
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (query) {
                  setState(() {
                    _visible = query.isEmpty
                        ? widget.candidates
                        : widget.candidates
                              .where(
                                (c) =>
                                    c.name.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ) ||
                                    c.firstName.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ),
                              )
                              .toList();
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _selected.isEmpty
                    ? 'Select who to add'
                    : '${_selected.length} selected',
                style: TextStyle(
                  fontSize: fs.fontSize - 3,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  itemCount: _visible.length,
                  itemBuilder: (context, index) {
                    final contact = _visible[index];
                    return CheckboxListTile(
                      value: _selected.containsKey(contact.userUuid),
                      activeColor: Colors.green,
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected[contact.userUuid] = contact;
                          } else {
                            _selected.remove(contact.userUuid);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        backgroundColor: contact.avatarColor,
                        child: Text(
                          contact.initials,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fs.fontSize - 4,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: fs.fontSize,
                          fontWeight: fs.fontWeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: fs.fontSize - 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selected.isEmpty
                          ? null
                          : () =>
                                Navigator.pop(context, _selected.values.toList()),
                      child: Text(
                        'Add',
                        style: TextStyle(fontSize: fs.fontSize - 2),
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
}
