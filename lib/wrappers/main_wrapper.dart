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

  final List<String> _locations = ['/home', '/menu', '/events', '/settings'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 3) {
      showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return const SizedBox(
              height: 200,
              child: SettingsPopupMenu(),
            );
          });
    } else {
      context.go(_locations[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              size: 30.0,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.menu,
              size: 30.0,
            ),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.event,
              size: 30.0,
            ),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              size: 30.0,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
