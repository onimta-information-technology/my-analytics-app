import 'package:ballys_reservation_app/components/contact_picker.dart';
import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/providers/chat_font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What [NewChatScreen] was closed with: either a person to open a 1:1 with,
/// or the request to go on to the group flow.
class NewChatResult {
  const NewChatResult.contact(ChatContact this.contact) : startGroup = false;
  const NewChatResult.newGroup() : contact = null, startGroup = true;

  final ChatContact? contact;
  final bool startGroup;
}

/// WhatsApp's "New chat" screen: the action rows, then everyone you can write
/// to. Search lives in the app bar and hides the actions while it is running,
/// so a search only ever returns people.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key, required this.contacts});

  final List<ChatContact> contacts;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
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

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(chatFontSettingsProvider);
    final total = widget.contacts.length;
    // The actions belong to the unfiltered list only.
    final int headerCount = _isSearching ? 0 : 2;
    final bool noResults = _visible.isEmpty;

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
                      title: 'New chat',
                      subtitle: '$total contact${total == 1 ? '' : 's'}',
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
            body: ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: headerCount + (noResults ? 1 : _visible.length),
              itemBuilder: (context, index) {
                if (headerCount > 0 && index == 0) {
                  return PickerActionRow(
                    icon: Icons.group,
                    label: 'New group',
                    fontSettings: fontSettings,
                    onTap: () =>
                        Navigator.pop(context, const NewChatResult.newGroup()),
                  );
                }
                if (headerCount > 0 && index == 1) {
                  return PickerSectionLabel(
                    label: 'CONTACTS',
                    fontSettings: fontSettings,
                  );
                }
                if (noResults) {
                  return PickerMessage(
                    message: widget.contacts.isEmpty
                        ? 'No contacts available'
                        : 'No contacts found',
                    fontSettings: fontSettings,
                  );
                }
                final contact = _visible[index - headerCount];
                return PickerContactTile(
                  contact: contact,
                  fontSettings: fontSettings,
                  onTap: () =>
                      Navigator.pop(context, NewChatResult.contact(contact)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
