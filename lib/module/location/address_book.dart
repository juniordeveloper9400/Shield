import 'package:flutter/foundation.dart';

/// What a saved address is used for.
enum AddressLabel {
  home('Home'),
  work('Work'),
  other('Other');

  final String label;

  const AddressLabel(this.label);
}

/// A delivery address.
@immutable
class Address {
  final String pincode;
  final String house;
  final String area;
  final String landmark;
  final String firstName;
  final String lastName;
  final String phone;
  final AddressLabel label;

  const Address({
    required this.pincode,
    required this.house,
    required this.area,
    required this.firstName,
    required this.phone,
    required this.label,
    this.landmark = '',
    this.lastName = '',
  });

  String get receiver => lastName.isEmpty ? firstName : '$firstName $lastName';

  /// Single-line rendering for lists.
  String get summary {
    final parts = [house, area, if (landmark.isNotEmpty) landmark, pincode];
    return parts.where((part) => part.isNotEmpty).join(', ');
  }
}

/// Saved delivery addresses, and which one is being delivered to.
///
/// Also the single owner of the current delivery location, so the two ways of
/// setting it — a bare pincode from the location sheet, or a full address
/// saved in the form — end up in the same place and every surface showing the
/// location updates from one notification.
///
/// In memory only; a backend would replace this class wholesale.
class AddressBook extends ChangeNotifier {
  AddressBook._();

  static final AddressBook instance = AddressBook._();

  /// Where the app delivers until told otherwise.
  static const String defaultPincode = '400079';

  /// Pincodes the app can name a city for. Anything else is shown as-is.
  static const Map<String, String> knownCities = {
    '400079': 'Mumbai',
    '110001': 'Delhi',
    '560001': 'Bengaluru',
    '600001': 'Chennai',
    '682001': 'Kochi',
    '700001': 'Kolkata',
  };

  /// "400079, Mumbai" when the city is known, otherwise just the pincode.
  static String describePincode(String pincode) {
    final city = knownCities[pincode];
    return city == null ? pincode : '$pincode, $city';
  }

  final List<Address> _addresses = [];

  String _pincode = defaultPincode;
  Address? _deliverTo;

  List<Address> get addresses => List.unmodifiable(_addresses);

  bool get isEmpty => _addresses.isEmpty;

  /// The saved address being delivered to, or null when the location is just
  /// a pincode.
  Address? get deliverTo => _deliverTo;

  String get pincode => _deliverTo?.pincode ?? _pincode;

  /// What the chrome shows: the pincode and the place it belongs to.
  ///
  /// A saved address names its own locality, which beats the city lookup —
  /// "400079, Ghatkopar East" is more use than "400079, Mumbai".
  String get locationLabel {
    final address = _deliverTo;
    if (address != null && address.area.isNotEmpty) {
      return '${address.pincode}, ${address.area}';
    }
    return describePincode(pincode);
  }

  /// Saves an address and starts delivering to it. Saving an address is a
  /// statement about where you want things sent, so it takes effect at once.
  void add(Address address) {
    _addresses.add(address);
    _deliverTo = address;
    notifyListeners();
  }

  /// Sets the location from a bare pincode.
  ///
  /// That is a different place from any saved address, so the saved address
  /// stops being the delivery target rather than silently overriding it.
  void setPincode(String pincode) {
    _pincode = pincode;
    _deliverTo = null;
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _addresses.length) {
      return;
    }
    final removed = _addresses.removeAt(index);
    if (identical(removed, _deliverTo)) {
      _deliverTo = null;
    }
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _addresses.clear();
    _deliverTo = null;
    _pincode = defaultPincode;
    notifyListeners();
  }
}
