import 'package:flutter/material.dart';

import '../dates.dart';
import '../theme/app_colors.dart';

/// The age a date of birth works out to, printed as a pill.
///
/// The age is never typed anywhere in the app: a date and a number of years
/// are two answers that can disagree, and the number is wrong from the next
/// birthday onwards. So a form takes the date and prints the age back.
class AgeBadge extends StatelessWidget {
  final DateTime dob;

  /// Fixes "today" for tests; production always reads the clock.
  final DateTime? asOf;

  const AgeBadge({super.key, required this.dob, this.asOf});

  @override
  Widget build(BuildContext context) {
    final label = ageLabel(dob, asOf: asOf);
    return Semantics(
      label: 'Age $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.offerTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brandBlue, width: 1.1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.brandBlue,
          ),
        ),
      ),
    );
  }
}

/// What every date-of-birth field hangs off its right edge: the derived age
/// once a date is picked, and the calendar affordance always.
///
/// One widget rather than two copies, so the age cannot appear on one form and
/// not the other.
class DobFieldSuffix extends StatelessWidget {
  /// Null until a date is picked, when only the calendar icon shows.
  final DateTime? dob;

  final DateTime? asOf;

  const DobFieldSuffix({super.key, this.dob, this.asOf});

  @override
  Widget build(BuildContext context) {
    final picked = dob;
    return Row(
      // The suffix must size to its contents; without this it claims the field.
      mainAxisSize: MainAxisSize.min,
      children: [
        if (picked != null) ...[
          AgeBadge(dob: picked, asOf: asOf),
          const SizedBox(width: 8),
        ],
        const Padding(
          padding: EdgeInsets.only(right: 14),
          child: Icon(
            Icons.calendar_month_rounded,
            size: 19,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
