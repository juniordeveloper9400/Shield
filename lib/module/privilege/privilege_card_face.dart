import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'privilege_tier.dart';

/// A privilege card drawn the way a card in a wallet looks: rings of the
/// tier's own colour under a frosted panel, a chip, and the figures embossed
/// on the front.
///
/// The colour is not decoration. Silver, gold and platinum are told apart in
/// a wallet by their finish long before anyone reads the name off them, and
/// the card face is built so that switching tier repaints everything —
/// background, rings and chrome — from the one accent the tier owns.
class PrivilegeCardFace extends StatelessWidget {
  final PrivilegeTier tier;

  /// Embossed across the front. Falls back to the programme's own name for a
  /// member who has not registered yet, rather than showing an empty line.
  final String holder;

  /// Small enough that the serial and the holder would be unreadable, so it
  /// shows the amount and the tier alone. Used on the home strip.
  final bool compact;

  const PrivilegeCardFace({
    super.key,
    required this.tier,
    this.holder = '',
    this.compact = false,
  });

  /// The proportions of a card in the hand, and what every face is laid out
  /// against.
  static const double aspectRatio = 245 / 155;

  /// Eighteen rings, outermost first, from a light wash of [accent] down to
  /// near-black.
  ///
  /// Built from the accent rather than listed per tier so a new card needs
  /// one colour, not eighteen — and so the ramp can never drift away from the
  /// colour the rest of the app paints that tier in.
  static List<Color> ringsFor(Color accent) {
    final base = HSLColor.fromColor(accent);
    const steps = 18;
    return [
      for (var index = 0; index < steps; index++)
        () {
          final t = index / (steps - 1);
          return HSLColor.fromAHSL(
            1,
            // A slow drift towards the warm end, which is what gives the
            // rings their depth instead of reading as one flat colour.
            (base.hue - 20 * t) % 360,
            (base.saturation * (0.95 + 0.35 * t)).clamp(0.0, 1.0),
            ui.lerpDouble(0.58, 0.11, t)!,
          ).toColor();
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rings = ringsFor(tier.accent);

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 9 : 15),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _RingsPainter(rings)),
          // The glass panel from the reference card: a white wash over a
          // blur, which is what keeps white text legible on rings that run
          // from pale to near-black under it.
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
            child: Container(
              color: AppColors.white.withValues(alpha: 0.18),
              padding: EdgeInsets.all(compact ? 8 : 16),
              child: compact ? _compactBody() : _fullBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fullBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Label.rich('Privilege', ' card'),
            const _Label('SHIELD'),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 30, width: 30, child: _Chip()),
        const Spacer(),
        Text(
          holder.isEmpty ? 'SHIELD MEMBER' : holder.toUpperCase(),
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(11, FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          tier.amountLabel,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(
            17,
            FontWeight.w800,
          ).copyWith(fontFamily: 'monospace', letterSpacing: 1.6),
        ),
        const SizedBox(height: 3),
        Text(
          // Where a payment card prints its expiry. The bonus is the one
          // figure a member wants off the front of this card.
          '10% BONUS · ${tier.bonusLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(10.5, FontWeight.w700).copyWith(letterSpacing: 0.3),
        ),
      ],
    );
  }

  Widget _compactBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(height: 15, width: 15, child: _Chip()),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'SHIELD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(8, FontWeight.w800).copyWith(letterSpacing: 0.6),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          tier.amountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(13.5, FontWeight.w800),
        ),
        Text(
          // "Gold Shield" is the tier; on a face this size the word Shield is
          // the one that can go, because the card itself says it.
          tier.name.split(' ').first.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(8, FontWeight.w700).copyWith(letterSpacing: 0.8),
        ),
      ],
    );
  }

  static TextStyle _style(double size, FontWeight weight) {
    return TextStyle(
      fontSize: size,
      height: 1.15,
      fontWeight: weight,
      color: AppColors.white,
      shadows: const [
        Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
      ],
    );
  }
}

/// A caption on the card front. The rich form emboldens the first word the
/// way the reference card sets "**Credit** card".
class _Label extends StatelessWidget {
  final String head;
  final String tail;

  const _Label(this.head) : tail = '';

  const _Label.rich(this.head, this.tail);

  @override
  Widget build(BuildContext context) {
    final base = PrivilegeCardFace._style(11.5, FontWeight.w400);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: head,
            style: base.copyWith(fontWeight: FontWeight.w800),
          ),
          if (tail.isNotEmpty) TextSpan(text: tail, style: base),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Concentric rings, laid out the way the reference SVG lays them out: a
/// 1600×800 field scaled to the card's width and centred, with the rings
/// growing from a point up in the top-left corner.
class _RingsPainter extends CustomPainter {
  final List<Color> rings;

  const _RingsPainter(this.rings);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 1600;
    // The field is twice as wide as it is tall; a card is not, so it is
    // centred vertically and the rings run off the top and bottom.
    final dy = (size.height - 800 * scale) / 2;
    final centre = Offset(17 * scale, 263.4 * scale + dy);

    canvas.drawRect(Offset.zero & size, Paint()..color = rings.first);

    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 66.7 * scale
      ..color = const Color(0x0D000000);

    for (var index = 0; index < rings.length; index++) {
      final radius = (1800 - index * 100) * scale;
      canvas.drawCircle(centre, radius, Paint()..color = rings[index]);
      canvas.drawCircle(centre, radius, seam);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.rings != rings;
}

/// The contact plate, in the gold every card wears whatever its tier.
class _Chip extends StatelessWidget {
  const _Chip();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _ChipPainter());
  }
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter();

  static const Color gold = Color(0xFFD4AF37);
  static const Color groove = Color(0xFF8A6E1F);

  @override
  void paint(Canvas canvas, Size size) {
    final plate = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.18),
    );
    canvas.drawRRect(plate, Paint()..color = gold);

    final inner = Rect.fromLTWH(
      size.width * 0.27,
      size.height * 0.24,
      size.width * 0.46,
      size.height * 0.52,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.055).clamp(0.8, 2.0)
      ..color = groove;

    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(size.width * 0.06)),
      line,
    );

    // The four leads running out of the contact area to the plate edge, which
    // is what makes a gold rectangle read as a chip.
    for (final y in [size.height * 0.38, size.height * 0.62]) {
      canvas.drawLine(Offset(0, y), Offset(inner.left, y), line);
      canvas.drawLine(Offset(inner.right, y), Offset(size.width, y), line);
    }
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, inner.top),
      line,
    );
    canvas.drawLine(
      Offset(size.width / 2, inner.bottom),
      Offset(size.width / 2, size.height),
      line,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => false;
}
