import 'package:flutter/material.dart';

/// Circular avatar for a group.
///
/// Shows [avatarUrl] when the group has a picture, and otherwise falls back to
/// a WhatsApp-style two-people glyph rather than the group's initials — a
/// group reads as a group at a glance that way, even before anyone sets a
/// photo. The same fallback is used everywhere a group is listed, so the list,
/// the chat header and the details sheet stay in sync.
class GroupAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;

  /// Circle colour behind the placeholder glyph. Callers pass the group's
  /// generated colour so groups stay distinguishable.
  final Color backgroundColor;

  const GroupAvatar({
    super.key,
    required this.avatarUrl,
    required this.radius,
    required this.backgroundColor,
  });

  bool get _hasImage => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: _hasImage ? NetworkImage(avatarUrl!) : null,
      // A broken/expired url would otherwise leave an empty circle.
      onBackgroundImageError: _hasImage ? (_, __) {} : null,
      child: _hasImage
          ? null
          : Icon(
              Icons.group,
              // Roughly the proportion WhatsApp gives its placeholder.
              size: radius * 1.1,
              color: Colors.white,
            ),
    );
  }
}
