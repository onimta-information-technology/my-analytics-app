import 'package:ballys_reservation_app/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // Same red as the My Inactive Members screen, so the banner and the list
  // it opens look like one feature.
  static const Color _accent = Constants.kSecondaryColor;
  static const Color _text = Color(0xFF2C3E50);

  static const double _maxWidth = 400;

  @override
  Widget build(BuildContext context) {
    final isOne = count == 1;
    final countText = NumberFormat.decimalPattern().format(count);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    // The artwork is 1536px wide; decode it at card size, not full size.
    final imageWidth = (_maxWidth * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Semantics(
      container: true,
      label: '$count ${isOne ? 'member is' : 'members are'} inactive',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxWidth, maxHeight: maxHeight),
        child: Material(
          color: Colors.white,
          elevation: 10,
          shadowColor: Colors.black54,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: ResizeImage(
                  const AssetImage('assets/images/others/inactive_banner2.jpg'),
                  width: imageWidth,
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: DecoratedBox(
              // Soften the artwork behind the text and buttons so they stay
              // easy to read.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Scrolls only when space is tight (landscape / large text
                  // sizes).
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIcon(),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'FOLLOW-UP REMINDER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: _accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'You have '),
                              TextSpan(
                                text:
                                    '$countText inactive '
                                    '${isOne ? 'member' : 'members'}',
                                style: const TextStyle(color: _accent),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            height: 1.25,
                            fontWeight: FontWeight.bold,
                            color: _text,
                            fontFamily: 'ABCArizonaFlare',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "They haven't visited in a while. A quick follow-up "
                          'can bring them back to the tables.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: _text.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: onView,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.people_alt_outlined,
                              size: 20,
                            ),
                            label: Text(
                              isOne ? 'View member' : 'View members',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: TextButton(
                            onPressed: onDismiss,
                            style: TextButton.styleFrom(
                              foregroundColor: _text.withValues(alpha: 0.75),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton(
                      onPressed: onDismiss,
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        foregroundColor: _text,
                      ),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Round white badge with a people icon, the card's focal point.
  Widget _buildIcon() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withValues(alpha: 0.18), width: 5),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.groups_rounded, size: 42, color: _accent),
    );
  }
}
