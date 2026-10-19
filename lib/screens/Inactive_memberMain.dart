import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/providers/my_inactive_members_provider.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';
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

class _InactiveMembermainScreenState
    extends ConsumerState<InactiveMembermainScreen>
    with ConnectivityMixin {
  /// The "My Inactive" card (and its count call) is Ballys only.
  bool _isBallys = false;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    // Location code saved at login, e.g. "BALLYS_..." / "BELLAGIO_...".
    final location = await StorageUtil.getCurrentLocation();
    final isBallys =
        location?.code.split('_').first.toUpperCase() == 'BALLYS';
    if (mounted) setState(() => _isBallys = isBallys);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);
    final myInactiveCount = _isBallys
        ? ref.watch(myInactiveMembersProvider).valueOrNull?.length
        : null;

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

                    // ── Followed ────────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/inctiveMemberMain/followups');
                        },
                        child: Card(
                          color: const Color.fromARGB(255, 4, 158, 143),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Lottie.asset(
                                  'assets/icon/menu_screen/Followed.json',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                                const Text(
                                  'Followed',
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
                    // ── My Inactive (logged-in user's own) ─────────────────
                    if (_isBallys)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            context.go(
                              '/inctiveMemberMain/my-inactive-members',
                            );
                          },
                          child: Stack(
                            fit: StackFit.passthrough,
                            clipBehavior: Clip.none, // let badge overflow the card corner
                            children: [
                              Card(
                                color: const Color.fromARGB(255, 33, 120, 214),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Column(
                                    children: [
                                      Center(
                                        child: Lottie.asset(
                                          'assets/icon/menu_screen/user.json',
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const Text(
                                        'My Inactive',
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
                              // Badge – only shown when count > 0, same as the
                              // Approve / Reject cards.
                              if ((myInactiveCount ?? 0) > 0)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      '$myInactiveCount',
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
                        ),
                      ),
                    // ── Unfollowed ──────────────────────────────────────────
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/inctiveMemberMain/unfollowups');
                        },
                        child: Card(
                          color: const Color.fromARGB(255, 214, 69, 65),
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
                                  'Unfollowed',
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
                    if (!_isBallys) const Expanded(child: SizedBox()),
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
