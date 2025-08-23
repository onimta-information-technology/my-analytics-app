import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MenuScreenState();
  }
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //     // title: const Text(
      //     //   'Menu',
      //     //   style: TextStyle(fontSize: 20.0),
      //     // ),
      //     ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/home');
                        },
                        child: const Card(
                          color: Color.fromARGB(255, 5, 230, 247),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.home_filled,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Home',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          context.go('/reservations');
                        },
                        child: Card(
                          color: Colors.orange[700],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.luggage,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Reservations',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: const Card(
                          color: Color.fromARGB(255, 4, 158, 143),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.edit_document,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Reports',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/birthdays');
                        },
                        child: const Card(
                          color: Color.fromARGB(255, 240, 22, 6),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(Icons.cake, size: 60, color: Colors.white),
                                Text(
                                  'Birthdays',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/inactive-members');
                        },
                        child: const Card(
                          color: Color.fromARGB(255, 194, 44, 221),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Inactive Members',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/members');
                        },
                        child: const Card(
                          color: Color.fromARGB(255, 2, 177, 46),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Members',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/gifts');
                        },
                        child: const Card(
                          color: Color.fromARGB(255, 58, 58, 58),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  FontAwesomeIcons.gifts,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Gifts',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: const Card(
                          color: Color.fromARGB(176, 4, 123, 235),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Daily Walking Guests',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
