import 'package:flutter/foundation.dart';

/// A dietitian a member can book a consultation with.
@immutable
class Dietitian {
  final String name;
  final String qualification;

  /// What they are consulted for. Drawn as chips on the card.
  final List<String> focus;

  final int experienceYears;
  final List<String> languages;

  /// Whole rupees for one consultation.
  final int fee;

  /// Plain words rather than a timestamp: a slot the app cannot actually book
  /// should not pretend to be a calendar entry.
  final String nextSlot;

  final String initials;

  const Dietitian({
    required this.name,
    required this.qualification,
    required this.focus,
    required this.experienceYears,
    required this.languages,
    required this.fee,
    required this.nextSlot,
    required this.initials,
  });

  /// "8 yrs · Malayalam, English"
  String get summary => '$experienceYears yrs · ${languages.join(', ')}';
}

/// The panel a member can book from.
class DietitianDirectory {
  const DietitianDirectory._();

  /// What every consultation includes, whoever it is with. Stated once above
  /// the list rather than repeated on each card.
  static const List<String> included = [
    'A diet plan written for your condition and your kitchen',
    'A follow-up call after two weeks, at no extra cost',
    'Notes shared with the pharmacist filling your prescription',
  ];

  static const List<Dietitian> all = [
    Dietitian(
      name: 'Dr. Anjali Menon',
      qualification: 'PhD Clinical Nutrition, RD',
      focus: ['Diabetes', 'Thyroid', 'PCOS'],
      experienceYears: 12,
      languages: ['Malayalam', 'English'],
      fee: 400,
      nextSlot: 'Today, 4:00 PM',
      initials: 'AM',
    ),
    Dietitian(
      name: 'Fathima Rasheed',
      qualification: 'MSc Food & Nutrition, RD',
      focus: ['Weight management', 'Pregnancy', 'Child nutrition'],
      experienceYears: 8,
      languages: ['Malayalam', 'English', 'Tamil'],
      fee: 300,
      nextSlot: 'Tomorrow, 10:30 AM',
      initials: 'FR',
    ),
    Dietitian(
      name: 'Vishnu Prasad',
      qualification: 'MSc Dietetics',
      focus: ['Heart health', 'Cholesterol', 'Sports nutrition'],
      experienceYears: 6,
      languages: ['Malayalam', 'English', 'Hindi'],
      fee: 250,
      nextSlot: 'Tomorrow, 6:00 PM',
      initials: 'VP',
    ),
    Dietitian(
      name: 'Dr. Sreelakshmi Nair',
      qualification: 'MD Ayurveda, Diploma in Nutrition',
      focus: ['Digestive health', 'Post-surgery recovery'],
      experienceYears: 15,
      languages: ['Malayalam', 'English'],
      fee: 500,
      nextSlot: 'Thu, 11:00 AM',
      initials: 'SN',
    ),
  ];

  /// Everyone whose name, focus or qualification matches [query]. An empty
  /// query returns the whole panel rather than nothing.
  static List<Dietitian> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return all;
    }
    return all
        .where(
          (dietitian) =>
              dietitian.name.toLowerCase().contains(needle) ||
              dietitian.qualification.toLowerCase().contains(needle) ||
              dietitian.focus.any(
                (area) => area.toLowerCase().contains(needle),
              ),
        )
        .toList();
  }
}
