import 'package:ballys_reservation_app/models/pendingCounts.dart';
import 'package:ballys_reservation_app/providers/pending_count_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



class ApproveScreen extends ConsumerStatefulWidget {
  const ApproveScreen({super.key});

  @override
  ConsumerState<ApproveScreen> createState() => _ApproveScreenState();
}

class _ApproveScreenState extends ConsumerState<ApproveScreen> with ConnectivityMixin{
  /// Group Reservation, Amendments, Visa, Airport Services and the Ballys
  /// Transport list are Ballys-only, as on the Reservations screen.
  bool _isBallys = false;

  /// The shared Transport list is a Bellagio-only (bty.world) feature.
  bool _isBellagio = false;

  @override
  void initState() {
    super.initState();
    // re-fetch every time we land on this screen so the badge stays fresh
  Future.microtask(() {
    ref.read(pendingCountProvider.notifier).fetch();
  });
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    final isBallys = await _isBallysLocation();
    if (!mounted) return;
    setState(() {
      _isBellagio = apiUrl.contains('bty.world');
      _isBallys = isBallys;
    });
  }

  /// True when the logged-in device/user is on the Ballys location, which
  /// keeps its own Reservations list.
  Future<bool> _isBallysLocation() async {
    final location = await StorageUtil.getCurrentLocation();
    if (location == null) return false;
    return location.code.split('_').first.toUpperCase() == 'BALLYS';
  }

  /// Ballys logins get their own Reservations screen; every other location
  /// keeps the shared one.
  Future<void> _openReservations() async {
    final isBallys = await _isBallysLocation();
    if (!mounted) return;
    context.go(
      isBallys
          ? '/menu/approve-reject/reservations-ballys'
          : '/menu/approve-reject/reservations',
    );
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(pendingCountProvider);

    // Default counts while loading or on error – badges simply won't show
    final counts = countsAsync.when(
      data: (c) => c,
      loading: () => const PendingCounts(),
      error: (e, st) => const PendingCounts(),
    );

    // Laid out two per row in this order, so location-only cards fill the
    // gaps instead of leaving half-empty rows.
    final cards = <Widget>[
      _CardWithBadge(
        count: counts.reservation,
        onTap: _openReservations,
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 149, 0),
            Color.fromARGB(255, 255, 149, 0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: FontAwesomeIcons.luggageCart,
        label: 'Reservations',
      ),
      _CardWithBadge(
        count: counts.otpGift,
        onTap: () => context.go('/menu/approve-reject/special-gift-requests'),
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color.fromARGB(255, 2, 235, 235)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: FontAwesomeIcons.gifts,
        label: 'OTP Gifts',
      ),
      _CardWithBadge(
        count: counts.birthdayGift,
        onTap: () => context.go('/menu/approve-reject/birthday-gifts'),
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 0, 0, 0), Color(0xFFFF6F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: FontAwesomeIcons.cakeCandles,
        label: 'Birthday Gifts',
      ),
      // Same lists as the Reservations menu, opened without their add
      // buttons — nothing is created from the Approve flow.
      if (_isBallys) ...[
        _CardWithBadge(
          count: 0,
          onTap: () =>
              context.go('/menu/approve-reject/group-reservations-ballys'),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 103, 58, 183),
              Color.fromARGB(255, 103, 58, 183),
            ],
          ),
          icon: Icons.groups,
          label: 'Group Reservation',
        ),
        _CardWithBadge(
          count: 0,
          onTap: () => context.go('/menu/approve-reject/amendments-ballys'),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 0, 121, 107),
              Color.fromARGB(255, 0, 121, 107),
            ],
          ),
          icon: Icons.edit_note,
          label: 'Amendments',
        ),
        _CardWithBadge(
          count: 0,
          onTap: () => context.go('/menu/approve-reject/transport-ballys'),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 63, 81, 181),
              Color.fromARGB(255, 63, 81, 181),
            ],
          ),
          icon: Icons.directions_car_filled,
          label: 'Transport',
        ),
        _CardWithBadge(
          count: 0,
          onTap: () => context.go('/menu/approve-reject/visa-ballys'),
          gradient: const LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF6A1B9A)],
          ),
          icon: Icons.badge,
          label: 'Visa',
        ),
        _CardWithBadge(
          count: 0,
          onTap: () =>
              context.go('/menu/approve-reject/airport-service-ballys'),
          gradient: const LinearGradient(
            colors: [Color(0xFF0277BD), Color(0xFF0277BD)],
          ),
          icon: Icons.local_airport,
          label: 'Airport Services',
        ),
      ],
      if (_isBellagio)
        _CardWithBadge(
          count: 0,
          onTap: () => context.go('/menu/approve-reject/transport'),
          gradient: const LinearGradient(
            colors: [
              Color.fromARGB(255, 63, 81, 181),
              Color.fromARGB(255, 63, 81, 181),
            ],
          ),
          icon: Icons.directions_car_filled,
          label: 'Transport',
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go('/menu'),
        ),
        title: const Text(
          'Approve',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (var i = 0; i < cards.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 12),
                  // Odd count: empty spacer keeps the last card half width.
                  Expanded(
                    child: i + 1 < cards.length
                        ? cards[i + 1]
                        : const SizedBox(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Reusable card widget with an optional badge ────────────────────────────

class _CardWithBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final LinearGradient gradient;
  final IconData icon;
  final String label;

  const _CardWithBadge({
    required this.count,
    required this.onTap,
    required this.gradient,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none, // let badge overflow the rounded corners
        children: [
          // gradient card body with shadow — no Card widget wrapper
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              gradient: gradient,
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.15),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 60, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // badge – only shown when count > 0
          if (count > 0)
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}