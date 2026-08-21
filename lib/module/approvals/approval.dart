import 'package:flutter/foundation.dart';

/// Where a request stands with the member.
enum ApprovalStatus {
  awaiting('Awaiting your approval', 'Awaiting'),
  approved('Approved', 'Approved'),
  declined('Declined', 'Declined');

  /// The full sentence, for anywhere with room for one.
  final String label;

  /// One word, for the chip on the card. The sentence is 22 characters and a
  /// chip carrying it squeezes the order reference off a 320px card.
  final String shortLabel;

  const ApprovalStatus(this.label, this.shortLabel);
}

/// One line the pharmacist is proposing to dispense.
@immutable
class ApprovalItem {
  final String name;
  final String pack;
  final int quantity;

  /// Whole rupees for the whole line, not per unit.
  final int price;

  /// Why this line differs from the prescription — a substitution, a shorter
  /// course, a pack size the shelf actually carries. Empty when it does not.
  final String note;

  const ApprovalItem({
    required this.name,
    required this.pack,
    required this.quantity,
    required this.price,
    this.note = '',
  });

  bool get isChanged => note.isNotEmpty;
}

/// A filled prescription waiting on the member before it is dispensed.
///
/// The pharmacist reads the prescription, prices it, and proposes any
/// substitution. Nothing is dispensed and nothing is charged until the member
/// says yes — which is what this screen is for.
@immutable
class Approval {
  final String id;
  final String orderRef;
  final String patientName;

  /// Plain words rather than a timestamp, matching how the rest of the app
  /// writes dates it cannot yet compute.
  final String raisedOn;

  final List<ApprovalItem> items;

  /// What the pharmacist wants the member to know before deciding.
  final String pharmacistNote;

  final ApprovalStatus status;

  const Approval({
    required this.id,
    required this.orderRef,
    required this.patientName,
    required this.raisedOn,
    required this.items,
    required this.status,
    this.pharmacistNote = '',
  });

  int get total => items.fold(0, (sum, item) => sum + item.price);

  int get itemCount => items.length;

  /// True when any line differs from what was prescribed. Those are the ones
  /// a member has to actually read rather than wave through.
  bool get hasChanges => items.any((item) => item.isChanged);

  bool get isAwaiting => status == ApprovalStatus.awaiting;

  Approval copyWith({ApprovalStatus? status}) {
    return Approval(
      id: id,
      orderRef: orderRef,
      patientName: patientName,
      raisedOn: raisedOn,
      items: items,
      pharmacistNote: pharmacistNote,
      status: status ?? this.status,
    );
  }
}

/// The approvals on the account.
///
/// In memory only; a backend would replace this class wholesale.
class ApprovalService extends ChangeNotifier {
  ApprovalService._();

  static final ApprovalService instance = ApprovalService._();

  static const List<Approval> _seed = [
    Approval(
      id: 'a1',
      orderRef: 'SHD-100517',
      patientName: 'Rahul Nair',
      raisedOn: 'Today, 9:20 AM',
      status: ApprovalStatus.awaiting,
      pharmacistNote:
          'Dolo 650 is out of stock at your store. Calpol 650 is the same '
          'salt and strength, and ₹6 cheaper for the strip.',
      items: [
        ApprovalItem(
          name: 'Calpol 650mg Tablet',
          pack: 'Strip of 15 tablets',
          quantity: 2,
          price: 58,
          note: 'Substituted for Dolo 650mg — same salt',
        ),
        ApprovalItem(
          name: 'Azithral 500mg Tablet',
          pack: 'Strip of 5 tablets',
          quantity: 1,
          price: 104,
        ),
      ],
    ),
    Approval(
      id: 'a2',
      orderRef: 'SHD-100514',
      patientName: 'Asha Nair',
      raisedOn: 'Yesterday, 6:05 PM',
      status: ApprovalStatus.awaiting,
      pharmacistNote:
          'The prescription allows 30 days. We have 21 days in stock and can '
          'deliver the rest on Friday.',
      items: [
        ApprovalItem(
          name: 'Glycomet GP 1 Tablet',
          pack: 'Strip of 15 tablets',
          quantity: 2,
          price: 176,
          note: '21 days now, 9 days to follow on Friday',
        ),
      ],
    ),
    Approval(
      id: 'a3',
      orderRef: 'SHD-100482',
      patientName: 'Rahul Nair',
      raisedOn: '16 Aug 2026',
      status: ApprovalStatus.approved,
      items: [
        ApprovalItem(
          name: 'Shelcal 500 Tablet',
          pack: 'Strip of 15 tablets',
          quantity: 4,
          price: 412,
        ),
      ],
    ),
  ];

  final List<Approval> _approvals = List.of(_seed);

  /// Newest first, which is the order the screen reads them in.
  List<Approval> get approvals => List.unmodifiable(_approvals);

  /// The ones still needing an answer, which is what the screen leads with.
  List<Approval> get awaiting =>
      _approvals.where((approval) => approval.isAwaiting).toList();

  /// Settled either way, kept below the live ones as a record.
  List<Approval> get settled =>
      _approvals.where((approval) => !approval.isAwaiting).toList();

  int get pendingCount => awaiting.length;

  Approval? byId(String id) {
    for (final approval in _approvals) {
      if (approval.id == id) {
        return approval;
      }
    }
    return null;
  }

  void approve(String id) => _settle(id, ApprovalStatus.approved);

  void decline(String id) => _settle(id, ApprovalStatus.declined);

  /// Only an awaiting request moves. Re-answering a settled one would let a
  /// stale screen overwrite a decision the member already made.
  void _settle(String id, ApprovalStatus status) {
    final index = _approvals.indexWhere((approval) => approval.id == id);
    if (index == -1 || !_approvals[index].isAwaiting) {
      return;
    }
    _approvals[index] = _approvals[index].copyWith(status: status);
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _approvals
      ..clear()
      ..addAll(_seed);
    notifyListeners();
  }
}
