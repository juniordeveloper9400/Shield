import 'package:flutter/foundation.dart';

/// A SHIELD outlet. Every registered member is assigned one, and it is the
/// branch their orders are packed and dispatched from.
@immutable
class ShieldStore {
  /// Stable code, and what a saved registration stores rather than the object.
  final String id;

  final String name;
  final String area;
  final String city;
  final String state;
  final String pincode;

  /// Blank until a branch publishes one. Nothing shows it yet, and a wrong
  /// number on a real shop is worse than no number.
  final String phone;

  /// Opening hours, shown on the store card so a member can tell whether
  /// walking in today is an option.
  final String hours;

  const ShieldStore({
    required this.id,
    required this.name,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    this.phone = '',
    this.hours = '8:00 AM – 10:00 PM',
  });

  /// "Melattur, Malappuram · 679326"
  String get addressLine => '$area, $city · $pincode';
}

/// The published outlets, and the rule for picking the nearest one.
class StoreDirectory {
  const StoreDirectory._();

  /// The branches, in the order SHIELD lists them.
  ///
  /// All but Alanallur are in Malappuram; the pincode is the district's, so
  /// [nearest] ranks the whole list off a member's own code without any
  /// geocoding. A branch that opens elsewhere only has to be added here.
  static const List<ShieldStore> all = [
    ShieldStore(
      id: 'SHD-MEL',
      name: 'SHIELD Pharmacy Melattur',
      area: 'Melattur',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '679326',
    ),
    ShieldStore(
      id: 'SHD-MKP',
      name: 'SHIELD Pharmacy Makkaraparamba',
      area: 'Makkaraparamba',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '676507',
    ),
    ShieldStore(
      id: 'SHD-TIR',
      name: 'SHIELD Pharmacy Tirur',
      area: 'Tirur',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '676101',
    ),
    ShieldStore(
      id: 'SHD-KKT',
      name: 'SHIELD Pharmacy Karinkallathani',
      area: 'Karinkallathani',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '679321',
    ),
    ShieldStore(
      id: 'SHD-MJR',
      name: 'SHIELD Pharmacy Manjery',
      area: 'Manjery',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '676121',
    ),
    ShieldStore(
      id: 'SHD-ALN',
      name: 'SHIELD Pharmacy Alanallur',
      area: 'Alanallur',
      city: 'Palakkad',
      state: 'Kerala',
      pincode: '678601',
    ),
    ShieldStore(
      id: 'SHD-TRD',
      name: 'SHIELD Pharmacy Tirurangadi',
      area: 'Tirurangadi',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '676306',
    ),
    ShieldStore(
      id: 'SHD-KNP',
      name: 'SHIELD Pharmacy Kunnumpuram',
      area: 'Kunnumpuram',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '676505',
    ),
    ShieldStore(
      id: 'SHD-KND',
      name: 'SHIELD Pharmacy Kondotty',
      area: 'Kondotty',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '673638',
    ),
    ShieldStore(
      id: 'SHD-ARK',
      name: 'SHIELD Pharmacy Areekode',
      area: 'Areekode',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '673639',
    ),
  ];

  static ShieldStore? byId(String? id) {
    if (id == null) {
      return null;
    }
    for (final store in all) {
      if (store.id == id) {
        return store;
      }
    }
    return null;
  }

  /// Every store, nearest to [pincode] first.
  ///
  /// There is no geocoding in this build, so proximity is read off the pincode
  /// itself: Indian codes are allocated by region, so the more leading digits
  /// two share, the closer they are — 679326 (Melattur) and 679321
  /// (Karinkallathani) share five and are a few kilometres apart, while
  /// 673639 (Areekode) shares two and is an hour away. Codes that tie on that
  /// are ordered by plain numeric distance. A backend with real coordinates
  /// replaces this method and nothing else.
  static List<ShieldStore> nearest(String pincode) {
    final clean = pincode.trim();
    final ranked = List<ShieldStore>.of(all);
    if (clean.length != 6 || int.tryParse(clean) == null) {
      return ranked;
    }

    final target = int.parse(clean);
    ranked.sort((a, b) {
      final byPrefix = _sharedPrefix(
        b.pincode,
        clean,
      ).compareTo(_sharedPrefix(a.pincode, clean));
      if (byPrefix != 0) {
        return byPrefix;
      }
      final da = (int.parse(a.pincode) - target).abs();
      final db = (int.parse(b.pincode) - target).abs();
      return da.compareTo(db);
    });
    return ranked;
  }

  /// The store to pre-select for [pincode], or null when it is not a pincode
  /// yet — an incomplete code must not silently assign a branch.
  static ShieldStore? suggestFor(String pincode) {
    final clean = pincode.trim();
    if (clean.length != 6 || int.tryParse(clean) == null) {
      return null;
    }
    return nearest(clean).first;
  }

  static int _sharedPrefix(String a, String b) {
    var count = 0;
    while (count < a.length && count < b.length && a[count] == b[count]) {
      count++;
    }
    return count;
  }
}
