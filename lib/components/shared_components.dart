import 'package:flutter/material.dart';

AppBar buildAppBar(BuildContext context, String title) {
  return AppBar(
    elevation: 10.0,
    title: Text(
      title,
      style: const TextStyle(fontSize: 15.0),
    ),
    backgroundColor: Colors.white,
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {},
      ),
      IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () {},
      ),
    ],
  );
}

// BottomNavigationBar buildBottomNav(BuildContext context) {
//   return BottomNavigationBar(
//     items: const [
//       BottomNavigationBarItem(
//         icon: Icon(Icons.home),
//         label: 'Home',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.menu),
//         label: 'Menu',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.event),
//         label: 'Events',
//       ),
//       BottomNavigationBarItem(
//         icon: Icon(Icons.settings),
//         label: 'Settings',
//       ),
//     ],
//     onTap: (index) {
//       if (index == 1) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (context) => MenuScreen()),
//         );
//       } else if (index == 3) {
//         // Show bottom sheet for settings
//         showModalBottomSheet(
//           context: context,
//           shape: const RoundedRectangleBorder(
//             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//           ),
//           builder: (BuildContext context) {
//             return const SettingsPopupMenu();
//           },
//         );
//       }
//     },
//   );
// }
