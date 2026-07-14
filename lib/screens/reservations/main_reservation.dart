import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class ReservationMainScreen extends ConsumerStatefulWidget {
  const ReservationMainScreen({super.key});

  @override
  ConsumerState<ReservationMainScreen> createState() =>
      _ReservationMainScreenState();
}

class _ReservationMainScreenState extends ConsumerState<ReservationMainScreen>
    with ConnectivityMixin {
  /// Transport is a Bellagio-only (bty.world) feature.
  bool _isBellagio = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    final apiUrl = await StorageUtil.getCurrentApiUrl() ?? '';
    if (!mounted) return;
    setState(() => _isBellagio = apiUrl.contains('bty.world'));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Reservations'),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // ── Reservations ────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/reservationMain/reservations');
                        },
                        child: Card(
                          color: Colors.orange[700],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Lottie.asset(
                                  'assets/icon/menu_screen/reservation.json',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const Text(
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

                    // ── Quick Reservation ────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/reservationMain/quick-reservation');
                        },
                        child: Card(
                          color: const Color.fromARGB(255, 4, 158, 143),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Lottie.asset(
                                  'assets/icon/menu_screen/packageGuest.json',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const Text(
                                  'Quick Reservation',
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

                // ── Transport (Bellagio only) ────────────────────────────
                if (_isBellagio)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            context.go('/reservationMain/transport');
                          },
                          child: Card(
                            color: const Color.fromARGB(255, 63, 81, 181),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.directions_car_filled,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                  Text(
                                    'Transport',
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
                      // Keeps the card the same width as the cards above.
                      const Expanded(child: SizedBox()),
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