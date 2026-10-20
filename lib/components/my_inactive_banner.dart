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
  static const Color _ink = Color(0xFF1A1206);
  static const Color _surface = Color(0xFF17120B);

  static const double _headerHeight = 150;

  @override
  Widget build(BuildContext context) {
    final isOne = count == 1;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Semantics(
      container: true,
      label: '$count ${isOne ? 'member is' : 'members are'} inactive',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Material(
          color: _surface,
          elevation: 12,
          shadowColor: Colors.black,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: _gold.withOpacity(0.55), width: 1.2),
          ),
          // Scrolls only when space is tight (landscape / large text sizes).
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                  child: Column(
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$count',
                              style: const TextStyle(color: _gold),
                            ),
                            TextSpan(
                              text: isOne
                                  ? ' member is inactive'
                                  : ' members are inactive',
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 21,
                          height: 1.25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'ABCArizonaFlare',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "They haven't visited recently. A quick follow-up "
                        'can bring them back to the tables.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: Colors.white.withOpacity(0.78),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: onView,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _ink,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.people_alt_outlined, size: 20),
                          label: Text(
                            isOne ? 'View member' : 'View members',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: onDismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.75),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Remind me later',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Photo header with the label chip and close button.
  Widget _buildHeader() {
    return SizedBox(
      height: _headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Casino photo: chandelier and table visible.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _headerHeight,
            child: Image.asset(
              'assets/images/others/inactive_banner2.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.1),
            ),
          ),
          // Fade the photo into the card surface so the edge isn't harsh.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _headerHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                    _surface,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(0.8)),
              ),
              child: const Text(
                'INACTIVE MEMBERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: _gold,
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton(
              onPressed: onDismiss,
              tooltip: 'Close',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
              icon: const Icon(Icons.close, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
