import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../money.dart';
import '../../theme/app_colors.dart';
import 'referral_level.dart';

/// The ladder as a climb: what each rung pays, and which rung the member is
/// standing on.
///
/// The card above it says the level and the figures; neither says where that
/// level sits in the whole programme. A member on Starter reading "100 points"
/// has no way of knowing whether that is most of what the ladder pays or a
/// thirtieth of it — and the answer, that the rewards climb steeply, is the
/// single most persuasive thing the programme has to say. It is a picture,
/// so it is drawn as one.
///
/// The marker pulses four times when the graph appears and then holds still.
/// A marker that went on blinking would be movement in the corner of the eye
/// for as long as the screen was open, and a member trying to read the rung
/// they are on would be reading it through a flash. Four is enough to be
/// noticed once.
class RewardGraph extends StatefulWidget {
  final List<ReferralLevel> levels;
  final ReferralProgress progress;

  const RewardGraph({
    super.key,
    required this.levels,
    required this.progress,
  });

  /// The plotted area, above the row of values and below the marker's pill.
  static const double plotHeight = 74;

  /// How many times the marker pulses before it leaves the eye alone.
  static const int pulses = 4;

  static const Duration pulseDuration = Duration(milliseconds: 620);

  @override
  State<RewardGraph> createState() => _RewardGraphState();
}

class _RewardGraphState extends State<RewardGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RewardGraph.pulseDuration,
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  int _cycles = 0;

  @override
  void initState() {
    super.initState();
    // Counted rather than repeated: repeat() would never stop, and a widget
    // test that pumped this screen to settle would never come back.
    _controller.addStatusListener(_onPulse);
    _controller.forward();
  }

  void _onPulse(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _cycles++;
      if (_cycles < RewardGraph.pulses) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onPulse);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levels = widget.levels;
    final cleared = widget.progress.currentLevel(levels);

    // Where the member is standing. Nothing cleared yet still points at the
    // first rung — that is the one being worked on — but the marker says
    // "Start here" rather than claiming they are already on it.
    final standing = ReferralLadder.standingFor(widget.progress);
    final index = levels.indexWhere((level) => level.level == standing.level);

    // The dot the marker sets off from, and how far along the segment to the
    // next dot it has travelled. A cleared Level 1 with three of the five
    // referrals Level 2 asks for leaves the marker a third of the way up the
    // rise between the two — the climb has flow rather than sitting frozen on
    // a rung.
    final next = widget.progress.nextLevel(levels);
    final baseIndex = index < 0 ? 0 : index;
    final advance = (cleared == 0 || next == null)
        ? 0.0
        : widget.progress.progressTowards(next, levels);

    // The rung the flow is heading for: the next uncleared one, or the top
    // once the whole ladder is done.
    final targetIndex = cleared >= levels.length
        ? levels.length - 1
        : cleared;

    return Semantics(
      label: cleared == 0
          ? 'Reward graph. You have not cleared a level yet. '
                'Level 1 pays ${levels.first.pointsLabel}.'
          : 'Reward graph. You are on level $cleared of ${levels.length}, '
                'which pays ${standing.pointsLabel}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POINTS AT EACH LEVEL',
            style: TextStyle(
              fontSize: 9.5,
              height: 1,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: Color(0xB3E6EBF3),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: RewardGraph.plotHeight,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _LadderPainter(
                  points: [for (final level in levels) level.points],
                  accents: [for (final level in levels) level.accent],
                  cleared: cleared,
                  markerIndex: baseIndex,
                  markerAdvance: advance,
                  pulse: _pulse.value,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Under each dot: the level, named as its card names it lower down
          // the screen, and the points it pays. The curve is compressed so
          // that the first rungs are not flat on the floor beside a rung
          // paying thirty times as much — so every dot says what it is
          // actually worth, and the shape is left to say only that the climb
          // steepens.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < levels.length; i++)
                Expanded(
                  child: _AxisLabel(
                    name: levels[i].name,
                    text: formatRupees(levels[i].points),
                    lit: levels[i].level <= cleared,
                    marked: i == targetIndex,
                    accent: levels[i].accent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  /// The level's name, as its card names it further down the screen.
  final String name;

  /// The points the rung pays, formatted.
  final String text;

  /// A rung the member has already cleared.
  final bool lit;

  /// The rung the marker is standing on.
  final bool marked;

  /// The rung's own colour, matching the level card lower down the screen.
  final Color accent;

  const _AxisLabel({
    required this.name,
    required this.text,
    required this.lit,
    required this.marked,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final legible = _legibleOnDeepBlue(accent);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The rung itself, named as its card names it, so a dot on the graph
        // and its card read as the same level. The one the member is standing
        // on is filled in the level's colour; the rest carry the name in it.
        Container(
          // The same padding whether or not it is filled, so the points
          // values below stay on one line across every column.
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: marked
              ? BoxDecoration(
                  color: legible,
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                height: 1,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w800,
                color: marked
                    ? AppColors.brandBlueDeep
                    : lit
                    ? legible
                    : const Color(0x8CE6EBF3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              height: 1,
              fontWeight: marked ? FontWeight.w800 : FontWeight.w600,
              color: marked || lit
                  ? AppColors.white
                  : const Color(0x8CE6EBF3),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lifts a rung's accent up off the deep-blue standing card so it stays
/// readable — a couple of the accents (Starter's blue especially) sit too
/// close to the card's own colour to be legible raw.
Color _legibleOnDeepBlue(Color accent) {
  final hsl = HSLColor.fromColor(accent);
  return hsl
      .withLightness(hsl.lightness < 0.62 ? 0.68 : hsl.lightness)
      .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
      .toColor();
}

/// The climb itself: a filled area up to where the member stands, a line on
/// past it, a dot on every rung and a marker on theirs.
class _LadderPainter extends CustomPainter {
  final List<int> points;

  /// Each rung's own colour, matching the level cards further down the screen,
  /// so a dot on the graph and its card read as the same level.
  final List<Color> accents;

  /// How many rungs are cleared, 0 to [points].length.
  final int cleared;

  /// The rung the marker sets off from — the last one cleared, or the first
  /// rung before anything is cleared.
  final int markerIndex;

  /// 0 to 1: how far along the rise from [markerIndex] to the next rung the
  /// member has climbed, so a half-finished Level 2 puts the marker halfway
  /// up the segment rather than parked on Level 1.
  final double markerAdvance;

  /// 0 to 1, driving the ring that opens out of the marker and fades.
  final double pulse;

  _LadderPainter({
    required this.points,
    required this.accents,
    required this.cleared,
    required this.markerIndex,
    required this.markerAdvance,
    required this.pulse,
  });

  /// The marker's position: [markerIndex]'s dot, nudged [markerAdvance] of the
  /// way towards the next dot along the straight segment between them.
  Offset _markerPoint(List<double> xs, List<double> ys) {
    if (markerAdvance <= 0 || markerIndex >= xs.length - 1) {
      return Offset(xs[markerIndex], ys[markerIndex]);
    }
    final t = markerAdvance.clamp(0.0, 1.0);
    return Offset(
      xs[markerIndex] + (xs[markerIndex + 1] - xs[markerIndex]) * t,
      ys[markerIndex] + (ys[markerIndex + 1] - ys[markerIndex]) * t,
    );
  }

  /// Kept clear at the top for the marker's ring, and at the sides so the
  /// end dots are not cut in half by the edge of the card.
  static const double _inset = 10;
  static const double _topPad = 12;

  static const double _dotRadius = 4;

  /// The curve is compressed by a square root rather than plotted straight.
  ///
  /// Level one pays 100 and level five pays 3,000: on a linear axis the first
  /// three rungs sit on the floor, indistinguishable, and a member standing on
  /// one of them sees a marker glued to the bottom of the card. The values are
  /// printed under every dot, so the axis is carrying shape rather than
  /// magnitude, and shape is what compresses honestly.
  static double _scale(double fraction) => math.sqrt(fraction);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    final left = _inset;
    final right = size.width - _inset;
    final top = _topPad;
    final bottom = size.height;
    final span = right - left;
    final height = bottom - top;
    final max = points.reduce(math.max).toDouble();

    final xs = <double>[
      for (var i = 0; i < points.length; i++)
        left + span * i / (points.length - 1),
    ];
    final ys = <double>[
      for (final value in points) bottom - height * _scale(value / max),
    ];

    final marker = _markerPoint(xs, ys);

    _paintBaseline(canvas, left, right, bottom);

    // Everything past where the member stands, drawn first and thinner, so
    // the climb they have made sits on top of the climb still ahead.
    final ahead = Path()..moveTo(xs.first, ys.first);
    for (var i = 1; i < xs.length; i++) {
      ahead.lineTo(xs[i], ys[i]);
    }
    canvas.drawPath(
      ahead,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white.withValues(alpha: 0.4),
    );

    _paintClimbed(canvas, xs, ys, bottom, marker);

    for (var i = 0; i < xs.length; i++) {
      _paintDot(canvas, Offset(xs[i], ys[i]), i);
    }

    _paintMarker(canvas, marker);
  }

  void _paintBaseline(Canvas canvas, double left, double right, double y) {
    canvas.drawLine(
      Offset(left - _inset / 2, y),
      Offset(right + _inset / 2, y),
      Paint()
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: 0.16),
    );
  }

  /// The stretch of the climb the member has actually made: a solid white
  /// line through every cleared rung and on to the marker, with the area
  /// under it washed in white.
  ///
  /// Runs to the marker rather than to the last cleared rung, so a Level 1
  /// that is done and a Level 2 that is a third referred reads as a climb
  /// already under way, not a marker frozen on a rung.
  void _paintClimbed(
    Canvas canvas,
    List<double> xs,
    List<double> ys,
    double bottom,
    Offset marker,
  ) {
    // Nothing cleared and not yet moving: the marker just sits on the first
    // dot, there is no climb behind it to draw.
    if (markerIndex == 0 && markerAdvance <= 0) {
      return;
    }

    final line = Path()..moveTo(xs.first, ys.first);
    for (var i = 1; i <= markerIndex; i++) {
      line.lineTo(xs[i], ys[i]);
    }
    line.lineTo(marker.dx, marker.dy);

    final area = Path.from(line)
      ..lineTo(marker.dx, bottom)
      ..lineTo(xs.first, bottom)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white.withValues(alpha: 0.22),
            AppColors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromLTRB(xs.first, marker.dy, marker.dx, bottom),
        ),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
  }

  /// A dot on every rung, in that rung's own colour so it matches the level
  /// card lower down the screen. Cleared rungs are filled solid; the rung the
  /// climb is heading for carries a full-weight ring; rungs beyond it are
  /// hollow and faint — the card's deep blue with a thin accent outline.
  void _paintDot(Canvas canvas, Offset at, int index) {
    final done = index < cleared;
    final target = index == cleared && cleared < points.length;
    final accent = accents[index];

    canvas.drawCircle(
      at,
      _dotRadius,
      Paint()..color = done ? accent : AppColors.brandBlueDeep,
    );
    canvas.drawCircle(
      at,
      _dotRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = done || target ? 1.8 : 1.4
        ..color = done || target ? accent : accent.withValues(alpha: 0.6),
    );
  }

  /// Where the member is standing: a filled white disc a size up from the
  /// plain rung dots, cored in that rung's own colour, with a white ring that
  /// opens out of it and fades on every pulse. White so it reads as the head
  /// of the white climb line rather than as one more coloured rung.
  void _paintMarker(Canvas canvas, Offset at) {
    final accent = accents[markerIndex];

    if (pulse > 0) {
      canvas.drawCircle(
        at,
        _dotRadius + 3 + pulse * 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.white.withValues(alpha: 0.6 * (1 - pulse)),
      );
    }

    canvas.drawCircle(at, _dotRadius + 3, Paint()..color = AppColors.white);
    canvas.drawCircle(at, _dotRadius - 0.2, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _LadderPainter old) =>
      old.pulse != pulse ||
      old.cleared != cleared ||
      old.markerIndex != markerIndex ||
      old.markerAdvance != markerAdvance ||
      !listEquals(old.points, points) ||
      !listEquals(old.accents, accents);
}
