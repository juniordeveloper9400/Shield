import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'privilege_card_face.dart';
import 'privilege_tier.dart';

/// The three privilege cards, tucked into a wallet pocket.
///
/// At rest only the top strip of each card shows above the pocket lip, in the
/// order they are issued — silver furthest back, platinum in front — which is
/// what a wallet of cards looks like and what says at a glance that the
/// programme is three cards rather than one. Driving [fan] from 0 to 1 lifts
/// them out, the back card travelling furthest so all three are readable.
class PrivilegeWallet extends StatelessWidget {
  /// 0 while the cards are in the pocket, 1 once they are fanned out. May
  /// overshoot 1 slightly — the frame leaves headroom for it.
  final Animation<double> fan;

  final double width;

  const PrivilegeWallet({super.key, required this.fan, required this.width});

  /// The artwork is laid out against this frame and scaled to [width], so one
  /// set of numbers positions the pocket, the cards and their travel.
  ///
  /// 280×230 is the wallet itself; the rest is headroom above it for the
  /// cards to rise into.
  static const double frameWidth = 280;
  static const double frameHeight = 310;

  /// Where the wallet body starts inside the frame.
  static const double _walletTop = 80;

  /// How far each card rises, back card first. Chosen so that even with the
  /// overshoot of an ease-out-back curve the topmost card stays in frame.
  static const List<double> _rise = [62, 38, 8];

  /// A little rotation as they come out, so they read as loose cards rather
  /// than as one block sliding up.
  static const List<double> _turn = [-3, 2, 0];

  static double heightFor(double width) => width * frameHeight / frameWidth;

  @override
  Widget build(BuildContext context) {
    final scale = width / frameWidth;
    final tiers = PrivilegeProgramme.tiers;

    return SizedBox(
      width: width,
      height: heightFor(width),
      child: AnimatedBuilder(
        animation: fan,
        builder: (context, _) {
          final t = fan.value;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The body of the wallet, behind everything.
              Positioned(
                left: 0,
                top: (_walletTop + 30) * scale,
                width: 280 * scale,
                height: 200 * scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brandBlueDeep,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22 * scale),
                      topRight: Radius.circular(22 * scale),
                      bottomLeft: Radius.circular(60 * scale),
                      bottomRight: Radius.circular(60 * scale),
                    ),
                    // Stands in for the reference card's inset shadow, which
                    // is what makes the opening read as a hollow rather than
                    // as a flat panel.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.brandNavy, AppColors.brandBlueDeep],
                      stops: const [0, 0.45],
                    ),
                  ),
                ),
              ),
              for (var index = 0; index < tiers.length; index++)
                Positioned(
                  left: 10 * scale,
                  top: (_walletTop + index * 25 - _rise[index] * t) * scale,
                  width: 260 * scale,
                  height: 140 * scale,
                  child: Transform.rotate(
                    angle: _turn[index] * t * math.pi / 180,
                    alignment: Alignment.bottomCenter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16 * scale),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 8 * scale,
                            offset: Offset(0, -2 * scale),
                          ),
                        ],
                      ),
                      child: PrivilegeCardFace(
                        load: tiers[index].entry,
                        compact: true,
                      ),
                    ),
                  ),
                ),
              // The pocket, drawn over the cards: it is what they are in.
              Positioned(
                left: 0,
                top: (_walletTop + 70) * scale,
                width: 280 * scale,
                height: 160 * scale,
                child: CustomPaint(painter: const _PocketPainter()),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The pocket front, traced from the reference wallet: a lip that dips in the
/// middle, and a stitch line running inside it.
class _PocketPainter extends CustomPainter {
  const _PocketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 280;
    final sy = size.height / 160;

    final front = Path()
      ..moveTo(0, 20 * sy)
      ..cubicTo(0, 10 * sy, 5 * sx, 10 * sy, 10 * sx, 10 * sy)
      ..cubicTo(20 * sx, 10 * sy, 25 * sx, 25 * sy, 40 * sx, 25 * sy)
      ..lineTo(240 * sx, 25 * sy)
      ..cubicTo(255 * sx, 25 * sy, 260 * sx, 10 * sy, 270 * sx, 10 * sy)
      ..cubicTo(275 * sx, 10 * sy, 280 * sx, 10 * sy, 280 * sx, 20 * sy)
      ..lineTo(280 * sx, 120 * sy)
      ..cubicTo(280 * sx, 155 * sy, 260 * sx, 160 * sy, 240 * sx, 160 * sy)
      ..lineTo(40 * sx, 160 * sy)
      ..cubicTo(20 * sx, 160 * sy, 0, 155 * sy, 0, 120 * sy)
      ..close();

    canvas.drawPath(front, Paint()..color = AppColors.brandBlueDeep);

    final stitch = Path()
      ..moveTo(8 * sx, 22 * sy)
      ..cubicTo(8 * sx, 16 * sy, 12 * sx, 16 * sy, 15 * sx, 16 * sy)
      ..cubicTo(23 * sx, 16 * sy, 27 * sx, 29 * sy, 40 * sx, 29 * sy)
      ..lineTo(240 * sx, 29 * sy)
      ..cubicTo(253 * sx, 29 * sy, 257 * sx, 16 * sy, 265 * sx, 16 * sy)
      ..cubicTo(268 * sx, 16 * sy, 272 * sx, 16 * sy, 272 * sx, 22 * sy)
      ..lineTo(272 * sx, 120 * sy)
      ..cubicTo(272 * sx, 150 * sy, 255 * sx, 152 * sy, 240 * sx, 152 * sy)
      ..lineTo(40 * sx, 152 * sy)
      ..cubicTo(25 * sx, 152 * sy, 8 * sx, 152 * sy, 8 * sx, 120 * sy)
      ..close();

    // Green thread on a blue wallet, the two colours the logo is made of.
    canvas.drawPath(
      _dashed(stitch, 6 * sx, 4 * sx),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, 1.5 * sx)
        ..color = AppColors.brandGreen.withValues(alpha: 0.55),
    );
  }

  /// Flutter strokes solid lines only, so the dashes are cut out of the path
  /// before it is stroked.
  static Path _dashed(Path source, double on, double off) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + on, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + off;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(_PocketPainter oldDelegate) => false;
}
