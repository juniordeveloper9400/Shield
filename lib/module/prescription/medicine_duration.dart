/// How long a prescription should be dispensed for.
///
/// A fixed set rather than a free number of days: a pharmacist dispenses in
/// whole strips and packs, and these are the runs that map onto them.
enum MedicineDuration {
  oneWeek('1 week', 7),
  fifteenDays('15 days', 15),
  oneMonth('1 month', 30),
  twoMonths('2 months', 60),
  threeMonths('3 months', 90);

  final String label;
  final int days;

  const MedicineDuration(this.label, this.days);

  /// "1 month · 30 days' supply" — the confirmation line.
  String get supplyLabel => "$label · $days days' supply";
}
