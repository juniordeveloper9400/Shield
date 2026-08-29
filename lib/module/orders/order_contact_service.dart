import 'package:flutter/foundation.dart';

/// The extra ways a member can be reached about an order: a contact email and
/// a second phone number, both added from the Track order screen.
///
/// Held here rather than on the [Purchase] because they are the member's
/// standing preferences — added once, they apply to the next order too — and
/// because a real backend would key them on the account, not the order.
///
/// In memory only; a backend would replace this class wholesale.
class OrderContactService extends ChangeNotifier {
  OrderContactService._();

  static final OrderContactService instance = OrderContactService._();

  String? _email;
  String? _alternateNumber;

  /// The contact email, or null when none has been added.
  String? get email => _email;

  /// The second number, or null when none has been added.
  String? get alternateNumber => _alternateNumber;

  bool get hasEmail => _email != null;

  bool get hasAlternateNumber => _alternateNumber != null;

  /// Sets the email, or clears it when passed blank.
  void setEmail(String? value) {
    final clean = value?.trim() ?? '';
    _email = clean.isEmpty ? null : clean;
    notifyListeners();
  }

  /// Sets the second number, or clears it when passed blank.
  void setAlternateNumber(String? value) {
    final clean = value?.trim() ?? '';
    _alternateNumber = clean.isEmpty ? null : clean;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _email = null;
    _alternateNumber = null;
    notifyListeners();
  }
}
