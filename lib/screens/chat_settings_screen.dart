import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:ballys_reservation_app/providers/chat_font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/chat_notification_sound_provider.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/chat_notification_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Chat's own font, notification-tone and device-permission settings, reached from the overflow
/// menu in the chat list and inside a conversation. The typography here is
/// deliberately separate from the app-wide
/// "Font Size Settings" on the app Settings screen: changing one leaves the other
/// alone, so the conversation can read like a messenger while the rest of the
/// app keeps its display face.
class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  static const _weights = <FontWeight, String>{
    FontWeight.normal: 'Normal',
    FontWeight.w500: 'Medium',
    FontWeight.bold: 'Bold',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatFontSettingsProvider);
    final notifier = ref.read(chatFontSettingsProvider.notifier);
    final sound = ref.watch(chatNotificationSoundProvider);
    final soundNotifier = ref.read(chatNotificationSoundProvider.notifier);

    return ChatFontScope(
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: ChatColors.primary,
          foregroundColor: Colors.white,
          title: const Text(
            'Chat settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _sectionLabel('Preview'),
            _buildPreview(settings),
            const SizedBox(height: 8),
            _sectionLabel('Font size'),
            _buildCard(
              child: Column(
                children: [
                  for (final size in ChatFontSize.all)
                    _optionTile(
                      label: ChatFontSize.labelFor(size),
                      selected: settings.fontSize == size,
                      onTap: () => notifier.setFontSize(size),
                      style: TextStyle(
                        fontSize: size,
                        fontWeight: settings.fontWeight,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _sectionLabel('Font weight'),
            _buildCard(
              child: Column(
                children: [
                  for (final entry in _weights.entries)
                    _optionTile(
                      label: entry.value,
                      selected: settings.fontWeight == entry.key,
                      onTap: () => notifier.setFontWeight(entry.key),
                      style: TextStyle(
                        fontSize: settings.fontSize,
                        fontWeight: entry.key,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _sectionLabel('Notification sound'),
            _buildCard(
              child: Column(
                children: [
                  for (final option in ChatNotificationSound.values)
                    _soundTile(
                      option: option,
                      selected: sound == option,
                      onTap: () => soundNotifier.select(option),
                      onPlay: option == ChatNotificationSound.appTone
                          ? soundNotifier.preview
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _sectionLabel('Camera & microphone'),
            _buildCard(child: const _DevicePermissionsCard()),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: notifier.resetToDefaults,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset to default'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChatColors.primaryDark,
                  side: const BorderSide(color: ChatColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'This size applies to chats only. The rest of the app follows '
                'the font size in Settings. The notification sound applies to '
                'chat messages only and is kept by the reset above.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required TextStyle style,
  }) => ListTile(
    onTap: onTap,
    title: Text(label, style: style),
    trailing: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: selected ? ChatColors.primary : Colors.grey.shade400,
    ),
  );

  /// One tone choice. The app's own tone gets a play button, so the user can
  /// hear it before living with it; the phone default is whatever the system
  /// plays and cannot be sampled from here.
  Widget _soundTile({
    required ChatNotificationSound option,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onPlay,
  }) => ListTile(
    onTap: onTap,
    title: Text(
      option.label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    subtitle: Text(
      option.description,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPlay != null)
          IconButton(
            onPressed: onPlay,
            icon: const Icon(Icons.play_circle_outline),
            color: ChatColors.primaryDark,
            tooltip: 'Play',
          ),
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? ChatColors.primary : Colors.grey.shade400,
        ),
      ],
    ),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ChatColors.primaryDark,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _buildCard({required Widget child}) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );

  /// Two bubbles in the conversation's own colours, so the size choice is read
  /// against the thing it actually changes.
  Widget _buildPreview(FontSettings settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ChatColors.chatBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bubble(
            text: 'How does this size look?',
            settings: settings,
            isMine: false,
          ),
          const SizedBox(height: 8),
          _bubble(
            text: 'Easy to read now 👍',
            settings: settings,
            isMine: true,
          ),
        ],
      ),
    );
  }

  Widget _bubble({
    required String text,
    required FontSettings settings,
    required bool isMine,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? ChatColors.outgoingBubble : ChatColors.incomingBubble,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: settings.fontSize,
                fontWeight: settings.fontWeight,
                color: ChatColors.bubbleText,
              ),
            ),
            Text(
              '10:24 AM',
              style: TextStyle(
                fontSize: settings.fontSize - 5,
                color: ChatColors.bubbleMeta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Camera (photos in chat) and microphone (voice messages) access, read from
/// the OS. An app can ask for a permission but never take one back, and once
/// the user has refused for good only the phone's Settings can grant it — so
/// the switch prompts when it can and otherwise sends the user to Settings,
/// re-reading the status when they come back.
class _DevicePermissionsCard extends StatefulWidget {
  const _DevicePermissionsCard();

  @override
  State<_DevicePermissionsCard> createState() => _DevicePermissionsCardState();
}

class _DevicePermissionsCardState extends State<_DevicePermissionsCard>
    with WidgetsBindingObserver {
  final Map<Permission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final camera = await Permission.camera.status;
    final microphone = await Permission.microphone.status;
    if (!mounted) return;
    setState(() {
      _statuses[Permission.camera] = camera;
      _statuses[Permission.microphone] = microphone;
    });
  }

  static bool _isAllowed(PermissionStatus? status) =>
      status != null &&
      (status.isGranted || status.isLimited || status.isProvisional);

  Future<void> _onToggle(Permission permission, String name, bool allow) async {
    final status = _statuses[permission];
    if (allow && status != null && status.isDenied) {
      final result = await permission.request();
      if (!mounted) return;
      setState(() => _statuses[permission] = result);
      // The OS may refuse without showing a prompt (Android after "Don't ask
      // again", or a refusal already on record), which would leave the tap
      // looking dead — point the user at Settings instead.
      if (!_isAllowed(result)) _showSettingsHint(name);
      return;
    }
    if (allow && status != null && status.isRestricted) {
      _showMessage(
        '$name access is restricted on this device (for example by '
        'Screen Time or a device policy) and cannot be changed here.',
      );
      return;
    }
    await _confirmOpenSettings(
      allow
          ? '$name access was turned off for this app. Turn it on in your '
                'phone settings.'
          : 'To stop the app using the ${name.toLowerCase()}, turn it off in '
                'your phone settings.',
    );
  }

  Future<void> _confirmOpenSettings(String message) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open phone settings?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Open settings',
              style: TextStyle(color: ChatColors.primaryDark),
            ),
          ),
        ],
      ),
    );
    if (open == true) await openAppSettings();
  }

  void _showSettingsHint(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$name access is off. You can allow it in phone settings.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        ),
      );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tile(
          permission: Permission.camera,
          icon: Icons.camera_alt_outlined,
          name: 'Camera',
          purpose: 'Take photos to send in chat',
        ),
        Divider(height: 1, indent: 56, color: Colors.grey.shade200),
        _tile(
          permission: Permission.microphone,
          icon: Icons.mic_none,
          name: 'Microphone',
          purpose: 'Record voice messages',
        ),
      ],
    );
  }

  Widget _tile({
    required Permission permission,
    required IconData icon,
    required String name,
    required String purpose,
  }) {
    final status = _statuses[permission];
    final allowed = _isAllowed(status);
    final String statusText;
    if (status == null) {
      statusText = 'Checking…';
    } else if (allowed) {
      statusText = 'Allowed';
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      statusText = 'Denied · change in phone settings';
    } else {
      statusText = 'Not allowed';
    }

    return ListTile(
      leading: Icon(icon, color: ChatColors.primaryDark),
      title: Text(
        name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '$purpose\n$statusText',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      isThreeLine: true,
      trailing: Switch(
        value: allowed,
        activeThumbColor: Colors.white,
        activeTrackColor: ChatColors.primary,
        onChanged: status == null
            ? null
            : (value) => _onToggle(permission, name, value),
      ),
    );
  }
}
