import 'package:ballys_reservation_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPopupMenu extends ConsumerWidget {
  const SettingsPopupMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      return SafeArea(
    child : Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           ListTile(
            leading: Icon(Icons.web, color: Colors.grey[700]),
            title: const Text('Academic'),
            onTap: () {
              context.push('/academic');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: Colors.grey[700]),
            title: const Text('Settings'),
            onTap: () {
              context.push('/settings');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.support, color: Colors.grey[700]),
            title: const Text('Support'),
            onTap: () {
              context.push('/support');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.grey[700]),
            title: const Text('Logout'),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    ),
    );
  }
}
