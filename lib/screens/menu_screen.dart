import 'package:ballys_reservation_app/providers/guest_booking_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:ballys_reservation_app/providers/pending_count_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _salesCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);
    _loadSalesCode();
    // Fetch pending counts when screen loads
    Future.microtask(() {
      ref.read(pendingCountProvider.notifier).fetch();
      ref.read(guestBookingProvider.notifier).getAllBookings();
    });
  }

  Future<void> _loadSalesCode() async {
    final salesCode = await StorageUtil.getSalesCode();
    setState(() {
      _salesCode = salesCode;
      _isLoading = false;
    });
  }

  bool get _isReservationsBlocked => _salesCode == "CD001";

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

    // Watch pending counts
    final countsAsync = ref.watch(pendingCountProvider);
    final hasPendingItems = countsAsync.when(
      data: (counts) =>
          counts.reservation > 0 ||
          counts.otpGift > 0 ||
          counts.birthdayGift > 0,
      loading: () => false,
      error: (e, st) => false,
    );
final guestBookingState = ref.watch(guestBookingProvider);
final hasPendingGuestBookings = guestBookingState.pendingBookings.isNotEmpty;
    return Scaffold(
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
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                              context.go('/menu/approve-reject');
                            },
                            child: Card(
                              color: const Color.fromARGB(255, 201, 185, 8),
                              child: const SizedBox(
                                width: double.infinity,
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
                          // Red dot indicator for pending items
                       if (hasPendingItems)
  Positioned(
    top: 8,
    right: 8,
    child: FadeTransition(
      opacity: _controller,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    ),
  ),
                        ],
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
                                  'Daily Walking',
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
//                    Expanded(
//   child: Stack(                          // ✅ Wrap in Stack
//     children: [
//       GestureDetector(
//         onTap: () {
//           context.push('/guest-bookings');
//         },
//         child: const Card(
//           color: Color.fromARGB(174, 134, 132, 16),
//           child: Padding(
//             padding: EdgeInsets.symmetric(vertical: 30),
//             child: Column(
//               children: [
//                 Icon(
//                   Icons.book_online,
//                   size: 60,
//                   color: Colors.white,
//                 ),
//                 Text(
//                   'Guest Booking',
//                   style: TextStyle(
//                     fontSize: 16.0,
//                     fontWeight: FontWeight.normal,
//                     color: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//       // ✅ Blinking red dot when there are pending guest bookings
//       if (hasPendingGuestBookings)
//         Positioned(
//           top: 8,
//           right: 8,
//           child: FadeTransition(
//             opacity: _controller,        // reuses existing AnimationController
//             child: Container(
//               width: 16,
//               height: 16,
//               decoration: BoxDecoration(
//                 color: Colors.red,
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: Colors.white,
//                   width: 2,
//                 ),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//     ],
//   ),
// ),
 Expanded(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () {
                            context.push('/guest-bookings');
                            },
                            child: Card(
                             color: Color.fromARGB(174, 134, 132, 16),
                              child: const SizedBox(
                                width: double.infinity,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 30),
                                  child: Column(
                                    children: [
                                      Icon(
                  Icons.book_online,
                  size: 60,
                  color: Colors.white,
                ),
                                      Text(
                                        'Guest Booking',
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
                          // Red dot indicator for pending items
                       if (hasPendingGuestBookings)
  Positioned(
    top: 8,
    right: 8,
    child: FadeTransition(
      opacity: _controller,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    ),
  ),
                        ],
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
