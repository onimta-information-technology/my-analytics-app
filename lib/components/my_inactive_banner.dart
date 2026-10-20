import 'package:flutter/material.dart';

/// Home-screen reminder of how many of the logged-in user's own members have
/// gone inactive, with a shortcut to the "My Inactive Members" list.
class MyInactiveBanner extends StatelessWidget {
  final int count;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const MyInactiveBanner({
    super.key,
    required this.count,
    required this.onView,
    required this.onDismiss,
  });

  static const Color _gold = Color(0xFFE2B84C);
  static const Color _goldDark = Color(0xFFB8862B);
  static const Color _ink = Color(0xFF1A1206);

  @override
  Widget build(BuildContext context) {
    final noun = count == 1 ? 'member has' : 'members have';

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 440,
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold.withOpacity(0.7), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.35),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Casino photo: chandelier and table visible up top.
            Positioned.fill(
              child: Image.asset(
                'assets/images/others/inactive_banner.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.1),
              ),
            ),
            // Dark wash, heaviest at the bottom behind the text.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.92),
                    ],
                    stops: const [0.0, 0.4, 0.75],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top: label + dismiss ──────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _gold.withOpacity(0.8)),
                        ),
                        child: const Text(
                          'INACTIVE MEMBERS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: _gold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onDismiss,
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.45),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Top: count medallion ──────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 96),
                          height: 96,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(48),
                            gradient: const LinearGradient(
                              colors: [_gold, _goldDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withOpacity(0.6),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            count == 1 ? 'member inactive' : 'members inactive',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // ── Bottom: message, actions ──────────────────────────
                  const Text(
                    'We miss them at the tables',
                    style: TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'ABCArizonaFlare',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$count of your $noun not visited recently. '
                    'A quick follow-up can bring them back.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: Color.fromARGB(230, 255, 255, 255),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.6),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Later',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onView,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _ink,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.people_alt_outlined, size: 20),
                          label: const Text(
                            'View members',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
