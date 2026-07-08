import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/reservation.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/reservation_provider.dart';
import 'package:ballys_reservation_app/providers/selected_flight_provider.dart';
import 'package:ballys_reservation_app/providers/selected_hotel_provider.dart';
import 'package:ballys_reservation_app/providers/selected_reservation_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
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
    with SingleTickerProviderStateMixin,ConnectivityMixin {
  late TabController _tabController;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
String _searchQuery = '';
bool _isSearching = false;

@override
  void onConnectivityRestored() {
   _loadReservationData();
  }
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reservations = ref.watch(reservationProvider);
      if (reservations['Pending']!.isNotEmpty ||
          reservations['Approved']!.isNotEmpty ||
          reservations['Rejected']!.isNotEmpty||reservations['Checked']!.isNotEmpty) {
        return;
      }
      _loadReservationData();
    });
  }

  Future<void> _loadReservationData() async {
    setState(() => _isLoading = true);
    await ref.read(reservationProvider.notifier).getReservationData();
    setState(() => _isLoading = false);
  }

  Future<List<Reservation>> _filterReservations(
    List<Reservation> reservations,
  ) async {
    final salesCode = await StorageUtil.getSalesCode();
    if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
      return reservations;
    }
     final resChk = await StorageUtil.getResChk();
  final resApp = await StorageUtil.getResApp();
  print("Filtering reservations for user. resChk: $resChk, resApp: $resApp"
  );
  if (resChk == true || resApp == true) {
    return reservations;
  }
   final currentUserName = await StorageUtil.getUserName();
    if (currentUserName == null) return [];
    return reservations.where((reservation) {
      return reservation.reqBy.trim().toLowerCase() ==
          currentUserName.trim().toLowerCase();
    }).toList();
  
  }

  // Future<bool> _canAccessReservationDetails(Reservation reservation) async {
  //   final giftApp = await StorageUtil.getGiftApp();
  //   if (giftApp == true) return true;
  //   final currentUserName = await StorageUtil.getUserName();
  //   if (currentUserName != null &&
  //       reservation.reqBy.isNotEmpty &&
  //       currentUserName.trim().toLowerCase() ==
  //           reservation.reqBy.trim().toLowerCase()) {
  //     return true;
  //   }
  //   return false;
  // }
Future<bool> _canAccessReservationDetails(
  Reservation reservation,
  int tabIndex, // 0=Pending, 1=Checked, 2=Approved, 3=Rejected
) async {
  // AD001 can access everything
  final salesCode = await StorageUtil.getSalesCode();
  if (salesCode != null && salesCode.trim().toUpperCase() == 'AD001') {
    return true;
  }

  final currentUserName = await StorageUtil.getUserName();
  if (currentUserName == null) return false;

  final normalizedUser   = currentUserName.trim().toLowerCase();
  final normalizedReqBy  = reservation.reqBy.trim().toLowerCase();
  final normalizedIsAppBy = reservation.isAppBy?.trim().toLowerCase() ?? '';

  final isRequester        = normalizedUser == normalizedReqBy;
  final isApproverOrHandler = normalizedUser == normalizedIsAppBy;

  switch (tabIndex) {
    case 0: // Pending
      final resChk = await StorageUtil.getResChk();
      return (resChk == true) || isRequester;

    case 1: // Checked
      final resApp = await StorageUtil.getResApp();
      return (resApp == true) || isRequester || isApproverOrHandler;

    case 2: // Approved
      final resApp = await StorageUtil.getResApp();
      return (resApp == true) || isRequester || isApproverOrHandler;

    case 3: // Rejected
      return isRequester || isApproverOrHandler;

    default:
      return false;
  }
}
  @override
  void dispose() {
    _tabController.dispose();
     _searchController.dispose(); 
    super.dispose();
  }

  /// Format DateTime to "DD/MM/YYYY  HH:MM"
String _formatDateTime(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final hourStr = hour12.toString().padLeft(2, '0');
  return '$day/$month/$year  $hourStr:$minute $period';
}

  // final Map<String, String> ratingImageMap = {
  //   "CLASSIC": "assets/images/ratings/CLASSIC.png",
  //   "DIAMOND": "assets/images/ratings/DIAMOND.png",
  //   "GOLD": "assets/images/ratings/GOLD.png",
  //   "INFINITY": "assets/images/ratings/INFINITY.png",
  //   "PLATINUM": "assets/images/ratings/PLATINUM.png",
  //   "SILVER": "assets/images/ratings/SILVER.png",
  // };
 Color _getRatingColor(String rating) {
    switch (rating.toUpperCase()) {
      case 'GOLD':
        return const Color(0xFFDAA520);
      case 'PLATINUM':
        return const Color(0xFF707070);
      case 'DIAMOND':
        return const Color(0xFF1565C0);
      case 'SILVER':
        return const Color(0xFF9E9E9E);
      case 'INFINITY':
        return const Color(0xFF4A148C);
      case 'PREMIER':
        return const Color(0xFF1B5E20);
      case 'RAFFELS CLUB':
        return const Color(0xFF880E4F);
      case 'CLASSIC':
        return const Color(0xFF5D4037);
      default:
        return Colors.grey;
    }
  }
  @override
  Widget build(BuildContext context) {
    final reservations = ref.watch(reservationProvider);

    return Scaffold(
      appBar: AppBar(
         leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/menu');
            }
          },
        ),
title: _isSearching
      ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name, ID, or requested by...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
          ),
          style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
        )
      : const Text('Reservations'),
        actions: [
          IconButton(
      icon: Icon(_isSearching ? Icons.close : Icons.search, size: 28),
      tooltip: _isSearching ? 'Close Search' : 'Search',
      onPressed: () {
        setState(() {
          _isSearching = !_isSearching;
          if (!_isSearching) {
            _searchController.clear();
            _searchQuery = '';
          }
        });
      },
    ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: _loadReservationData,
          ),
          if (!widget.hideAddButton)
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 35),
              onPressed: () async {
                // Always start a fresh "New Reservation" — clear any
                // reservation/hotels/flights left selected by the view screen
                // so NewReservationScreen doesn't open in Update mode or show
                // the previously-viewed hotel & air-ticket data.
                ref
                    .read(selectedReservationProvider.notifier)
                    .clearSelectedReservation();
                ref.read(selectedHotelProvider.notifier).setHotels([]);
                ref.read(selectedFlightProvider.notifier).setFlights([]);
                final result = await context.push(
                  '/reservationMain/reservations/new-reservation',
                );
                if (result == true) await _loadReservationData();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
           isScrollable: true, 
          indicatorColor: Colors.pink,
           tabAlignment: TabAlignment.start,
          tabs: [
            _buildTab(
              'Pending & Checked',
              reservations['Pending']?.length ?? 0,
              Colors.orange,
            ),
             _buildTab(
              'For Approval',
              reservations['Checked']?.length ?? 0,
              Colors.blue,
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
              _buildReservationList(reservations['Checked'] ?? []),
              _buildReservationList(reservations['Approved'] ?? []),
              _buildReservationList(reservations['Rejected'] ?? []),
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
        //  const Watermark(),
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

    return FutureBuilder<List<Reservation>>(
      future: _filterReservations(reservations),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Constants.kSecondaryColor,
              ),
            ),
          );
        }

        // final filteredReservations = snapshot.data ?? [];
final filteredReservations = (snapshot.data ?? []).where((reservation) {
  if (_searchQuery.isEmpty) return true;
  return reservation.mid.toLowerCase().contains(_searchQuery) ||
      reservation.mName.toLowerCase().contains(_searchQuery) ||
      reservation.reqBy.toLowerCase().contains(_searchQuery) ||
        reservation.reservNo.toLowerCase().contains(_searchQuery) ||
      reservation.reservNo.toLowerCase().contains(_searchQuery);
}).toList();
        if (filteredReservations.isEmpty) {
          return const Center(child: Text('No reservations available.'));
        }

        return ListView.builder(
          itemCount: filteredReservations.length,
          itemBuilder: (context, index) {
            final reservation = filteredReservations[index];
            final isApprovedOrRejected =
                reservation.requestStatus == 'Approved' ||
                reservation.requestStatus == 'Rejected'||
                  reservation.requestStatus == 'Checked';

            return Stack(
              children: [
                Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    // title: Text(
                    //   'Reservation: ${reservation.reservNo}',
                    //   style: TextStyle(
                    //     color: Colors.black,
                    //     fontSize: fontSettings.fontSize,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),

                        // Member ID & Name
                        Text(
                          '${reservation.mid} - ${reservation.mName}',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: fontSettings.fontSize + 1,
                            fontWeight: fontSettings.fontWeight,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Requested By
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
                                fontSize: fontSettings.fontSize + 2,
                                fontWeight: fontSettings.fontWeight,
                                 color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                reservation.reqBy,
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: fontSettings.fontWeight,
                                   color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Approved / Rejected By
                        if (isApprovedOrRejected)
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
                                  fontSize: fontSettings.fontSize + 2,
                                  fontWeight: fontSettings.fontWeight,
                                   color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  reservation.isAppBy ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: fontSettings.fontSize + 2,
                                    fontWeight: fontSettings.fontWeight,
                                    
                                    color:
                                        reservation.requestStatus == 'Approved'
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 20,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Requested: ${_formatDateTime(reservation.insertDate)}',
                              style: TextStyle(
                                fontSize: fontSettings.fontSize + 1,
                                color: const Color.fromARGB(255, 0, 0, 0),
                                fontWeight: fontSettings.fontWeight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Approved or Rejected time
                        if (isApprovedOrRejected) ...[
                          const SizedBox(height: 3),
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
                                '${reservation.requestStatus}: ${_formatDateTime(reservation.isAppTime)}',
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize + 1,
                                  color: reservation.requestStatus == 'Approved'
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontWeight: fontSettings.fontWeight,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        // Status Badge
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
                                size: 20,
                                  color: const Color.fromARGB(255, 255, 255, 255),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reservation.requestStatus,
                                style: TextStyle(
                                  fontSize: fontSettings.fontSize,
                                  color: const Color.fromARGB(255, 255, 255, 255),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      final canAccess = await _canAccessReservationDetails(
                        reservation,_tabController.index,
                      );

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
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Constants.kPrimaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
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

                      ref
                          .read(selectedReservationProvider.notifier)
                          .setSelectedReservation(reservation);

                      final result = await context.push(
                        "/reservationMain/reservations/reservation-view",
                      );
                      if (result == true) await _loadReservationData();
                    },
                  ),
                ),

                // Rating image (top-right corner)
  //               Positioned(
  //                 top: 10,
  //                 right: 15,
  //                 child: 
  //                 // SizedBox(
  //                 //   width: 100,
  //                 //   height: 30,
  //                 //   child: Hero(
  //                 //     tag: "rating-image-${reservation.mid}",
  //                 //     child: Image.asset(
  //                 //       ratingImageMap[reservation.gRating] ??
  //                 //           "assets/images/ratings/CLASSIC.png",
  //                 //       fit: BoxFit.contain,
  //                 //     ),
  //                 //   ),
  //                 // ),
  //                 Hero(
  //   tag: "rating-image-${reservation.mid}",
  //   child: Container(
  //     padding: const EdgeInsets.symmetric(
  //       horizontal: 10,
  //       vertical: 6,
  //     ),
  //     decoration: BoxDecoration(
  //       color: _getRatingColor(reservation.gRating ?? 'N/A'),
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.25),
  //           blurRadius: 6,
  //           offset: const Offset(0, 3),
  //         ),
  //       ],
  //     ),
  //     child: Text(
  //       reservation.gRating ?? 'N/A', 
  //       style: const TextStyle(
  //         color: Colors.white,
  //         fontSize: 12,
  //         fontWeight: FontWeight.bold,
  //       ),
  //     ),
  //   ),
  // ),
  //               ),
              ],
            );
          },
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
      case 'Checked':        
        return Colors.blue;
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
      case 'Checked':        
        return Icons.fact_check;
      default:
        return Icons.hourglass_bottom;
    }
  }
}
