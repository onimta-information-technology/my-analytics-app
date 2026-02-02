import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  final bool hideAddButton;
  const ReservationScreen({super.key, this.hideAddButton = false});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reservations = ref.watch(reservationProvider);

      if (reservations['Pending']!.isNotEmpty ||
          reservations['Approved']!.isNotEmpty ||
          reservations['Rejected']!.isNotEmpty) {
        return;
      }
      _loadReservationData();
    });
  }

  Future<void> _loadReservationData() async {
    setState(() {
      _isLoading = true;
    });
    await ref.read(reservationProvider.notifier).getReservationData();
    setState(() {
      _isLoading = false;
    });
  }

  // Add this method to check access permission
  Future<bool> _canAccessReservationDetails(Reservation reservation) async {
    // Check if user has Gift_App permission
    final giftApp = await StorageUtil.getGiftApp();
    if (giftApp == true) {
      return true;
    }

    // Check if current user is the requester
    final currentUserName = await StorageUtil.getUserName();
    if (currentUserName != null && 
        reservation.reqBy.isNotEmpty && 
        currentUserName.trim().toLowerCase() == reservation.reqBy.trim().toLowerCase()) {
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final Map<String, String> ratingImageMap = {
    "CLASSIC": "assets/images/ratings/CLASSIC.png",
    "DIAMOND": "assets/images/ratings/DIAMOND.png",
    "GOLD": "assets/images/ratings/GOLD.png",
    "INFINITY": "assets/images/ratings/INFINITY.png",
    "PLATINUM": "assets/images/ratings/PLATINUM.png",
    "SILVER": "assets/images/ratings/SILVER.png",
  };

  @override
  Widget build(BuildContext context) {
    final reservations = ref.watch(reservationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: () async {
              await _loadReservationData();
            },
          ),
          if (!widget.hideAddButton)
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 35),
              onPressed: () async {
                final result = await context.push(
                  '/reservations/new-reservation',
                );
                if (result == true) {
                  await _loadReservationData();
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pink,
          tabs: [
            _buildTab(
              'Pending',
              reservations['Pending']?.length ?? 0,
              Colors.orange,
            ),
            _buildTab(
              'Approved',
              reservations['Approved']?.length ?? 0,
              Colors.green,
            ),
            _buildTab(
              'Rejected',
              reservations['Rejected']?.length ?? 0,
              Colors.red,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildReservationList(reservations['Pending'] ?? []),
              _buildReservationList(reservations['Approved'] ?? []),
              _buildReservationList(reservations['Rejected'] ?? []),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(135, 117, 115, 115),
                ),
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

  Widget _buildTab(String label, int count, Color bubbleColor) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 6),
          if (count > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: count > 9 ? 6 : 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(15),
              ),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
                maxWidth: 30,
                maxHeight: 30,
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReservationList(List<Reservation> reservations) {
    final fontSettings = ref.watch(fontSettingsProvider);
    if (reservations.isEmpty) {
      return const Center(child: Text('No reservations available.'));
    }

    return ListView.builder(
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        
        return Stack(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                title: Text(
                  'Reservation: ${reservation.reservNo}',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: fontSettings.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${reservation.mid} - ${reservation.mName}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSettings.fontSize,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Request By section
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Requested by: ',
                          style: TextStyle(
                            fontSize: fontSettings.fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reservation.reqBy,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Approved/Rejected By section
                    if (reservation.requestStatus == 'Approved' ||
                        reservation.requestStatus == 'Rejected')
                      Row(
                        children: [
                          Icon(
                            reservation.requestStatus == 'Approved'
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            size: 20,
                            color: reservation.requestStatus == 'Approved'
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reservation.requestStatus} by: ',
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              reservation.isAppBy ?? 'N/A',
                              style: TextStyle(
                                fontSize: fontSettings.fontSize,
                                color: reservation.requestStatus == 'Approved'
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                              overflow: TextOverflow.ellipsis,
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
                        color: _getStatusColor(reservation.requestStatus),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(reservation.requestStatus),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reservation.requestStatus,
                            style: TextStyle(
                              fontSize: fontSettings.fontSize,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  // Check access permission before navigation
                  final canAccess = await _canAccessReservationDetails(reservation);
                  
                  if (!canAccess) {
                    if (mounted) {
                     
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  "Access Denied",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Got It",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
                    }
                    return;
                  }

                  // Navigate if user has access
                  ref
                      .read(selectedReservationProvider.notifier)
                      .setSelectedReservation(reservation);

                  final result = await context.push(
                    "/reservations/reservation-view",
                  );

                  if (result == true) {
                    await _loadReservationData();
                  }
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 15,
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: SizedBox(
                  width: 100,
                  height: 30,
                  child: ratingImageMap[reservation.gRating] != null
                      ? Hero(
                          tag: "rating-image-${reservation.mid}",
                          child: Image.asset(
                            ratingImageMap[reservation.gRating]!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Hero(
                          tag: "rating-image-${reservation.mid}",
                          child: Image.asset(
                            "assets/images/ratings/CLASSIC.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.hourglass_bottom;
    }
  }
}