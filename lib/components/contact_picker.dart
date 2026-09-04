import 'dart:io';

import 'package:ballys_reservation_app/components/user_avatar.dart';
import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/models/chat_contact.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// The pieces the "New chat" and "New group" screens are built from.
///
/// Both screens are the same list of people with a different tap action, so
/// the row, the section label and the empty state live here rather than being
/// written twice with two sets of paddings that would drift apart.

/// WhatsApp's light-surface neutrals. Kept next to [ChatColors] rather than in
/// it because these are picker chrome, not conversation colours.
const Color kPickerTitle = Color(0xFF111B21);
const Color kPickerSubtitle = Color(0xFF667781);
const Color kPickerRule = Color(0xFFE9EDEF);

/// Name search shared by both screens.
List<ChatContact> matchContacts(List<ChatContact> contacts, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.from(contacts);
  return contacts
      .where(
        (user) =>
            user.name.toLowerCase().contains(q) ||
            user.firstName.toLowerCase().contains(q),
      )
      .toList();
}

/// Two-line app bar title: name on top, count or state underneath.
class PickerAppBarTitle extends StatelessWidget {
  const PickerAppBarTitle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fontSettings,
  });

  final String title;
  final String subtitle;
  final FontSettings fontSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: fontSettings.fontSize + 2,
            fontWeight: fontSettings.fontWeight,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: fontSettings.fontSize - 5,
            fontWeight: FontWeight.normal,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

/// The field the app bar turns into once the search icon is tapped.
class PickerSearchField extends StatelessWidget {
  const PickerSearchField({
    super.key,
    required this.controller,
    required this.fontSettings,
    required this.onChanged,
    this.hint = 'Search name',
  });

  final TextEditingController controller;
  final FontSettings fontSettings;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      cursorColor: Colors.white,
      style: TextStyle(color: Colors.white, fontSize: fontSettings.fontSize),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white70,
          fontSize: fontSettings.fontSize,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// Grey run-in header above a run of rows ("CONTACTS", "MEMBERS: 4").
class PickerSectionLabel extends StatelessWidget {
  const PickerSectionLabel({
    super.key,
    required this.label,
    required this.fontSettings,
  });

  final String label;
  final FontSettings fontSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSettings.fontSize - 5,
          fontWeight: FontWeight.w500,
          color: kPickerSubtitle,
        ),
      ),
    );
  }
}

/// Centred "nothing here" line, sized to sit in a list slot.
class PickerMessage extends StatelessWidget {
  const PickerMessage({
    super.key,
    required this.message,
    required this.fontSettings,
  });

  final String message;
  final FontSettings fontSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSettings.fontSize - 2,
            color: kPickerSubtitle,
          ),
        ),
      ),
    );
  }
}

/// An action at the top of the new-chat list — "New group" and anything that
/// joins it later. A green disc instead of a photo, so it reads as a command
/// rather than a person.
class PickerActionRow extends StatelessWidget {
  const PickerActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.fontSettings,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final FontSettings fontSettings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: ChatColors.accent,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: FontWeight.w500,
          color: kPickerTitle,
        ),
      ),
    );
  }
}

/// One person. [selected] draws the green tick badge the member picker uses
/// instead of a trailing checkbox.
class PickerContactTile extends StatelessWidget {
  const PickerContactTile({
    super.key,
    required this.contact,
    required this.fontSettings,
    required this.onTap,
    this.selected = false,
  });

  final ChatContact contact;
  final FontSettings fontSettings;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          children: [
            UserAvatar(
              avatarUrl: contact.avatarUrl,
              initials: contact.initials,
              backgroundColor: contact.avatarColor,
              radius: 24,
              fontSize: fontSettings.fontSize - 4,
            ),
            if (selected)
              const Positioned(right: 0, bottom: 0, child: _TickBadge()),
          ],
        ),
      ),
      title: Text(
        contact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSettings.fontSize,
          fontWeight: fontSettings.fontWeight,
          color: kPickerTitle,
        ),
      ),
      subtitle: Text(
        contact.isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize: fontSettings.fontSize - 4,
          color: contact.isOnline ? ChatColors.primaryDark : kPickerSubtitle,
        ),
      ),
    );
  }
}

class _TickBadge extends StatelessWidget {
  const _TickBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const CircleAvatar(
        radius: 8,
        backgroundColor: ChatColors.accent,
        child: Icon(Icons.check, size: 11, color: Colors.white),
      ),
    );
  }
}

/// The strip of picked people above the member list. Tapping one drops it,
/// which is the only way WhatsApp lets you deselect from up there.
class PickerSelectedStrip extends StatelessWidget {
  const PickerSelectedStrip({
    super.key,
    required this.members,
    required this.fontSettings,
    required this.onRemove,
  });

  final List<ChatContact> members;
  final FontSettings fontSettings;
  final ValueChanged<ChatContact> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 84,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => onRemove(member),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            children: [
                              UserAvatar(
                                avatarUrl: member.avatarUrl,
                                initials: member.initials,
                                backgroundColor: member.avatarColor,
                                radius: 24,
                                fontSize: fontSettings.fontSize - 4,
                              ),
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: _RemoveBadge(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.firstName.isNotEmpty
                            ? member.firstName
                            : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 6,
                          color: kPickerSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: kPickerRule),
      ],
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const CircleAvatar(
        radius: 8,
        backgroundColor: kPickerSubtitle,
        child: Icon(Icons.close, size: 11, color: Colors.white),
      ),
    );
  }
}

/// Camera / gallery sheet plus the pick itself, downscaled ready for upload.
///
/// Shared by the group screen and the chat header's "change photo", so an
/// avatar is capped the same way wherever it is set.
Future<File?> pickChatAvatarImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  try {
    // Downscaled before upload — the backend caps the avatar at 5MB.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    return picked == null ? null : File(picked.path);
  } catch (e) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not pick image: $e'),
        backgroundColor: Colors.red,
      ),
    );
    return null;
  }
}
