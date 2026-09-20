import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../orders/order_track.dart';
import '../orders/order_track_screen.dart';
import '../orders/purchase_service.dart';
import 'prescription_copy.dart';
import 'prescription_record.dart';

/// Where the order a prescription was placed into has got to — the same
/// stages as the Track order screen (Order placed → Processing → Out for
/// delivery → Delivered, or Cancelled), shown right on the prescription's card
/// so a member need not leave "Your prescriptions" to see it.
///
/// The steps come from [OrderTrack], the very tracker Track order draws, so the
/// two can never disagree. The app's loaded order book is preferred over what
/// the prescription row reported ([PrescriptionRecord.order]) since it is
/// refreshed more often; the card falls back on the latter until the book has
/// the order.
///
/// Nothing at all for a prescription that is not linked to an order.
class PrescriptionOrderStatus extends StatelessWidget {
  final PrescriptionRecord record;
  final PrescriptionCopy copy;

  const PrescriptionOrderStatus({
    super.key,
    required this.record,
    required this.copy,
  });

  /// The four stages of a live order, in [OrderTrack.steps] order.
  List<String> get _stageLabels => [
    copy.stagePlaced,
    copy.stageProcessing,
    copy.stageOutForDelivery,
    copy.stageDelivered,
  ];

  @override
  Widget build(BuildContext context) {
    final link = record.order;
    if (link == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: PurchaseService.instance,
      builder: (context, _) {
        final purchase = PurchaseService.instance.purchaseFor(link);
        final order = purchase ?? link.toPurchase();
        final track = OrderTrack(order);
        final steps = track.steps;
        final cancelled = track.isCancelled;

        // The stage the order sits on: the last step reached (all four once
        // delivered).
        final reached = cancelled
            ? -1
            : steps.lastIndexWhere((s) => s.state != TrackState.upcoming);
        final label = cancelled
            ? copy.stageCancelled
            : _stageLabels[reached.clamp(0, _stageLabels.length - 1)];
        final detail = switch (order.status) {
          OrderStatus.cancelled => copy.stageCancelledDetail,
          OrderStatus.delivered => copy.stageDeliveredDetail,
          OrderStatus.outForDelivery => copy.stageOutForDeliveryDetail,
          OrderStatus.processing => copy.stagePlacedDetail,
        };
        final color = order.status.foreground;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          decoration: BoxDecoration(
            color: order.status.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.orderStatusTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          link.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      label,
                      key: const ValueKey('order-stage-chip'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (!cancelled) ...[
                const SizedBox(height: 12),
                _StageTrack(
                  steps: steps,
                  labels: _stageLabels,
                  reached: reached,
                  color: color,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textBody,
                ),
              ),
              if (purchase != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderTrackScreen(order: purchase),
                      ),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: Text(copy.trackOrder),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandBlue,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The four-dot progress line: a dot per stage, joined by a line filled up to
/// the stage reached. Done stages are ticked, the current one is ringed, and
/// the rest are hollow.
class _StageTrack extends StatelessWidget {
  final List<TrackStep> steps;
  final List<String> labels;
  final int reached;
  final Color color;

  const _StageTrack({
    required this.steps,
    required this.labels,
    required this.reached,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2.5,
                    color: i <= reached ? color : AppColors.border,
                  ),
                ),
              _Dot(state: steps[i].state, color: color),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  // The end labels hug their dot's edge so the row does not run
                  // past the card; the middle ones centre under theirs.
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == steps.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: i == reached
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i <= reached
                        ? AppColors.textDark
                        : AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final TrackState state;
  final Color color;

  const _Dot({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    if (state == TrackState.done) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 12, color: AppColors.white),
      );
    }
    final active = state == TrackState.current;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? color : AppColors.border,
          width: active ? 4 : 2,
        ),
      ),
    );
  }
}
