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
    required this.phone,
    this.hours = '8:00 AM – 10:00 PM',
  });

  /// "Perinthalmanna, Malappuram · 679322"
  String get addressLine => '$area, $city · $pincode';
}

/// The published outlets, and the rule for picking the nearest one.
class StoreDirectory {
  const StoreDirectory._();

  static const List<ShieldStore> all = [
    ShieldStore(
      id: 'SHD-PTM',
      name: 'SHIELD Pharmacy Perinthalmanna',
      area: 'Kottakkal Road',
      city: 'Perinthalmanna',
      state: 'Kerala',
      pincode: '679322',
      phone: '9400525063',
    ),
    ShieldStore(
      id: 'SHD-MJR',
      name: 'SHIELD Pharmacy Manjeri',
      area: 'Kacheripadi',
      city: 'Manjeri',
      state: 'Kerala',
      pincode: '676121',
      phone: '9400525064',
    ),
    ShieldStore(
      id: 'SHD-MLP',
      name: 'SHIELD Pharmacy Malappuram',
      area: 'Up Hill',
      city: 'Malappuram',
      state: 'Kerala',
      pincode: '676505',
      phone: '9400525065',
    ),
    ShieldStore(
      id: 'SHD-KKD',
      name: 'SHIELD Pharmacy Kozhikode',
      area: 'Mavoor Road',
      city: 'Kozhikode',
      state: 'Kerala',
      pincode: '673004',
      phone: '9400525066',
      hours: 'Open 24 hours',
    ),
    ShieldStore(
      id: 'SHD-TSR',
      name: 'SHIELD Pharmacy Thrissur',
      area: 'Round South',
      city: 'Thrissur',
      state: 'Kerala',
      pincode: '680001',
      phone: '9400525067',
    ),
    ShieldStore(
      id: 'SHD-KOC',
      name: 'SHIELD Pharmacy Kochi',
      area: 'MG Road',
      city: 'Ernakulam',
      state: 'Kerala',
      pincode: '682011',
      phone: '9400525068',
      hours: 'Open 24 hours',
    ),
    ShieldStore(
      id: 'SHD-TVM',
      name: 'SHIELD Pharmacy Thiruvananthapuram',
      area: 'Pattom',
      city: 'Thiruvananthapuram',
      state: 'Kerala',
      pincode: '695004',
      phone: '9400525069',
    ),
    ShieldStore(
      id: 'SHD-BLR',
      name: 'SHIELD Pharmacy Bengaluru',
      area: 'Indiranagar',
      city: 'Bengaluru',
      state: 'Karnataka',
      pincode: '560038',
      phone: '9400525070',
    ),
    ShieldStore(
      id: 'SHD-MAA',
      name: 'SHIELD Pharmacy Chennai',
      area: 'T. Nagar',
      city: 'Chennai',
      state: 'Tamil Nadu',
      pincode: '600017',
      phone: '9400525071',
    ),
    ShieldStore(
      id: 'SHD-BOM',
      name: 'SHIELD Pharmacy Mumbai',
      area: 'Ghatkopar East',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400079',
      phone: '9400525072',
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
  /// two share, the closer they are — 679322 and 676121 share "67" and are
  /// both in Malappuram, while 679322 and 400079 share nothing. Codes that tie
  /// on that are ordered by plain numeric distance. A backend with real
  /// coordinates replaces this method and nothing else.
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
