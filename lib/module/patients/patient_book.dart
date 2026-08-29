import 'package:flutter/foundation.dart';

import '../../dates.dart';

/// How a patient is related to the account holder.
enum PatientRelation {
  self('Self'),
  spouse('Spouse'),
  child('Child'),
  parent('Parent'),
  other('Other');

  final String label;

  const PatientRelation(this.label);
}

enum PatientGender {
  male('Male'),
  female('Female'),
  other('Other');

  final String label;

  const PatientGender(this.label);
}

/// Someone an order or a test can be raised for.
@immutable
class Patient {
  final String id;
  final String name;

  /// Ten digits. Reports and delivery updates for this patient go here, which
  /// is why it is asked for even when the account holder is the patient.
  final String phone;

  /// Delivery and visit address for this patient.
  final String address;

  /// Held as a date rather than a number of years, because an age recorded
  /// once is wrong from the next birthday onwards — and a lab range is read
  /// against the age on the day of the test, not the day of the entry.
  final DateTime dob;

  final PatientGender gender;

  /// The 14-digit ABHA number, digits only, or empty when the patient has
  /// none. Optional by design: an account without one must still be usable.
  final String abhaId;

  final PatientRelation relation;

  const Patient({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    required this.dob,
    required this.gender,
    required this.relation,
    this.abhaId = '',
  });

  /// Whole years today, derived rather than stored.
  int get age => ageInYears(dob);

  /// "32 yrs · Female · Spouse" — the line every list row shows.
  String get summary => '$ageLine · ${gender.label} · ${relation.label}';

  /// "32 yrs" — the same wording the form's date field prints back.
  String get ageLine => ageLabel(dob);

  String get dobLabel => formatDate(dob);

  bool get hasAbha => abhaId.isNotEmpty;

  /// `12-3456-7890-1234`, the form an ABHA number is printed in.
  String get abhaLabel => formatAbha(abhaId);

  /// Groups [digits] the way ABHA numbers are written: 2-4-4-4.
  static String formatAbha(String digits) {
    const groups = [2, 4, 4, 4];
    final parts = <String>[];
    var index = 0;
    for (final size in groups) {
      if (index >= digits.length) {
        break;
      }
      final end = index + size > digits.length ? digits.length : index + size;
      parts.add(digits.substring(index, end));
      index = end;
    }
    return parts.join('-');
  }

  Patient copyWith({
    String? name,
    String? phone,
    String? address,
    DateTime? dob,
    PatientGender? gender,
    String? abhaId,
    PatientRelation? relation,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      abhaId: abhaId ?? this.abhaId,
      relation: relation ?? this.relation,
    );
  }
}

/// The people on the account.
///
/// A household orders for more than one person, and both a prescription and a
/// diagnostic booking have to say who they are for. Keeping that list in one
/// place means the prescription flow and the account screen can never show
/// different sets of people.
///
/// In memory only; a backend would replace this class wholesale.
class PatientBook extends ChangeNotifier {
  PatientBook._();

  static final PatientBook instance = PatientBook._();

  final List<Patient> _patients = [];

  int _nextId = 1;

  List<Patient> get patients => List.unmodifiable(_patients);

  bool get isEmpty => _patients.isEmpty;

  int get length => _patients.length;

  Patient? byId(String id) {
    for (final patient in _patients) {
      if (patient.id == id) {
        return patient;
      }
    }
    return null;
  }

  /// Adds a patient and returns the stored record, id included.
  Patient add({
    required String name,
    required String phone,
    String address = '',
    required DateTime dob,
    required PatientGender gender,
    required PatientRelation relation,
    String abhaId = '',
  }) {
    final patient = Patient(
      id: 'p${_nextId++}',
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      dob: dob,
      gender: gender,
      // Stored as digits so a number typed with or without its grouping
      // dashes is the same number.
      abhaId: abhaId.replaceAll(RegExp(r'\D'), ''),
      relation: relation,
    );
    _patients.add(patient);
    notifyListeners();
    return patient;
  }

  /// Replaces the record with the same id. A no-op when the id is unknown,
  /// rather than silently appending a duplicate.
  void update(Patient patient) {
    final index = _patients.indexWhere((entry) => entry.id == patient.id);
    if (index == -1) {
      return;
    }
    _patients[index] = patient;
    notifyListeners();
  }

  void remove(String id) {
    _patients.removeWhere((patient) => patient.id == id);
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _patients.clear();
    _nextId = 1;
    notifyListeners();
  }
}
