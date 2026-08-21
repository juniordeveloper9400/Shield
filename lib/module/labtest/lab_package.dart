// formatRupees lives at the app root now that the wallet needs it too. It is
// re-exported here so callers reaching for it through the lab catalogue —
// where every price in this file is grouped by it — keep working.
export '../../money.dart' show formatRupees;

/// One profile inside a diagnostic package, e.g. "CBC · 24 parameters".
class LabProfile {
  final String emoji;
  final String name;
  final int parameters;

  const LabProfile(this.emoji, this.name, this.parameters);
}

/// A bookable diagnostic package.
class LabPackage {
  final String name;
  final int testCount;
  final int profileCount;
  final String rating;
  final String booked;
  final String reportIn;
  final String price;
  final String mrp;
  final String saved;

  /// Profiles listed directly on the card.
  final List<LabProfile> profiles;

  /// Name of a package this one fully contains, shown as a rolled-up row
  /// instead of repeating every profile.
  final String? inheritsFrom;
  final String? inheritsSummary;

  /// Extras beyond the inherited package, e.g. "+ 2 MORE TESTS · DIABETES".
  final String? extrasLabel;
  final List<LabProfile> extras;

  // ---- Detail-screen fields ----

  /// Who the package is for, e.g. 'For Male & Female'.
  final String forWhom;

  /// Eligible age range, e.g. '5-99 yrs'.
  final String ageRange;

  /// What the patient must do beforehand, e.g. '12 hrs fasting'.
  final String preparation;

  /// What is collected, e.g. 'Blood, Urine'.
  final String sample;

  /// Organs and systems the panel covers, shown as chips.
  final List<String> organs;

  final String about;

  const LabPackage({
    required this.name,
    required this.testCount,
    required this.profileCount,
    required this.rating,
    required this.booked,
    required this.reportIn,
    required this.price,
    required this.mrp,
    required this.saved,
    this.profiles = const [],
    this.inheritsFrom,
    this.inheritsSummary,
    this.extrasLabel,
    this.extras = const [],
    this.forWhom = 'For Male & Female',
    this.ageRange = '5-99 yrs',
    this.preparation = '12 hrs fasting',
    this.sample = 'Blood, Urine',
    this.organs = const [],
    this.about = '',
  });

  /// [price] and [mrp] are written pre-grouped for display; these are the
  /// numbers behind them, which is what a multi-patient booking needs.
  int get priceValue => _toInt(price);

  int get mrpValue => _toInt(mrp);

  /// '46.67% off', matching the way the reference rounds it.
  String get discountLabel {
    if (mrpValue <= 0 || mrpValue <= priceValue) {
      return '';
    }
    final percent = (mrpValue - priceValue) / mrpValue * 100;
    return '${percent.toStringAsFixed(2)}% off';
  }

  static int _toInt(String amount) =>
      int.tryParse(amount.replaceAll(',', '').trim()) ?? 0;
}

/// Published packages and individual tests.
class LabCatalogue {
  const LabCatalogue._();

  static const LabPackage preventivePlus = LabPackage(
    name: 'Preventive Plus',
    testCount: 83,
    profileCount: 8,
    rating: '4.83',
    booked: '12k+ booked',
    reportIn: '15 hr',
    price: '999',
    mrp: '2,498',
    saved: 'Saved ₹333 with coupon code',
    preparation: '10 hrs fasting',
    organs: [
      'Liver',
      'Kidneys',
      'Heart',
      'Thyroid Gland',
      'Blood Vessels',
      'Bones',
    ],
    about:
        'A broad first look at how the body is running: blood counts, liver '
        'and kidney function, cholesterol, thyroid, blood sugar, and the two '
        'vitamins most commonly found short. Suited to a yearly check when '
        'there is nothing specific to investigate.',
    profiles: [
      LabProfile('🩸', 'CBC', 24),
      LabProfile('🫀', 'LFT', 12),
      LabProfile('🧪', 'Urine Routine', 21),
      LabProfile('🫁', 'KFT', 11),
      LabProfile('🥗', 'Lipid Profile', 9),
      LabProfile('🦋', 'Thyroid Profile', 3),
      LabProfile('💊', 'Blood Glucose', 1),
      LabProfile('💊', 'Vitamin B12', 1),
      LabProfile('☀️', 'Vitamin D', 1),
    ],
  );

  static const LabPackage activeLife = LabPackage(
    name: 'Active Life',
    testCount: 85,
    profileCount: 8,
    rating: '4.92',
    booked: '8k+ booked',
    reportIn: '15 hr',
    price: '1,299',
    mrp: '3,248',
    saved: 'Saved ₹433 with coupon code',
    inheritsFrom: 'Everything in Preventive Plus',
    inheritsSummary: 'All 83 tests · 8 profiles',
    extrasLabel: '+ 2 MORE TESTS · DIABETES',
    organs: [
      'Liver',
      'Kidneys',
      'Pancreas',
      'Heart',
      'Blood Vessels',
      'Thyroid Gland',
    ],
    about:
        'Everything in Preventive Plus, plus the two markers that show how '
        'blood sugar has behaved over the past three months rather than on '
        'the morning of the test.',
    extras: [
      LabProfile('🩸', 'HbA1c', 0),
      LabProfile('💠', 'Average blood glucose', 0),
    ],
  );

  static const LabPackage completeCare = LabPackage(
    name: 'Complete Care',
    testCount: 92,
    profileCount: 10,
    rating: '4.88',
    booked: '5k+ booked',
    reportIn: '18 hr',
    price: '1,799',
    mrp: '4,100',
    saved: 'Saved ₹560 with coupon code',
    inheritsFrom: 'Everything in Active Life',
    inheritsSummary: 'All 85 tests · 8 profiles',
    extrasLabel: '+ 7 MORE TESTS · HEART & IRON',
    preparation: '12 hrs fasting',
    sample: 'Blood, Urine',
    organs: [
      'Liver',
      'Kidneys',
      'Pancreas',
      'Heart',
      'Blood Vessels',
      'Thyroid Gland',
      'Bone Marrow',
    ],
    about:
        'Everything in Active Life, with cardiac risk markers and iron '
        'studies added. The fullest panel offered, and the one to choose '
        'when heart risk or anaemia is the reason for testing.',
    extras: [
      LabProfile('🫀', 'Cardiac Risk Markers', 5),
      LabProfile('🧲', 'Iron Studies', 2),
    ],
  );

  static const List<LabPackage> packages = [
    preventivePlus,
    activeLife,
    completeCare,
  ];

  /// Individually bookable profiles listed under the packages.
  static const List<LabProfile> topProfiles = [
    LabProfile('🩸', 'Complete Blood Count', 24),
    LabProfile('🦋', 'Thyroid Profile', 3),
    LabProfile('🥗', 'Lipid Profile', 9),
    LabProfile('🫁', 'Kidney Function Test', 11),
    LabProfile('🫀', 'Liver Function Test', 12),
    LabProfile('☀️', 'Vitamin D', 1),
  ];
}
