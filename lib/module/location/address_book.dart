import 'package:flutter/foundation.dart';

import '../../data/neon/order_repository.dart';

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
  /// Local identity — `'a1'`, `'a2'`, … for one [AddressBook.add] has
  /// assigned, or `'remote-<uuid>'` for one read back from Neon (see
  /// [AddressRepository]). Empty for an address built by a form before it has
  /// been handed to the book; every address actually sitting in [AddressBook]
  /// has a non-empty one. It is what an edit or a removal is addressed to —
  /// values can repeat (an address edited to match another), so they cannot
  /// stand in for identity themselves.
  final String id;

  final String pincode;
  final String house;
  final String area;
  final String landmark;
  final String firstName;
  final String lastName;
  final String phone;
  final AddressLabel label;

  /// The patient this address was captured for, when it came off the
  /// patient form rather than the standalone address form — null for an
  /// address added any other way. Lets [AddressBook.upsertForPatient] find
  /// and replace the one address that belongs to a given patient instead of
  /// piling up a fresh entry every time their details are edited.
  final String? patientId;

  /// The `uuid` of this address's row in `app.member_address` on Neon, once
  /// one has been written. Null while the record has only ever lived in
  /// memory — the same convention as `Patient.remoteId`.
  final String? remoteId;

  const Address({
    this.id = '',
    required this.pincode,
    required this.house,
    required this.area,
    required this.firstName,
    required this.phone,
    required this.label,
    this.landmark = '',
    this.lastName = '',
    this.patientId,
    this.remoteId,
  });

  String get receiver => lastName.isEmpty ? firstName : '$firstName $lastName';

  Address copyWith({
    String? id,
    String? pincode,
    String? house,
    String? area,
    String? landmark,
    String? firstName,
    String? lastName,
    String? phone,
    AddressLabel? label,
    String? patientId,
    String? remoteId,
  }) {
    return Address(
      id: id ?? this.id,
      pincode: pincode ?? this.pincode,
      house: house ?? this.house,
      area: area ?? this.area,
      landmark: landmark ?? this.landmark,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      label: label ?? this.label,
      patientId: patientId ?? this.patientId,
      remoteId: remoteId ?? this.remoteId,
    );
  }

  /// This address as the plain-values shape [OrderRepository] persists. The
  /// [label] enum name maps straight onto the `app.address_label` tokens
  /// (`home` -> `HOME`).
  DeliveryAddressInput toDeliveryInput() => DeliveryAddressInput(
        label: label.name.toUpperCase(),
        house: house,
        area: area,
        landmark: landmark,
        pincode: pincode,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

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

  int _nextId = 1;

  String _pincode = defaultPincode;
  Address? _deliverTo;

  List<Address> get addresses => List.unmodifiable(_addresses);

  bool get isEmpty => _addresses.isEmpty;

  /// The address captured for [patientId] on their own patient form, if any.
  Address? forPatient(String patientId) {
    for (final address in _addresses) {
      if (address.patientId == patientId) {
        return address;
      }
    }
    return null;
  }

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
  ///
  /// Assigns a stable local [Address.id] first when [address] does not
  /// already carry one — every address a form builds arrives without one.
  /// Returns the stored record, id included, so the caller (and anything it
  /// hands the record on to, such as a "delivering here" identity check) is
  /// working with the same instance the book now holds.
  Address add(Address address) {
    final stored =
        address.id.isEmpty ? address.copyWith(id: 'a${_nextId++}') : address;
    _addresses.add(stored);
    _deliverTo = stored;
    notifyListeners();
    return stored;
  }

  /// Replaces the record with the same [Address.id] — an edit from the
  /// address form or the management screen. A no-op when the id is unknown,
  /// rather than silently appending a duplicate.
  void update(Address address) {
    final index = _addresses.indexWhere((a) => a.id == address.id);
    if (index == -1) {
      return;
    }
    final wasDeliverTo = identical(_addresses[index], _deliverTo);
    _addresses[index] = address;
    if (wasDeliverTo) {
      _deliverTo = address;
    }
    notifyListeners();
  }

  /// Starts delivering to an address already on file — picking one on the
  /// "Select address" list, rather than saving a new one.
  void select(Address address) {
    _deliverTo = address;
    notifyListeners();
  }

  /// Saves the one address that belongs to [patientId]: replaces it in place
  /// if the patient form already put one on file, otherwise adds it as a new
  /// entry. Editing a patient's details again and again is meant to keep
  /// updating this same address, not pile up a fresh one on every save.
  ///
  /// Unlike [add], this does not start delivering to it — it only makes the
  /// address available to pick on the "Select address" list, which is a
  /// choice the member still makes for themselves.
  void upsertForPatient(String patientId, Address address) {
    final index = _addresses.indexWhere((a) => a.patientId == patientId);
    if (index == -1) {
      _addresses.add(
        address.id.isEmpty ? address.copyWith(id: 'a${_nextId++}') : address,
      );
    } else {
      final previous = _addresses[index];
      // Carries the previous entry's identity forward — the id an edit is
      // addressed to, and the remote row a fresh save with no id of its own
      // would otherwise duplicate rather than update.
      final replaced = address.copyWith(
        id: previous.id.isEmpty ? 'a${_nextId++}' : previous.id,
        remoteId: address.remoteId ?? previous.remoteId,
      );
      _addresses[index] = replaced;
      // The old instance may still be the delivery target — carry that over
      // to its replacement rather than leaving deliverTo pointing at an
      // address no longer on the list.
      if (identical(previous, _deliverTo)) {
        _deliverTo = replaced;
      }
    }
    notifyListeners();
  }

  /// Pins the backend row's [Address.remoteId] onto the in-memory address
  /// once the write returns. A no-op when [id] is unknown (the address was
  /// removed again before the round trip finished).
  void attachRemoteId(String id, String remoteId) {
    final index = _addresses.indexWhere((a) => a.id == id);
    if (index == -1) {
      return;
    }
    final updated = _addresses[index].copyWith(remoteId: remoteId);
    final wasDeliverTo = identical(_addresses[index], _deliverTo);
    _addresses[index] = updated;
    if (wasDeliverTo) {
      _deliverTo = updated;
    }
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

  /// Swaps in the account's addresses as read back from `app.member_address`
  /// on Neon, so a fresh install (or a second device) shows the addresses
  /// already on the account. Called after sign-in and at launch, the same
  /// way `PatientBook.replaceRemote` seeds the saved-patients list.
  ///
  /// Two addresses with the same [Address.patientId] are the same address by
  /// definition — a patient's own address is meant to be replaced in place,
  /// never duplicated. Otherwise they are the same when the house, area and
  /// pincode all match. Any address added on this device that has not synced
  /// yet (no [Address.remoteId]) is kept, unless [remote] already has the
  /// same one — then the remote copy wins so there is no duplicate.
  void replaceRemote(List<Address> remote) {
    bool sameAddress(Address a, Address b) {
      if (a.patientId != null && b.patientId != null) {
        return a.patientId == b.patientId;
      }
      return a.house.trim().toLowerCase() == b.house.trim().toLowerCase() &&
          a.area.trim().toLowerCase() == b.area.trim().toLowerCase() &&
          a.pincode == b.pincode;
    }

    final deduped = <Address>[];
    for (final r in remote) {
      if (!deduped.any((seen) => sameAddress(seen, r))) {
        deduped.add(r);
      }
    }

    final keptLocal = _addresses
        .where(
          (local) =>
              local.remoteId == null &&
              !deduped.any((r) => sameAddress(local, r)),
        )
        .toList();

    final merged = [...deduped, ...keptLocal];

    // `deliverTo` may be one of the entries just superseded by its
    // authoritative remote copy — repoint it to that copy rather than leave
    // it referencing an instance no longer in the list.
    final current = _deliverTo;
    Address? nextDeliverTo;
    if (current != null) {
      for (final a in merged) {
        if (identical(a, current) || sameAddress(a, current)) {
          nextDeliverTo = a;
          break;
        }
      }
    }

    _addresses
      ..clear()
      ..addAll(merged);
    _deliverTo = nextDeliverTo;
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

  /// Removes the address with [id] — what the management screen's delete
  /// button is addressed to, since a list position shifts under it as other
  /// entries come and go.
  void remove(String id) {
    final index = _addresses.indexWhere((a) => a.id == id);
    if (index == -1) {
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
    _nextId = 1;
    notifyListeners();
  }
}
