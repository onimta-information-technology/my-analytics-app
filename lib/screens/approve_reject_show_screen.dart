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
  @override
  void initState() {
    super.initState();
    // re-fetch every time we land on this screen so the badge stays fresh
  Future.microtask(() {
    ref.read(pendingCountProvider.notifier).fetch();
  });
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

    final cards = <Widget>[
      _CardWithBadge(
        count: counts.reservation,
        onTap: () => context.go('/menu/approve-reject/reservations-menu'),
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
    ];

    return _CardGridScaffold(
      title: 'Approve',
      onBack: () => context.go('/menu'),
      cards: cards,
    );
  }
}

/// Approve → Reservations. Lists the reservation types to approve for the
/// logged-in location: Ballys gets every type, Bellagio gets Reservation and
/// Transport. Each list is pushed so back returns here.
class ApproveReservationsMenuScreen extends ConsumerStatefulWidget {
  const ApproveReservationsMenuScreen({super.key});

  @override
  ConsumerState<ApproveReservationsMenuScreen> createState() =>
      _ApproveReservationsMenuScreenState();
}

class _ApproveReservationsMenuScreenState
    extends ConsumerState<ApproveReservationsMenuScreen>
    with ConnectivityMixin {
  /// Group Reservation, Amendments, Visa, Airport Services and the Ballys
  /// Transport list are Ballys-only, as on the Reservations screen.
  bool _isBallys = false;

  /// The shared Transport list is a Bellagio-only (bty.world) feature.
  bool _isBellagio = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    final location = await StorageUtil.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isBellagio = apiUrl.contains('bty.world');
      _isBallys =
          location?.code.split('_').first.toUpperCase() == 'BALLYS';
      _isLoading = false;
    });
  }

  void _open(String path) => context.push('/menu/approve-reject/$path');

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(pendingCountProvider);
    final counts = countsAsync.when(
      data: (c) => c,
      loading: () => const PendingCounts(),
      error: (e, st) => const PendingCounts(),
    );

    final cards = <Widget>[
      // Ballys logins get their own Reservations screen; every other
      // location keeps the shared one.
      _CardWithBadge(
        count: counts.reservation,
        onTap: () =>
            _open(_isBallys ? 'reservations-ballys' : 'reservations'),
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 149, 0),
            Color.fromARGB(255, 255, 149, 0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: FontAwesomeIcons.luggageCart,
        label: 'Reservation',
      ),
      // Same lists as the Reservations menu, opened without their add
      // buttons — nothing is created from the Approve flow.
      if (_isBallys) ...[
        _CardWithBadge(
          count: 0,
          onTap: () => _open('group-reservations-ballys'),
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
          onTap: () => _open('amendments-ballys'),
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
          onTap: () => _open('transport-ballys'),
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
          onTap: () => _open('visa-ballys'),
          gradient: const LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF6A1B9A)],
          ),
          icon: Icons.badge,
          label: 'Visa',
        ),
        _CardWithBadge(
          count: 0,
          onTap: () => _open('airport-service-ballys'),
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
          onTap: () => _open('transport'),
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

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _CardGridScaffold(
      title: 'Reservations',
      onBack: () => context.go('/menu/approve-reject'),
      cards: cards,
    );
  }
}

// ─── Shared two-per-row card layout ─────────────────────────────────────────

class _CardGridScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final List<Widget> cards;

  const _CardGridScaffold({
    required this.title,
    required this.onBack,
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: onBack,
        ),
        title: Text(
          title,
          style: const TextStyle(
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