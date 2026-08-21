import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'referral_level.dart';

/// Serpentine level map: nodes alternate left and right, joined by a curved
/// connector that is solid where the member has already progressed and dashed
/// where the path is still locked.
class JourneyMap extends StatelessWidget {
  final List<ReferralLevel> levels;
  final ReferralProgress progress;

  const JourneyMap({super.key, required this.levels, required this.progress});

  /// Distance from the edge to the centre of a node.
  static const double nodeInset = 44;
  static const double nodeSize = 56;
  static const double connectorHeight = 46;

  bool _isLeft(int index) => index.isEven;

  @override
  Widget build(BuildContext context) {
    final cleared = progress.currentLevel(levels);

    return Column(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          if (i > 0)
            SizedBox(
              height: connectorHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _ConnectorPainter(
                  fromLeft: _isLeft(i - 1),
                  toLeft: _isLeft(i),
                  // Solid once the level the path leads *into* is reachable.
                  reached: levels[i].level <= cleared + 1,
                ),
              ),
            ),
          _LevelRow(
            level: levels[i],
            progress: progress,
            isLeft: _isLeft(i),
            state: _stateFor(levels[i], cleared),
          ),
        ],
      ],
    );
  }

  _NodeState _stateFor(ReferralLevel level, int cleared) {
    if (level.level <= cleared) {
      return _NodeState.cleared;
    }
    if (level.level == cleared + 1) {
      return _NodeState.current;
    }
    return _NodeState.locked;
  }
}

enum _NodeState { cleared, current, locked }

class _LevelRow extends StatelessWidget {
  final ReferralLevel level;
  final ReferralProgress progress;
  final bool isLeft;
  final _NodeState state;

  const _LevelRow({
    required this.level,
    required this.progress,
    required this.isLeft,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final node = _LevelNode(level: level, state: state);
    final card = _LevelCard(level: level, progress: progress, state: state);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: isLeft
            ? [node, const SizedBox(width: 12), Expanded(child: card)]
            : [Expanded(child: card), const SizedBox(width: 12), node],
      ),
    );
  }
}

class _LevelNode extends StatelessWidget {
  final ReferralLevel level;
  final _NodeState state;

  const _LevelNode({required this.level, required this.state});

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (state) {
      _NodeState.cleared => (
        AppColors.brandGreenDeep,
        AppColors.brandGreenDeep,
        AppColors.white,
      ),
      _NodeState.current => (
        AppColors.brandBlue,
        AppColors.brandBlue,
        AppColors.white,
      ),
      _NodeState.locked => (
        AppColors.white,
        AppColors.searchBorder,
        AppColors.textMuted,
      ),
    };

    return Container(
      width: JourneyMap.nodeSize,
      height: JourneyMap.nodeSize,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        boxShadow: state == _NodeState.current
            ? [
                BoxShadow(
                  color: AppColors.brandBlue.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: switch (state) {
        _NodeState.cleared => Icon(
          Icons.check_rounded,
          size: 28,
          color: foreground,
        ),
        _NodeState.locked => Icon(
          Icons.lock_outline_rounded,
          size: 22,
          color: foreground,
        ),
        _NodeState.current => Text(
          '${level.level}',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
        ),
      },
    );
  }
}

class _LevelCard extends StatelessWidget {
  final ReferralLevel level;
  final ReferralProgress progress;
  final _NodeState state;

  const _LevelCard({
    required this.level,
    required this.progress,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = state == _NodeState.current;

    return Container(
      decoration: BoxDecoration(
        color: state == _NodeState.locked
            ? AppColors.pageTint
            : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.brandBlue : AppColors.border,
          width: isCurrent ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Level ${level.level} · ${level.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (state == _NodeState.cleared) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: AppColors.brandGreenDeep,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            level.requirement,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 10),

          // The two thresholds that gate this level, each with live counts so
          // the map reads off the member's actual details.
          _DetailBar(
            label: 'Referred',
            have: progress.directReferrals,
            need: level.directRequired,
            state: state,
          ),
          if (level.cardsRequired > 0) ...[
            const SizedBox(height: 6),
            _DetailBar(
              label: 'Privilege',
              have: progress.effectiveCards,
              need: level.cardsRequired,
              state: state,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: level.isCash
                      ? AppColors.greenTint
                      : AppColors.offerTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Earn ${level.reward}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: level.isCash
                        ? AppColors.brandGreenDark
                        : AppColors.brandBlue,
                  ),
                ),
              ),
              Text(
                switch (state) {
                  _NodeState.cleared => 'Cleared',
                  _NodeState.current => 'In progress',
                  _NodeState.locked => 'Locked',
                },
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: switch (state) {
                    _NodeState.cleared => AppColors.brandGreenDeep,
                    _NodeState.current => AppColors.brandBlue,
                    _NodeState.locked => AppColors.textMuted,
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final bool fromLeft;
  final bool toLeft;
  final bool reached;

  _ConnectorPainter({
    required this.fromLeft,
    required this.toLeft,
    required this.reached,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftX = JourneyMap.nodeInset;
    final rightX = size.width - JourneyMap.nodeInset;
    final startX = fromLeft ? leftX : rightX;
    final endX = toLeft ? leftX : rightX;

    final path = Path()
      ..moveTo(startX, 0)
      // Mirrored control points give a symmetric S between the two nodes.
      ..cubicTo(
        startX,
        size.height * 0.55,
        endX,
        size.height * 0.45,
        endX,
        size.height,
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = reached ? AppColors.brandGreenDeep : AppColors.searchBorder;

    if (reached) {
      canvas.drawPath(path, paint);
    } else {
      canvas.drawPath(_dashed(path), paint);
    }
  }

  /// Rebuilds [source] as a dashed path by walking its metrics.
  Path _dashed(Path source, {double dash = 7, double gap = 5}) {
    final result = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        result.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.fromLeft != fromLeft ||
        oldDelegate.toLeft != toLeft ||
        oldDelegate.reached != reached;
  }
}

/// One threshold of a level: a label, a `have/need` count, and a bar showing
/// how much of that requirement is met.
class _DetailBar extends StatelessWidget {
  final String label;
  final int have;
  final int need;
  final _NodeState state;

  const _DetailBar({
    required this.label,
    required this.have,
    required this.need,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final met = have >= need;
    final fraction = need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);
    final barColour = met
        ? AppColors.brandGreenDeep
        : (state == _NodeState.locked
              ? AppColors.searchBorder
              : AppColors.brandBlue);

    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(barColour),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          // Clamp the displayed figure so an over-target count does not read as
          // "60/8" against an already-cleared level.
          '${have > need ? need : have}/$need',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: met ? AppColors.brandGreenDeep : AppColors.textBody,
          ),
        ),
      ],
    );
  }
}
