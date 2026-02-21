import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/guest_booking_repository.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/guest_booking_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GuestBookingScreen extends ConsumerStatefulWidget {
  final GuestBookingRepository bookingRepository;

  const GuestBookingScreen({
    super.key,
    required this.bookingRepository,
  });

  @override
  ConsumerState<GuestBookingScreen> createState() => _GuestBookingScreenState();
}

class _GuestBookingScreenState extends ConsumerState<GuestBookingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bookingState = ref.read(guestBookingProvider);

      if (bookingState.pendingBookings.isNotEmpty ||
          bookingState.acceptedBookings.isNotEmpty) {
        return;
      }

      _loadBookingData();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";

    try {
      final dateTime = DateTime.parse(dateStr);
      return DateFormat("yyyy-MM-dd").format(dateTime);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "N/A";

    try {
      final dateTime = DateTime.parse(dateStr);
      return DateFormat("yyyy-MM-dd hh:mm a").format(dateTime);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _loadBookingData() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(guestBookingProvider.notifier).getAllBookings();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSettings = ref.watch(fontSettingsProvider);
    final bookingState = ref.watch(guestBookingProvider);

    return Scaffold(
      appBar: AppBar(
         leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Guest Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _loadBookingData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          tabs: [
            _buildTab('Pending', bookingState.pendingBookings.length, Colors.orange),
            _buildTab('Accepted', bookingState.acceptedBookings.length, Colors.green),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildBookingList(bookingState.pendingBookings, isPending: true),
              _buildBookingList(bookingState.acceptedBookings, isPending: false),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(135, 117, 115, 115),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          const Watermark(),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Text(
              count.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(
    List<GuestBooking> bookings, {
    required bool isPending,
  }) {
    final fontSettings = ref.watch(fontSettingsProvider);

    if (bookings.isEmpty) {
      return const Center(child: Text("No bookings found"));
    }

    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final result = await context.push(
              '/guest-bookings/view-booking',
              extra: {
                'booking': booking,
                'isPending': isPending,
              },
            );
            if (result == true) {
              _loadBookingData();
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 16,
            ),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              title: Text(
                booking.mid,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: fontSettings.fontSize + 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Start: ',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDate(booking.pkgStart),
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.event,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'End: ',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDate(booking.pkgEnd),
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Inserted: ',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDateTime(booking.insertDate),
                          style: TextStyle(
                         //   color: const Color.fromARGB(137, 0, 0, 0),
                            fontSize: fontSettings.fontSize,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(isPending ? 'Pending' : 'Accepted'),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(isPending ? 'Pending' : 'Accepted'),
                          size: 16,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPending ? 'Pending' : 'Accepted',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            color: const Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Accepted':
        return Icons.check_circle;
      case 'Pending':
        return Icons.hourglass_bottom;
      default:
        return Icons.info;
    }
  }
}