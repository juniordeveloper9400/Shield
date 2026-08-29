import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'prescription_copy.dart';
import 'prescription_record.dart';

/// One uploaded prescription, shown as the pharmacy read it: who it is for,
/// who prescribed it, and a line per medicine with its intake and its total.
///
/// A view, not a form. The member uploads an image; a pharmacist at the
/// counter keys in what is written on it, and this card shows that back so
/// the member can check it against the paper before it goes to the cart.
/// Nothing on the lower half is theirs to type — a dose that could be edited
/// here would be a dose the prescription never authorised.
class PrescriptionDetailCard extends StatelessWidget {
  final PrescriptionRecord record;
  final PrescriptionCopy copy;
  final VoidCallback onDelete;
  final VoidCallback onAddToCart;

  const PrescriptionDetailCard({
    super.key,
    required this.record,
    required this.copy,
    required this.onDelete,
    required this.onAddToCart,
  });

  /// Widths the headings and every row share, so the three columns line up.
  static const double intakeWidth = 54;
  static const double totalWidth = 52;

  @override
  Widget build(BuildContext context) {
    final waiting = record.isAwaitingReview;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: record.inCart ? AppColors.brandGreenDeep : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(record: record, copy: copy),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FactRow(label: copy.patientRow, value: record.patient.name),
                const SizedBox(height: 9),
                _FactRow(
                  label: copy.doctorRow,
                  value: record.doctor.isEmpty ? '—' : record.doctor,
                  muted: record.doctor.isEmpty,
                ),
                if (record.isRecurring) ...[
                  const SizedBox(height: 9),
                  _FactRow(
                    label: copy.repeatsRow,
                    value: record.recurring!.neverExpires
                        ? '${record.recurring!.fromLabel} · '
                              '${copy.neverExpires.toLowerCase()}'
                        : '${record.recurring!.fromLabel} → '
                              '${record.recurring!.untilLabel}',
                    icon: Icons.autorenew_rounded,
                  ),
                ],
                const SizedBox(height: 13),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 11),
                if (waiting)
                  _AwaitingReview(copy: copy)
                else ...[
                  _ColumnHeadings(copy: copy),
                  const SizedBox(height: 2),
                  for (final medicine in record.medicines)
                    _MedicineRow(
                      medicine: medicine,
                      days: record.days,
                      copy: copy,
                    ),
                  const SizedBox(height: 2),
                  _IntakeLegend(copy: copy),
                ],
              ],
            ),
          ),
          _Actions(
            record: record,
            copy: copy,
            onDelete: onDelete,
            onAddToCart: onAddToCart,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final PrescriptionRecord record;
  final PrescriptionCopy copy;

  const _Header({required this.record, required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: record.inCart ? AppColors.greenTint : AppColors.pageTint,
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            size: 20,
            color: record.inCart
                ? AppColors.brandGreenDark
                : AppColors.brandBlue,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (record.supplyLabel.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    record.supplyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (record.inCart) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.brandGreenDeep),
              ),
              child: Text(
                copy.inCart,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandGreenDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A label and the value beside it. Everything on this card is one of these.
class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool muted;

  const _FactRow({
    required this.label,
    required this.value,
    this.icon,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 66,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 5),
            child: Icon(icon, size: 15, color: AppColors.brandBlue),
          ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.textMuted : AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown while the upload is still with the counter.
///
/// The card exists from the moment the file is sent, so it has to be able to
/// say what is happening to it — an empty table would read as a prescription
/// with nothing on it rather than one nobody has read yet.
class _AwaitingReview extends StatelessWidget {
  final PrescriptionCopy copy;

  const _AwaitingReview({required this.copy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageTint,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A still icon rather than a spinner: this waits on a person at a
          // counter, not on a request in flight, and a spinner would promise
          // an answer in the next second for minutes on end.
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.awaitingReview,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  copy.awaitingReviewDetail,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeadings extends StatelessWidget {
  final PrescriptionCopy copy;

  const _ColumnHeadings({required this.copy});

  static const TextStyle _style = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(copy.product, style: _style)),
          SizedBox(
            width: PrescriptionDetailCard.intakeWidth,
            child: Text(
              copy.intake,
              textAlign: TextAlign.center,
              style: _style,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: PrescriptionDetailCard.totalWidth,
            child: Text(copy.total, textAlign: TextAlign.right, style: _style),
          ),
        ],
      ),
    );
  }
}

/// One line of the table: what to dispense, how it is taken, and how much of
/// it that adds up to over the run the prescription was uploaded for.
class _MedicineRow extends StatelessWidget {
  final PrescriptionMedicine medicine;
  final int days;
  final PrescriptionCopy copy;

  const _MedicineRow({
    required this.medicine,
    required this.days,
    required this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final intake = medicine.intake;
    final total = intake.totalFor(days);
    final spelled = intake.labelWith(copy.intakeSlots, copy.intakeNotSet);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // The pack and the code spelled out: between them they say
                  // what arrives and when it is taken, which is what a member
                  // checks this card against the paper for.
                  medicine.pack.isEmpty
                      ? spelled
                      : '${medicine.pack} · $spelled',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: PrescriptionDetailCard.intakeWidth,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.offerTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  intake.code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: PrescriptionDetailCard.totalWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  copy.units,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the three digits mean, said once under the table rather than on every
/// row. Someone meeting `101` for the first time needs it; someone who has
/// read a prescription before does not.
class _IntakeLegend extends StatelessWidget {
  final PrescriptionCopy copy;

  const _IntakeLegend({required this.copy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 6),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              copy.intakeHelp,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final PrescriptionRecord record;
  final PrescriptionCopy copy;
  final VoidCallback onDelete;
  final VoidCallback onAddToCart;

  const _Actions({
    required this.record,
    required this.copy,
    required this.onDelete,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: [
          // Shared out rather than sized to their labels: Malayalam sets both
          // of these longer than English does, and neither may push the other
          // off the card.
          Expanded(
            flex: 4,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                copy.delete,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: FilledButton.icon(
              // Nothing to send while the counter is still reading it, and
              // nothing to send twice once the lines are in the cart.
              onPressed: record.canOrder && !record.inCart ? onAddToCart : null,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: Text(
                record.inCart ? copy.inCart : copy.addToCart,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                disabledBackgroundColor: AppColors.searchBorder,
                foregroundColor: AppColors.white,
                disabledForegroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
