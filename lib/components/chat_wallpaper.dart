import 'dart:math' as math;

import 'package:ballys_reservation_app/core/chat_colors.dart';
import 'package:flutter/material.dart';

/// The doodle wallpaper behind a conversation, the way WhatsApp draws one.
///
/// It is painted rather than shipped as an image: the pattern is nothing but a
/// scatter of small line glyphs, so a painter gives it at any pixel density and
/// any screen size without an asset that would have to be re-cut for each.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ChatColors.chatBackground,
      child: CustomPaint(
        painter: const _DoodlePainter(),
        // The glyphs never move once laid out, so let the raster cache keep
        // them instead of re-drawing the whole field on every message.
        isComplex: true,
        willChange: false,
        child: child,
      ),
    );
  }
}

/// Draws one glyph centred on the origin, inside a box `size` across.
typedef _Glyph = void Function(Canvas canvas, Paint paint, double size);

class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  /// One glyph per cell. The cell is wide enough that neighbours never touch,
  /// even at the largest jitter and scale below.
  static const double _cell = 88;
  static const double _glyphSize = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ChatColors.wallpaperDoodle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        // Everything about a cell comes out of its own coordinates, so the
        // pattern is identical on every repaint: it does not crawl when the
        // list resizes around the keyboard, and it lines up across scrolls.
        final seed = _hash(col, row);
        final glyph = _glyphs[seed % _glyphs.length];
        final jitterX = ((seed >> 3) % 33) - 16.0;
        final jitterY = ((seed >> 8) % 33) - 16.0;
        final angle = (((seed >> 13) % 25) - 12) * math.pi / 180;
        final scale = 0.8 + ((seed >> 18) % 5) * 0.1;

        canvas.save();
        canvas.translate(
          col * _cell + _cell / 2 + jitterX,
          row * _cell + _cell / 2 + jitterY,
        );
        canvas.rotate(angle);
        canvas.scale(scale);
        glyph(canvas, paint, _glyphSize);
        canvas.restore();
      }
    }
  }

  /// A cheap integer hash — enough to make the scatter look unplanned, and
  /// stable so it stays put.
  static int _hash(int x, int y) {
    var h = (x * 73856093) ^ (y * 19349663);
    h ^= h >> 13;
    h = (h * 1274126177) & 0x7fffffff;
    h ^= h >> 16;
    return h & 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => false;
}

// ─── The glyphs ───────────────────────────────────────────────────────────────

const List<_Glyph> _glyphs = [
  _heart,
  _smiley,
  _bubble,
  _star,
  _camera,
  _note,
  _plane,
  _cup,
  _sun,
  _phone,
  _leaf,
  _clock,
];

void _heart(Canvas canvas, Paint paint, double s) {
  final r = s / 2;
  final path = Path()
    ..moveTo(0, r * 0.75)
    ..cubicTo(-r * 1.4, -r * 0.15, -r * 0.6, -r * 1.1, 0, -r * 0.35)
    ..cubicTo(r * 0.6, -r * 1.1, r * 1.4, -r * 0.15, 0, r * 0.75);
  canvas.drawPath(path, paint);
}

void _smiley(Canvas canvas, Paint paint, double s) {
  final r = s / 2;
  canvas.drawCircle(Offset.zero, r, paint);
  canvas.drawCircle(Offset(-r * 0.34, -r * 0.24), r * 0.07, paint);
  canvas.drawCircle(Offset(r * 0.34, -r * 0.24), r * 0.07, paint);
  canvas.drawArc(
    Rect.fromCircle(center: Offset(0, -r * 0.05), radius: r * 0.58),
    0.6,
    math.pi - 1.2,
    false,
    paint,
  );
}

void _bubble(Canvas canvas, Paint paint, double s) {
  final w = s, h = s * 0.7;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -s * 0.08), width: w, height: h),
      Radius.circular(h * 0.34),
    ),
    paint,
  );
  final base = -s * 0.08 + h / 2;
  final tail = Path()
    ..moveTo(-w * 0.2, base - 1)
    ..lineTo(-w * 0.3, base + s * 0.22)
    ..lineTo(-w * 0.02, base - 1);
  canvas.drawPath(tail, paint);
}

void _star(Canvas canvas, Paint paint, double s) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? s / 2 : s * 0.2;
    final a = -math.pi / 2 + i * math.pi / 5;
    final x = math.cos(a) * r, y = math.sin(a) * r;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  canvas.drawPath(path..close(), paint);
}

void _camera(Canvas canvas, Paint paint, double s) {
  final w = s, h = s * 0.66;
  final top = s * 0.06 - h / 2;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, s * 0.06), width: w, height: h),
      Radius.circular(s * 0.14),
    ),
    paint,
  );
  canvas.drawCircle(Offset(0, s * 0.06), s * 0.18, paint);
  final hump = Path()
    ..moveTo(-w * 0.24, top)
    ..lineTo(-w * 0.16, top - s * 0.12)
    ..lineTo(w * 0.02, top - s * 0.12)
    ..lineTo(w * 0.1, top);
  canvas.drawPath(hump, paint);
}

void _note(Canvas canvas, Paint paint, double s) {
  final stems = Path()
    ..moveTo(-s * 0.12, s * 0.3)
    ..lineTo(-s * 0.12, -s * 0.38)
    ..lineTo(s * 0.32, -s * 0.5)
    ..lineTo(s * 0.32, s * 0.16);
  canvas.drawPath(stems, paint);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(-s * 0.26, s * 0.32),
      width: s * 0.3,
      height: s * 0.22,
    ),
    paint,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(s * 0.18, s * 0.18),
      width: s * 0.3,
      height: s * 0.22,
    ),
    paint,
  );
}

void _plane(Canvas canvas, Paint paint, double s) {
  final path = Path()
    ..moveTo(-s * 0.5, -s * 0.06)
    ..lineTo(s * 0.5, -s * 0.42)
    ..lineTo(s * 0.1, s * 0.46)
    ..lineTo(-s * 0.02, s * 0.08)
    ..close();
  canvas.drawPath(path, paint);
  canvas.drawLine(Offset(-s * 0.02, s * 0.08), Offset(s * 0.5, -s * 0.42), paint);
}

void _cup(Canvas canvas, Paint paint, double s) {
  final body = Path()
    ..moveTo(-s * 0.3, -s * 0.22)
    ..lineTo(-s * 0.22, s * 0.36)
    ..lineTo(s * 0.22, s * 0.36)
    ..lineTo(s * 0.3, -s * 0.22)
    ..close();
  canvas.drawPath(body, paint);
  canvas.drawArc(
    Rect.fromCircle(center: Offset(s * 0.3, s * 0.0), radius: s * 0.15),
    -math.pi / 2,
    math.pi,
    false,
    paint,
  );
  canvas.drawLine(Offset(-s * 0.1, -s * 0.38), Offset(-s * 0.1, -s * 0.54), paint);
  canvas.drawLine(Offset(s * 0.1, -s * 0.38), Offset(s * 0.1, -s * 0.54), paint);
}

void _sun(Canvas canvas, Paint paint, double s) {
  canvas.drawCircle(Offset.zero, s * 0.26, paint);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    canvas.drawLine(
      Offset(math.cos(a) * s * 0.36, math.sin(a) * s * 0.36),
      Offset(math.cos(a) * s * 0.5, math.sin(a) * s * 0.5),
      paint,
    );
  }
}

void _phone(Canvas canvas, Paint paint, double s) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.52, height: s * 0.9),
      Radius.circular(s * 0.12),
    ),
    paint,
  );
  canvas.drawLine(Offset(-s * 0.1, s * 0.32), Offset(s * 0.1, s * 0.32), paint);
}

void _leaf(Canvas canvas, Paint paint, double s) {
  final path = Path()
    ..moveTo(-s * 0.35, s * 0.35)
    ..quadraticBezierTo(-s * 0.42, -s * 0.42, s * 0.35, -s * 0.35)
    ..quadraticBezierTo(s * 0.42, s * 0.3, -s * 0.35, s * 0.35)
    ..close();
  canvas.drawPath(path, paint);
  canvas.drawLine(Offset(-s * 0.3, s * 0.3), Offset(s * 0.2, -s * 0.2), paint);
}

void _clock(Canvas canvas, Paint paint, double s) {
  canvas.drawCircle(Offset.zero, s * 0.42, paint);
  canvas.drawLine(Offset.zero, Offset(0, -s * 0.24), paint);
  canvas.drawLine(Offset.zero, Offset(s * 0.18, s * 0.06), paint);
}
