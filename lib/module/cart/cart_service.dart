import 'package:flutter/foundation.dart';

/// One line in the cart.
class CartLine {
  final String name;
  final String pack;
  final double price;
  int qty;

  CartLine({
    required this.name,
    required this.pack,
    required this.price,
    this.qty = 1,
  });

  double get lineTotal => price * qty;

  /// False for a line that came off a prescription: the pharmacist prices it
  /// once the medicines are confirmed, and a made-up ₹0.00 would read as free.
  bool get isPriced => price > 0;
}

/// The shopping cart, shared by the badge and the cart screen so the count on
/// the icon can never disagree with the contents.
class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartLine> _lines = [];

  List<CartLine> get lines => List.unmodifiable(_lines);

  bool get isEmpty => _lines.isEmpty;

  /// Total units, not distinct products: two boxes of one item count as two.
  int get itemCount => _lines.fold(0, (sum, line) => sum + line.qty);

  double get subtotal => _lines.fold(0, (sum, line) => sum + line.lineTotal);

  double get discount => subtotal * 0.26;

  double get deliveryFee => _lines.isEmpty ? 0 : 40;

  double get payable => subtotal - discount + deliveryFee;

  /// Adds [qty] units, merging into the existing line when the product is
  /// already in the cart rather than creating a duplicate row.
  ///
  /// [qty] is there for prescriptions, which arrive as a whole run at once —
  /// ninety tablets, not one tapped ninety times.
  void add({
    required String name,
    required String pack,
    required double price,
    int qty = 1,
  }) {
    if (qty <= 0) {
      return;
    }
    final existing = _lines.indexWhere((line) => line.name == name);
    if (existing >= 0) {
      _lines[existing].qty += qty;
    } else {
      _lines.add(CartLine(name: name, pack: pack, price: price, qty: qty));
    }
    notifyListeners();
  }

  /// Steps a line's quantity, removing the line when it reaches zero.
  void changeQty(int index, int delta) {
    if (index < 0 || index >= _lines.length) {
      return;
    }
    final next = _lines[index].qty + delta;
    if (next <= 0) {
      _lines.removeAt(index);
    } else {
      _lines[index].qty = next;
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  /// Test hook: empties the cart and seeds nothing.
  @visibleForTesting
  void reset() => clear();

  /// Fixture used so the cart is not empty on first open during development.
  void seedSampleLines() {
    if (_lines.isNotEmpty) {
      return;
    }
    _lines.addAll([
      CartLine(
        name: 'Dolo 650mg Tablet',
        pack: 'Strip of 15 tablets',
        price: 32.5,
        qty: 2,
      ),
      CartLine(
        name: 'Shelcal 500 Calcium',
        pack: 'Strip of 15 tablets',
        price: 118,
      ),
    ]);
    notifyListeners();
  }
}
