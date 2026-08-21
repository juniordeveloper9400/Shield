/// Indian digit grouping for rupee amounts: 1732 → "1,732", 129900 →
/// "1,29,900".
///
/// Shared: the lab catalogue writes its prices pre-grouped but multiplies them
/// by the patient count, and the wallet adds a bonus to a balance. Both end up
/// with numbers that have to be grouped at runtime.
String formatRupees(int amount) {
  final digits = amount.abs().toString();
  final sign = amount < 0 ? '-' : '';
  if (digits.length <= 3) {
    return '$sign$digits';
  }

  // Last three digits stand alone; everything above them groups in pairs.
  final tail = digits.substring(digits.length - 3);
  final head = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  var rest = head;
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) {
    groups.insert(0, rest);
  }

  return '$sign${groups.join(',')},$tail';
}
