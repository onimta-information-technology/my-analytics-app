import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'dart:io';

import 'package:ballys_reservation_app/data/services/firebase_api_service.dart';
import 'package:ballys_reservation_app/providers/chat_font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// The signed-in user's chat profile: the name and photo other participants
/// see, plus the rest of the record the chat backend keeps.
///
/// Reached from the chats overflow menu. Tapping the photo replaces it, and the
/// screen pops `true` once it has been changed so the caller can refresh the
/// lists that carry avatar urls.
class ChatProfileScreen extends ConsumerStatefulWidget {
  const ChatProfileScreen({super.key});

  @override
  ConsumerState<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends ConsumerState<ChatProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;

  /// Whether the avatar was replaced while this screen was open — handed back
  /// to the chats screen on pop.
  bool _avatarChanged = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final profile = await FirebaseApiService.fetchUserProfile();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (profile == null) {
        _errorMessage = 'Could not load your profile. Pull down to retry.';
      } else {
        _profile = profile;
      }
    });
  }

  String? _value(String key) {
    final raw = _profile?[key];
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  String get _name => _value('name') ?? _value('firstName') ?? 'Unknown user';

  String? get _avatarUrl => _value('profileImageUrl');

  /// The backend has been seen writing a timestamp into `email`, so only show
  /// the field when it actually holds an address.
  String? get _email {
    final email = _value('email');
    return (email != null && email.contains('@')) ? email : null;
  }

  /// `location` arrives as an enum-ish `BALLYS_COLOMBO`; show it as words.
  String? get _location {
    final location = _value('location');
    if (location == null) return null;
    return location
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String? _formatDate(String key) {
    final raw = _value(key);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(chatFontSettingsProvider);

    return ChatFontScope(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) Navigator.pop(context, _avatarChanged);
        },
        child: Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text(
              'My Profile',
              style: TextStyle(
                fontSize: fontSettings.fontSize + 2,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
            backgroundColor: ChatColors.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context, _avatarChanged),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _loadProfile,
              ),
            ],
          ),
          body: _buildBody(fontSettings),
        ),
      ),
    );
  }

  Widget _buildBody(FontSettings fontSettings) {
    if (_isLoading && _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildHeader(fontSettings),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: fontSettings.fontSize - 3,
                ),
              ),
            ),
          if (_profile != null) _buildDetails(fontSettings),
        ],
      ),
    );
  }

  Widget _buildHeader(FontSettings fontSettings) {
    return Container(
      width: double.infinity,
      color: ChatColors.primary,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        children: [
          // The photo is the edit control: tapping it opens the picker and
          // uploads straight away.
          GestureDetector(
            onTap: _isUploading ? null : _changePhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                  child: _avatarUrl == null
                      ? Text(
                          _name.trim().isEmpty
                              ? '?'
                              : _name.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 40,
                            color: ChatColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (_isUploading)
                  const Positioned.fill(
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.black45,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: ChatColors.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: ChatColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSettings.fontSize + 4,
                fontWeight: fontSettings.fontWeight,
              ),
            ),
          ),
          // const SizedBox(height: 4),
          // Text(
          //   _profile?['isOnline'] == true ? 'Online' : 'Offline',
          //   style: TextStyle(
          //     color: Colors.white70,
          //     fontSize: fontSettings.fontSize - 5,
          //   ),
          // ),
          // const SizedBox(height: 8),
          // TextButton.icon(
          //   onPressed: _isUploading ? null : _changePhoto,
          //   icon: const Icon(Icons.edit, size: 16, color: Colors.white),
          //   label: Text(
          //     'Change photo',
          //     style: TextStyle(
          //       color: Colors.white,
          //       fontSize: fontSettings.fontSize - 4,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDetails(FontSettings fontSettings) {
    final rows = <Widget>[
      //_detailRow(Icons.phone, 'Phone', _value('phoneNo'), fontSettings),
     // _detailRow(Icons.email_outlined, 'Email', _email, fontSettings),
     // _detailRow(Icons.location_on_outlined, 'Location', _location,
       //   fontSettings),
      // _detailRow(Icons.badge_outlined, 'Sales code', _value('salesCode'),
      //     fontSettings),
      _detailRow(
          Icons.card_membership, 'Member ID', _value('memberId'), fontSettings),
      _detailRow(Icons.access_time, 'Last seen', _formatDate('lastSeen'),
          fontSettings),
      _detailRow(Icons.event_outlined, 'Joined', _formatDate('createdAt'),
          fontSettings),
    ].whereType<Widget>().toList();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  /// Renders one label/value row, or an empty box when the backend has no
  /// value for it — a blank row reads as a broken field.
  Widget _detailRow(
    IconData icon,
    String label,
    String? value,
    FontSettings fontSettings,
  ) {
    if (value == null) return const SizedBox.shrink();

    return ListTile(
      leading: Icon(icon, color: ChatColors.primary),
      title: Text(
        label,
        style: TextStyle(
          fontSize: fontSettings.fontSize - 5,
          color: Colors.black54,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: fontSettings.fontSize - 2,
          fontWeight: fontSettings.fontWeight,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// Picks an image and uploads it as the chat avatar, then re-reads the
  /// profile so the new url — not the cached one — is what gets shown.
  Future<void> _changePhoto() async {
    final picked = await _pickImage();
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);
    final result = await FirebaseApiService.updateUserAvatar(
      avatarPath: picked.path,
    );
    if (!mounted) return;
    setState(() => _isUploading = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result['success'] == true) {
      _avatarChanged = true;
      await _loadProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: ChatColors.primary,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not update the profile photo: ${result['error'] ?? ''}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<File?> _pickImage() async {
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
        imageQuality: 85,
      );
      return picked == null ? null : File(picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick an image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}
