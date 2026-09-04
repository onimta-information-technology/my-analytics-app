import 'dart:io';

import 'package:ballys_reservation_app/components/contact_picker.dart';
import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/providers/chat_font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything the caller needs to create the group, handed back once both
/// steps are through. The screens never touch the API themselves — the chat
/// list owns the create call and the refresh that follows it.
class NewGroupDraft {
  const NewGroupDraft({
    required this.name,
    required this.members,
    this.avatarPath,
  });

  final String name;
  final List<ChatContact> members;
  final String? avatarPath;
}

/// Step one of WhatsApp's group flow: pick who is in it.
///
/// Pops a [NewGroupDraft] once step two is finished, or null if the user backs
/// out of either step.
class NewGroupMembersScreen extends ConsumerStatefulWidget {
  const NewGroupMembersScreen({super.key, required this.contacts});

  final List<ChatContact> contacts;

  @override
  ConsumerState<NewGroupMembersScreen> createState() =>
      _NewGroupMembersScreenState();
}

class _NewGroupMembersScreenState extends ConsumerState<NewGroupMembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  // Keyed by userUuid so the selection survives search filtering.
  final Map<String, ChatContact> _selected = {};
  late List<ChatContact> _visible = List.from(widget.contacts);
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _visible = List.from(widget.contacts);
    });
  }

  Future<void> _goToGroupInfo() async {
    FocusScope.of(context).unfocus();
    final draft = await Navigator.push<NewGroupDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => NewGroupInfoScreen(members: _selected.values.toList()),
      ),
    );
    if (!mounted || draft == null) return;
    // Step two created the draft, so this step is done with too.
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(chatFontSettingsProvider);
    final members = _selected.values.toList();
    final total = widget.contacts.length;

    return ChatFontScope(
      child: PopScope(
        canPop: !_isSearching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSearch();
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: ChatColors.primary,
              foregroundColor: Colors.white,
              titleSpacing: 0,
              title: _isSearching
                  ? PickerSearchField(
                      controller: _searchController,
                      fontSettings: fontSettings,
                      onChanged: (value) => setState(() {
                        _visible = matchContacts(widget.contacts, value);
                      }),
                    )
                  : PickerAppBarTitle(
                      title: 'Add members',
                      subtitle: _selected.isEmpty
                          ? '$total contact${total == 1 ? '' : 's'}'
                          : '${_selected.length} of $total selected',
                      fontSettings: fontSettings,
                    ),
              actions: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    if (_isSearching) {
                      _closeSearch();
                    } else {
                      setState(() => _isSearching = true);
                    }
                  },
                ),
              ],
            ),
            floatingActionButton: members.isEmpty
                ? null
                : FloatingActionButton(
                    backgroundColor: ChatColors.accent,
                    onPressed: _goToGroupInfo,
                    child: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
            body: Column(
              children: [
                if (members.isNotEmpty)
                  PickerSelectedStrip(
                    members: members,
                    fontSettings: fontSettings,
                    onRemove: (member) =>
                        setState(() => _selected.remove(member.userUuid)),
                  ),
                Expanded(
                  child: _visible.isEmpty
                      ? PickerMessage(
                          message: widget.contacts.isEmpty
                              ? 'No contacts available'
                              : 'No contacts found',
                          fontSettings: fontSettings,
                        )
                      : ListView.builder(
                          // Clear of the floating next button.
                          padding: const EdgeInsets.only(bottom: 88),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: _visible.length,
                          itemBuilder: (context, index) {
                            final contact = _visible[index];
                            final bool isSelected = _selected.containsKey(
                              contact.userUuid,
                            );

                            return PickerContactTile(
                              contact: contact,
                              fontSettings: fontSettings,
                              selected: isSelected,
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _selected.remove(contact.userUuid);
                                } else {
                                  _selected[contact.userUuid] = contact;
                                }
                              }),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Step two: the group's photo and subject, over the members just picked.
class NewGroupInfoScreen extends ConsumerStatefulWidget {
  const NewGroupInfoScreen({super.key, required this.members});

  final List<ChatContact> members;

  @override
  ConsumerState<NewGroupInfoScreen> createState() => _NewGroupInfoScreenState();
}

class _NewGroupInfoScreenState extends ConsumerState<NewGroupInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  late final List<ChatContact> _members = List.from(widget.members);
  // Optional group avatar, uploaded in the same multipart create call.
  File? _avatarFile;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _removeMember(ChatContact member) {
    setState(() => _members.remove(member));
    // Nothing left to name a group after, so fall back to the picker.
    if (_members.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(chatFontSettingsProvider);
    final bool canCreate =
        _nameController.text.trim().isNotEmpty && _members.isNotEmpty;

    return ChatFontScope(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: ChatColors.primary,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: PickerAppBarTitle(
              title: 'New group',
              subtitle: 'Add subject',
              fontSettings: fontSettings,
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: canCreate ? ChatColors.accent : Colors.grey,
            onPressed: canCreate
                ? () => Navigator.pop(
                    context,
                    NewGroupDraft(
                      name: _nameController.text.trim(),
                      members: _members,
                      avatarPath: _avatarFile?.path,
                    ),
                  )
                : null,
            child: const Icon(Icons.check, color: Colors.white),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await pickChatAvatarImage(context);
                        if (picked != null) {
                          setState(() => _avatarFile = picked);
                        }
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: kPickerRule,
                            backgroundImage: _avatarFile != null
                                ? FileImage(_avatarFile!)
                                : null,
                            child: _avatarFile == null
                                ? const Icon(
                                    Icons.camera_alt,
                                    size: 24,
                                    color: ChatColors.primary,
                                  )
                                : null,
                          ),
                          if (_avatarFile != null)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: ChatColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          color: kPickerTitle,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Group subject',
                          hintStyle: TextStyle(
                            fontSize: fontSettings.fontSize - 2,
                            color: kPickerSubtitle,
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: kPickerRule),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: ChatColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        // Rebuild so the create button enables as soon as the
                        // subject stops being blank.
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              PickerSectionLabel(
                label: 'MEMBERS: ${_members.length}',
                fontSettings: fontSettings,
              ),
              Expanded(
                child: ListView.builder(
                  // Clear of the floating create button.
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return PickerContactTile(
                      contact: member,
                      fontSettings: fontSettings,
                      onTap: () => _removeMember(member),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
