import 'package:flutter/material.dart';

/// Circular avatar for a person.
///
/// Shows [avatarUrl] when the user has uploaded a profile picture, and falls
/// back to the coloured initials otherwise — the same pair everywhere a user
/// is listed (chat rows, headers, member pickers), so a photo set once shows
/// up consistently.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final Color backgroundColor;
  final double radius;

  /// Size of the initials when no picture is set. Callers pass the value from
  /// the font settings so the fallback scales with the rest of the row.
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.backgroundColor,
    this.radius = 20,
    this.fontSize,
  });

  bool get _hasImage => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: _hasImage ? NetworkImage(avatarUrl!.trim()) : null,
      // A broken/expired url would otherwise leave an empty circle.
      onBackgroundImageError: _hasImage ? (_, __) {} : null,
      child: _hasImage
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
