import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class InactiveMembermainScreen extends ConsumerStatefulWidget {
  const InactiveMembermainScreen({super.key});

  @override
  ConsumerState<InactiveMembermainScreen> createState() =>
      _InactiveMembermainScreenState();
}

class _InactiveMembermainScreenState extends ConsumerState<InactiveMembermainScreen>
    with ConnectivityMixin {
  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Inactive Members'),
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
                          context.go('/inctiveMemberMain/inactive-members');
                        },
                        child: Card(
                          color: const Color.fromARGB(255, 134, 68, 234),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Lottie.asset(
                                'assets/icon/menu_screen/inactiveMember.json',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const Text(
                                  'Inactive Member',
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
                        // onTap: () {
                        //   context.go('/reservationMain/quick-reservation');
                        // },
                        child: Card(
                          color: const Color.fromARGB(255, 4, 158, 143),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Lottie.asset(
                                  'assets/icon/menu_screen/followMembers.json',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const Text(
                                  'Follow Up',
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