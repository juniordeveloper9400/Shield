const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `04 Sep 1994` — the one date format the app writes.
///
/// Shared: registration and the patient book both take a date of birth from a
/// picker and both have to print it back. Two copies would drift.
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_months[date.month - 1]} ${date.year}';
}

/// Whole years between [dob] and [asOf], defaulting to today.
///
/// Counts the birthday, not the year difference: someone born in December is
/// still the younger age until December comes round.
int ageInYears(DateTime dob, {DateTime? asOf}) {
  final now = asOf ?? DateTime.now();
  var years = now.year - dob.year;
  final hadBirthday =
      now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
  if (!hadBirthday) {
    years--;
  }
  return years < 0 ? 0 : years;
}
