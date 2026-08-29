import 'package:flutter/foundation.dart';

import 'prescription_record.dart';

/// One prescription waiting to be dispensed.
///
/// The whole prescription, not its medicines. A prescription is filled as a
/// unit — the pharmacist reads one paper, counts out everything on it and
/// prices the lot — so it is one thing in the basket however many lines it
/// carries, and it is identified by its number rather than by its contents.
@immutable
class PrescriptionOrder {
  final PrescriptionRecord record;

  const PrescriptionOrder({required this.record});

  /// "RX-0004" — what the member quotes at the counter.
  String get number => record.number;

  /// Complete lines only. A half-keyed row is not something to dispense.
  int get medicineCount => record.dispensable.length;

  /// Every unit across every line: what the pharmacist actually counts out.
  int get unitCount => record.totalUnits;

  /// Nothing on a prescription carries a price until the counter has read it
  /// and confirmed what is being dispensed against it. A basket that showed
  /// ₹0.00 would read as free rather than as not yet priced.
  bool get isPriced => false;
}

/// The prescription basket.
///
/// The third of three, and separate from both for the same reason they are
/// separate from each other. `CartService` holds boxed products with a
/// quantity and a price; `LabCartService` holds scheduled visits priced per
/// patient; this holds paper waiting on a pharmacist. Only one of the three
/// can be totalled at all before somebody at the counter has looked at it.
///
/// It used to be no basket at all: sending a prescription to the cart broke
/// it into one product line per medicine, which lost the prescription — six
/// lines from one paper were indistinguishable from six things picked off
/// the shelf, and nothing in the cart could be traced back to the number the
/// counter files it under.
///
/// In memory only; a backend would replace this class wholesale.
class PrescriptionCartService extends ChangeNotifier {
  PrescriptionCartService._();

  static final PrescriptionCartService instance = PrescriptionCartService._();

  final List<PrescriptionOrder> _orders = [];

  List<PrescriptionOrder> get orders => List.unmodifiable(_orders);

  bool get isEmpty => _orders.isEmpty;

  /// Prescriptions in the basket — what the badge and the home tile show.
  ///
  /// Prescriptions, not medicines: a paper with six lines on it is one thing
  /// to collect, and one row on the screen.
  int get orderCount => _orders.length;

  /// Every medicine across every prescription, which is what the counter has
  /// to dispense.
  int get medicineCount =>
      _orders.fold(0, (sum, order) => sum + order.medicineCount);

  /// Whether the prescription filed under [id] is already in the basket.
  bool contains(String id) =>
      _orders.any((order) => order.record.id == id);

  /// Puts [record] in the basket.
  ///
  /// Replaces rather than appends when the prescription is already there.
  /// Sending the same paper twice is a correction — the pharmacy may have
  /// keyed another medicine onto it since — not a second order, and a
  /// prescription can only be dispensed once whatever the member taps.
  void add(PrescriptionRecord record) {
    final index = _orders.indexWhere((order) => order.record.id == record.id);
    final order = PrescriptionOrder(record: record);

    if (index == -1) {
      _orders.add(order);
    } else {
      _orders[index] = order;
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _orders.length) {
      return;
    }
    _orders.removeAt(index);
    notifyListeners();
  }

  /// Takes the prescription filed under [id] out of the basket, if it is in
  /// it. Used when the record itself is deleted, so the basket cannot go on
  /// holding a prescription that no longer exists.
  void remove(String id) {
    final before = _orders.length;
    _orders.removeWhere((order) => order.record.id == id);
    if (_orders.length != before) {
      notifyListeners();
    }
  }

  void clear() {
    _orders.clear();
    notifyListeners();
  }

  @visibleForTesting
  void reset() => clear();
}
