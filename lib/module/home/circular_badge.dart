import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The "TOP BRANDS / DOCTOR APPROVED" seal: two arcs of text wrapped around a
/// circular shield mark.
class CircularBadge extends StatelessWidget {
  final double diameter;

  const CircularBadge({super.key, this.diameter = 108});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(diameter, diameter),
            painter: _ArcTextPainter(
              topText: '• TOP BRANDS •',
              bottomText: '• DOCTOR APPROVED •',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textDark,
              ),
            ),
          ),
          Container(
            width: diameter * 0.52,
            height: diameter * 0.52,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(diameter * 0.09),
            child: Image.asset(
              'assets/logos/shield_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcTextPainter extends CustomPainter {
  final String topText;
  final String bottomText;
  final TextStyle style;

  _ArcTextPainter({
    required this.topText,
    required this.bottomText,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 7;
    canvas.translate(size.width / 2, size.height / 2);

    _drawArc(canvas, topText, radius, centerAngle: 0, flip: false);
    _drawArc(canvas, bottomText, radius, centerAngle: 0, flip: true);
  }

  /// Lays each glyph out individually along the circle. Advancing by
  /// `glyphWidth / radius` keeps spacing even regardless of character width.
  void _drawArc(
    Canvas canvas,
    String text,
    double radius, {
    required double centerAngle,
    required bool flip,
  }) {
    final painters = text.split('').map((char) {
      return TextPainter(
        text: TextSpan(text: char, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    }).toList();

    final totalWidth = painters.fold<double>(0, (sum, p) => sum + p.width);
    final totalAngle = totalWidth / radius;

    // Top arc sweeps clockwise; the bottom arc sweeps the other way so its
    // glyphs still read left-to-right once flipped upright.
    var angle = flip
        ? centerAngle + totalAngle / 2
        : centerAngle - totalAngle / 2;

    for (final painter in painters) {
      final glyphAngle = painter.width / radius;
      canvas.save();
      canvas.rotate(flip ? angle - glyphAngle / 2 : angle + glyphAngle / 2);
      canvas.translate(0, flip ? radius : -radius);
      if (flip) {
        canvas.rotate(math.pi);
      }
      painter.paint(
        canvas,
        Offset(-painter.width / 2, flip ? -painter.height : 0),
      );
      canvas.restore();
      angle += flip ? -glyphAngle : glyphAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ArcTextPainter oldDelegate) {
    return oldDelegate.topText != topText ||
        oldDelegate.bottomText != bottomText ||
        oldDelegate.style != style;
  }
}
