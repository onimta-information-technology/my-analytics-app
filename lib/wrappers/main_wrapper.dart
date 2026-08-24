import 'package:ballys_reservation_app/components/popup_menu.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<StatefulWidget> createState() {
    return _MainScreenState();
  }
}

class _MainScreenState extends State<MainWrapper> {
  int _selectedIndex = 0;

  final List<String> _locations = [
    '/home',
    '/menu',
    '/menu/chats',
    '/academic',
    '/settings',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 4) {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          //return const SizedBox(height: 200, child: SettingsPopupMenu());
            return const SettingsPopupMenu();
        },
      );
    } else {
      context.go(_locations[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentLocation = GoRouterState.of(context).uri.toString();
    final bool isChatScreen = currentLocation == "/chats";
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: isChatScreen
          ? null
          : BottomNavigationBar(
              // 5 items with labels visible on every tab, selected or not.
             type: BottomNavigationBarType.fixed,
              selectedFontSize: 12.0,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home, size: 30.0),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu, size: 30.0),
                  label: 'Menu',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat, size: 30.0),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.school, size: 30.0),
                  label: 'Academy',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings, size: 30.0),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}
