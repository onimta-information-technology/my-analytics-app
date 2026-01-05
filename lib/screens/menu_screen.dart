import 'package:ballys_reservation_app/utils/storage_util.dart';
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
  String? _salesCode;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _loadSalesCode();
  }

  Future<void> _loadSalesCode() async {
    final salesCode = await StorageUtil.getSalesCode();
    setState(() {
      _salesCode = salesCode;
      _isLoading = false;
    });
  }

  bool get _isReservationsBlocked => _salesCode == "CD001";

  // void _handleReservationsTap() {
  //   if (_isReservationsBlocked) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Row(
  //           children: const [
  //             Icon(Icons.block, color: Colors.white),
  //             SizedBox(width: 8),
  //             Expanded(
  //               child: Text(
  //                 'Access denied: Reservations not available for your account',
  //               ),
  //             ),
  //           ],
  //         ),
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 3),
  //         behavior: SnackBarBehavior.floating,
  //         margin: const EdgeInsets.all(16),
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //       ),
  //     );
  //   } else {
  //     context.go('/reservations');
  //   }
  // }
// void _handleApproveTap() {
//     if (_isReservationsBlocked) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Row(
//             children: const [
//               Icon(Icons.block, color: Colors.white),
//               SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   'Access denied: Approve tab not available for your account',
//                 ),
//               ),
//             ],
//           ),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.all(16),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
//     } else {
//       context.go('/menu/approve-reject');
//     }
//   }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
                    // Expanded(
                    //   child: Opacity(
                    //     opacity: _isReservationsBlocked ? 0.5 : 1.0,
                    //     child: InkWell(
                    //       onTap: _handleReservationsTap,
                    //       child: Card(
                    //         color: _isReservationsBlocked
                    //             ? Colors.grey
                    //             : Colors.orange[700],
                    //         child: Padding(
                    //           padding: const EdgeInsets.symmetric(vertical: 30),
                    //           child: Stack(
                    //             alignment: Alignment.center,
                    //             children: [
                    //               Column(
                    //                 children: [
                    //                   Icon(
                    //                     Icons.luggage,
                    //                     size: 60,
                    //                     color: Colors.white,
                    //                   ),
                    //                   const Text(
                    //                     'Reservations',
                    //                     style: TextStyle(
                    //                       fontSize: 16.0,
                    //                       fontWeight: FontWeight.normal,
                    //                       color: Colors.white,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               if (_isReservationsBlocked)
                    //                 Positioned(
                    //                   top: 8,
                    //                   right: 8,
                    //                   child: Icon(
                    //                     Icons.lock,
                    //                     size: 24,
                    //                     color: Colors.white.withOpacity(0.8),
                    //                   ),
                    //                 ),
                    //             ],
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                           context.go('/reports');
                        },
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
                                  'Package Guest',
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
                     Expanded(
                      child: GestureDetector(
                        onTap: () {
                           context.go('/menu/approve-reject');
                        },
                        child: const Card(
                          color: Color.fromARGB(255, 201, 185, 8),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                Text(
                                  'Approve',
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
                    //  Expanded(
                    //   child: Opacity(
                    //     opacity: _isReservationsBlocked ? 0.5 : 1.0,
                    //     child: InkWell(
                    //       onTap: _handleApproveTap,
                    //       child: Card(
                    //         color: _isReservationsBlocked
                    //             ? Colors.grey
                    //             :Color.fromARGB(255, 201, 185, 8),
                    //         child: Padding(
                    //           padding: const EdgeInsets.symmetric(vertical: 30),
                    //           child: Stack(
                    //             alignment: Alignment.center,
                    //             children: [
                    //               Column(
                    //                 children: [
                    //                   Icon(
                    //                     Icons.check,
                    //                     size: 60,
                    //                     color: Colors.white,
                    //                   ),
                    //                   const Text(
                    //                     'Approve',
                    //                     style: TextStyle(
                    //                       fontSize: 16.0,
                    //                       fontWeight: FontWeight.normal,
                    //                       color: Colors.white,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //               if (_isReservationsBlocked)
                    //                 Positioned(
                    //                   top: 8,
                    //                   right: 8,
                    //                   child: Icon(
                    //                     Icons.lock,
                    //                     size: 24,
                    //                     color: Colors.white.withOpacity(0.8),
                    //                   ),
                    //                 ),
                    //             ],
                    //           ),
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
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
                             //   SizedBox(height: 10),
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
                        onTap: () {
                          context.go('/daily-gests');
                        },

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
