import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A doctor bookable at a clinic.
class Doctor {
  final String name;
  final String speciality;
  final String fee;

  const Doctor({
    required this.name,
    required this.speciality,
    required this.fee,
  });

  /// Lettermark shown in place of a photograph, the way [Clinic] shows one in
  /// place of a logo.
  ///
  /// A stock face beside a named, bookable doctor would be a picture of
  /// somebody else, so the tile carries their initials until the clinic
  /// supplies a photograph of its own.
  String get initials {
    final words = name
        .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

/// A clinic or hospital.
class Clinic {
  final String name;
  final String type;
  final String location;
  final String phone;
  final String description;

  /// Lettermark shown in place of a logo asset.
  final String initials;
  final Color tint;

  final bool isVerified;
  final List<String> specialities;
  final List<Doctor> doctors;

  const Clinic({
    required this.name,
    required this.type,
    required this.location,
    required this.phone,
    required this.description,
    required this.initials,
    required this.tint,
    required this.specialities,
    required this.doctors,
    this.isVerified = false,
  });
}

/// Published clinics.
class ClinicDirectory {
  const ClinicDirectory._();

  static const Doctor drAnsar = Doctor(
    name: 'Dr. Ansar',
    speciality: 'Dermatology',
    fee: '400',
  );

  static const Clinic meiodia = Clinic(
    name: 'Meiodia Aesthetic Clinic',
    type: 'Skin, Hair & Aesthetic Clinic',
    location: 'Perinthalmanna',
    phone: '9605558833',
    description:
        'Meiodia Aesthetic Clinic in Perinthalmanna offers dermatology '
        'consultation alongside skin, hair and aesthetic procedures, with '
        'treatment plans built around each patient after an initial '
        'assessment.',
    initials: 'ME',
    tint: AppColors.chipBlueTint,
    isVerified: true,
    specialities: ['Dermatology'],
    doctors: [drAnsar],
  );

  static const List<Clinic> clinics = [meiodia];
}
