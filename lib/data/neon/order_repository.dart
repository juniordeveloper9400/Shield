import 'package:flutter/foundation.dart';

import '../../module/checkout/fulfillment_type.dart';
import 'neon_http.dart';
import 'wallet_repository.dart';

/// The delivery address an order ships to. [label] is already one of the
/// `app.address_label` tokens (`HOME` / `WORK` / `OTHER`).
@immutable
class DeliveryAddressInput {
  final String label;
  final String house;
  final String area;
  final String landmark;
  final String pincode;
  final String city;
  final String state;
  final String firstName;
  final String lastName;
  final String phone;

  const DeliveryAddressInput({
    required this.label,
    required this.house,
    required this.area,
    this.landmark = '',
    required this.pincode,
    this.city = '',
    this.state = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
  });
}

/// A wallet payment to post against an order at the moment it is placed (or,
/// for a "Pay now" bill, against one already on file). Carried as plain
/// values, same as every other `*Input` here, rather than reaching into
/// [WalletRepository] directly from the checkout screen.
@immutable
class WalletDebitInput {
  final String memberPhone;
  final int amount;
  final String label;

  const WalletDebitInput({
    required this.memberPhone,
    required this.amount,
    required this.label,
  });
}

/// A patient a prescription is raised for. [gender] and [relation] are already
/// `app.gender` / `app.patient_relation` tokens. [remoteUuid] is the
/// `app.patient.uuid` when this patient has already been written, so a repeat
/// order updates the same row instead of adding another.
@immutable
class PrescriptionPatientInput {
  final String? remoteUuid;
  final String name;
  final String phone;
  final String address;
  final DateTime dob;
  final String gender;
  final String relation;
  final String abhaId;

  const PrescriptionPatientInput({
    this.remoteUuid,
    required this.name,
    this.phone = '',
    this.address = '',
    required this.dob,
    required this.gender,
    required this.relation,
    this.abhaId = '',
  });
}

/// One medicine line the pharmacy keyed off a prescription, dose as
/// morning / afternoon / night counts.
@immutable
class PrescriptionMedicineInput {
  final String name;
  final String pack;
  final int doseMorning;
  final int doseAfternoon;
  final int doseNight;

  const PrescriptionMedicineInput({
    required this.name,
    this.pack = '',
    this.doseMorning = 0,
    this.doseAfternoon = 0,
    this.doseNight = 0,
  });
}

/// A whole prescription being submitted for fulfilment. [code] is the number
/// the counter files it under (`RX-0004`); [duration] is an
/// `app.medicine_duration` token or null.
///
/// [remoteUuid] is the `app.prescription.uuid` pinned when the script was
/// uploaded, so checkout marks that same row `ORDERED` instead of inserting a
/// second one. Null when the upload never reached the database.
@immutable
class PrescriptionInput {
  final String? remoteUuid;
  final String code;
  final String fileName;
  final String doctor;
  final String? duration;
  final int? customDays;
  final DateTime? recurringFrom;
  final DateTime? recurringUntil;
  final String? notes;
  final PrescriptionPatientInput patient;
  final List<PrescriptionMedicineInput> medicines;

  const PrescriptionInput({
    this.remoteUuid,
    required this.code,
    this.fileName = '',
    this.doctor = '',
    this.duration,
    this.customDays,
    this.recurringFrom,
    this.recurringUntil,
    this.notes,
    required this.patient,
    this.medicines = const [],
  });
}

/// One lab package booked for a number of patients. The package fields are
/// carried so a package the app knows but the backend has never seen can be
/// written on the fly; it is matched on a slug derived from [name].
@immutable
class LabBookingInput {
  final String name;
  final int testCount;
  final int profileCount;
  final String rating;
  final String booked;
  final String reportIn;
  final int unitPrice;
  final int mrp;
  final int patients;
  final String forWhom;
  final String ageRange;
  final String preparation;
  final String sample;
  final String about;

  const LabBookingInput({
    required this.name,
    this.testCount = 0,
    this.profileCount = 0,
    this.rating = '',
    this.booked = '',
    this.reportIn = '',
    required this.unitPrice,
    required this.mrp,
    required this.patients,
    this.forWhom = '',
    this.ageRange = '',
    this.preparation = '',
    this.sample = '',
    this.about = '',
  });
}

/// One line item on a standard order, as [OrderRepository.fetchItems] reads
/// it back — enough for "Items in this order" to show the real product
/// picture rather than naming it with no picture at all.
@immutable
class OrderItem {
  final String name;
  final String pack;
  final int qty;
  final int unitPrice;
  final int mrp;

  /// The product's own catalogue picture (a `data:` URI, the way
  /// `app.product.image` stores one), or null when the line carries no
  /// product (a name that matched none at checkout) or the product has
  /// since lost its picture.
  final String? image;

  const OrderItem({
    required this.name,
    required this.pack,
    required this.qty,
    required this.unitPrice,
    required this.mrp,
    required this.image,
  });
}

/// One prescription submitted into an order, as
/// [OrderRepository.fetchPrescriptions] reads it back — just enough for
/// [PrescriptionUploadedCard] to show the member's own uploaded scan rather
/// than a generic icon standing in for it.
@immutable
class OrderPrescription {
  final String code;

  /// The first page of the member's own uploaded scan (a `data:` URI, from
  /// `app.prescription_image` where `sort = 0`), or null when this
  /// prescription was submitted with no photo — a script phoned in, not an
  /// error case.
  final String? image;
  final String doctor;

  /// An `app.prescription_status` value — `AWAITING_REVIEW` / `READ` /
  /// `ORDERED`.
  final String status;

  const OrderPrescription({
    required this.code,
    required this.image,
    required this.doctor,
    required this.status,
  });
}

/// Writes placed orders, prescription submissions and lab bookings to the
/// `app` schema on Neon.
///
/// Every method is best-effort, the same contract as [MemberRepository]: when
/// the app was built without a `DATABASE_URL` (tests, a build that left
/// `--dart-define-from-file=.env` off) or the network is down, the call is a
/// no-op. A checkout must never fail because the order could not be filed — the
/// in-memory services stay the source of truth the UI reads; this is the
/// write-through.
///
/// Goes over [NeonHttp] (HTTPS on 443) rather than the raw Postgres socket, so
/// it behaves identically in a `--release` build. Neon's `/sql` endpoint runs
/// one statement per request with no client transaction, so each method writes
/// its rows in dependency order and every child insert is a single set-based
/// statement (`unnest`). The signed-in user is resolved by phone against
/// `app.users`, which sign-in / registration has already upserted; a minimal
/// row is inserted when a checkout beats that write-through.
class OrderRepository {
  const OrderRepository._();

  static const OrderRepository instance = OrderRepository._();

  /// Whether a write would actually reach a database.
  bool get isAvailable => NeonHttp.isConfigured;

  /// Files a prescription checkout: for each prescription an `app.patient`
  /// (reused when it already exists), an `app.prescription` with its
  /// `app.prescription_medicine` lines, and a single `app."order"` of kind
  /// `PRESCRIPTION` that every `app.prescription_order` row links to.
  ///
  /// Nothing is priced here — `mrp_total` / `paid_total` stay zero until the
  /// pharmacist bills it — so the order carries only its line count.
  Future<void> savePrescriptionOrder({
    required String phone,
    String? name,
    required String orderCode,
    required List<PrescriptionInput> prescriptions,
    String? storeCode,
    String? paymentMethodCode,
    DeliveryAddressInput? address,
    required FulfillmentType fulfillmentType,
    WalletDebitInput? walletDebit,
  }) async {
    await _guard('savePrescriptionOrder', () async {
      if (prescriptions.isEmpty) {
        return;
      }
      final memberId = await _ensureMember(phone, name);
      if (memberId == null) {
        return;
      }
      final addressId =
          address == null ? null : await _upsertAddress(memberId, address);

      final medicineCount = prescriptions.fold<int>(
        0,
        (sum, rx) => sum + rx.medicines.length,
      );
      final orderId = await _upsertOrderShell(
        memberId: memberId,
        code: orderCode,
        kind: 'PRESCRIPTION',
        itemCount: medicineCount == 0 ? prescriptions.length : medicineCount,
        addressId: addressId,
        storeCode: storeCode,
        paymentMethodCode: paymentMethodCode,
        fulfillmentType: fulfillmentType,
        // Written unpaid; marked paid below only once the debit has succeeded.
        paid: false,
      );
      if (orderId != null) {
        await _seedTrackSteps(orderId, _prescriptionStages);
        if (walletDebit != null) {
          final debited = await WalletRepository.instance.recordSpend(
            memberPhone: walletDebit.memberPhone,
            amount: walletDebit.amount,
            label: walletDebit.label,
            orderId: orderId,
          );
          if (debited) {
            await NeonHttp.instance.query(
              '''
                UPDATE app."order"
                SET payment_status = 'PAID'::app.order_payment_status, paid_at = now()
                WHERE id = \$1
              ''',
              [orderId],
            );
          } else {
            // Same as a standard order: a refused debit must not file a paid
            // order with no wallet entry behind it.
            await NeonHttp.instance.query(
              '''
                UPDATE app."order"
                SET status = 'CANCELLED'::app.order_status
                WHERE id = \$1
              ''',
              [orderId],
            );
            NeonHttp.log(
              'OrderRepository.savePrescriptionOrder: wallet debit refused, order cancelled',
            );
            return;
          }
        }
      }
      final storeId = await _storeId(storeCode);

      var freshSeq = 0;
      for (final rx in prescriptions) {
        final patientId = await _upsertPatient(memberId, rx.patient);
        if (patientId == null) {
          continue;
        }

        // Reuse the row the upload already wrote — by its uuid, else the
        // member's most recent non-ordered script with this file name — so
        // checkout marks that row ORDERED rather than filing a duplicate.
        int? prescriptionId = await _resolvePrescriptionId(memberId, rx);
        if (prescriptionId == null) {
          // No uploaded row (the upload write never landed): file a fresh one
          // under a collision-safe code, not the session-counter RX-000x.
          final freshCode = 'RX-'
              '${DateTime.now().microsecondsSinceEpoch.remainder(100000000)}'
              '${freshSeq++}';
          final row = await NeonHttp.instance.query(
            '''
              INSERT INTO app.prescription (
                member_id, patient_id, store_id, code, file_name, doctor,
                duration, custom_days, recurring_from, recurring_until, status
              )
              VALUES (
                \$1, \$2,
                (SELECT id FROM app.shield_store WHERE code = \$3),
                \$4, \$5, \$6,
                \$7::app.medicine_duration, \$8,
                \$9::date, \$10::date, 'ORDERED'
              )
              RETURNING id
            ''',
            [
              memberId,
              patientId,
              storeCode,
              freshCode,
              rx.fileName,
              rx.doctor,
              rx.duration,
              rx.customDays,
              _isoDate(rx.recurringFrom),
              _isoDate(rx.recurringUntil),
            ],
          );
          prescriptionId = _rowId(row);
        } else {
          await NeonHttp.instance.query(
            '''
              UPDATE app.prescription SET
                patient_id  = \$2,
                store_id    = COALESCE(store_id,
                              (SELECT id FROM app.shield_store WHERE code = \$3)),
                doctor      = CASE WHEN \$4 <> '' THEN \$4 ELSE doctor END,
                duration    = COALESCE(\$5::app.medicine_duration, duration),
                custom_days = COALESCE(\$6, custom_days),
                status      = 'ORDERED',
                updated_at  = now()
              WHERE id = \$1
            ''',
            [
              prescriptionId,
              patientId,
              storeCode,
              rx.doctor,
              rx.duration,
              rx.customDays,
            ],
          );
        }
        if (prescriptionId == null) {
          continue;
        }

        // Re-key the lines only when the caller actually sent some. The
        // order-first flow places the order with no medicines and lets the
        // pharmacist build the intake card in the console afterwards — a blind
        // DELETE here would wipe that card if checkout were ever re-run.
        if (rx.medicines.isNotEmpty) {
          await NeonHttp.instance.query(
            'DELETE FROM app.prescription_medicine WHERE prescription_id = \$1',
            [prescriptionId],
          );
          await _insertPrescriptionMedicines(prescriptionId, rx.medicines);
        }

        await NeonHttp.instance.query(
          '''
            INSERT INTO app.prescription_order
              (prescription_id, order_id, store_id, status, customer_notes)
            VALUES (\$1, \$2, \$3, 'SUBMITTED', \$4)
          ''',
          [prescriptionId, orderId, storeId, rx.notes],
        );
      }
      return;
    });
  }

  /// Settles a priced-but-unpaid order (a prescription bill, most often) off
  /// the member's wallet: debits the wallet and posts the `SPEND` ledger line
  /// via [WalletRepository.recordSpend], then flips this order's own
  /// `payment_status` and, when it carries one, its `app.bill.status` too.
  ///
  /// [orderCode] rather than a database id — the app only ever carries the
  /// order's own code ([Purchase.id]), so the row is found by it the same way
  /// [_upsertOrderShell] does. Returns false, writing nothing further, when
  /// the order cannot be found or the wallet debit itself is refused.
  Future<bool> markOrderPaidByWallet({
    required String orderCode,
    required int amount,
    required String memberPhone,
  }) async {
    if (!NeonHttp.isConfigured) {
      return false;
    }
    try {
      final found = await NeonHttp.instance.query(
        'SELECT id FROM app."order" WHERE code = \$1 LIMIT 1',
        [orderCode],
      );
      final orderId = _rowId(found);
      if (orderId == null) {
        return false;
      }

      final debited = await WalletRepository.instance.recordSpend(
        memberPhone: memberPhone,
        amount: amount,
        label: 'Order $orderCode',
        orderId: orderId,
      );
      if (!debited) {
        return false;
      }

      await NeonHttp.instance.query(
        '''
          UPDATE app."order"
          SET payment_status = 'PAID'::app.order_payment_status, paid_at = now()
          WHERE id = \$1
        ''',
        [orderId],
      );
      await NeonHttp.instance.query(
        '''
          UPDATE app.bill
          SET status = 'PAID'::app.order_payment_status, paid_at = now()
          WHERE order_id = \$1
        ''',
        [orderId],
      );
      return true;
    } catch (error) {
      NeonHttp.log('OrderRepository.markOrderPaidByWallet failed', error: error);
      return false;
    }
  }

  // --- shared helpers ------------------------------------------------------

  // Nothing reads `app.order_track_step` back — `OrderTrack` derives the
  // graph straight off the order's own columns (see its own doc) — but the
  // row is still seeded at placement, so its titles are kept matching
  // [OrderStage]'s wording rather than left showing the tracker's old
  // delivery-logistics stages.
  static const List<String> _prescriptionStages = [
    'Pending',
    'Processed',
    'Billing',
    'Completed',
  ];

  Future<int?> _memberId(String phone) async {
    final rows = await NeonHttp.instance.query(
      'SELECT id FROM app.users '
      'WHERE phone = \$1 AND deleted_at IS NULL LIMIT 1',
      [phone],
    );
    return _rowId(rows);
  }

  /// The `app.users` row id for [phone], inserting a minimal row (phone + name)
  /// when sign-in has not written one yet — a checkout must not be lost to a
  /// first-run race between the sign-in write-through and the order. Null only
  /// when there is no row and no [name] to create one with.
  Future<int?> _ensureMember(String phone, String? name) async {
    final existing = await _memberId(phone);
    if (existing != null) {
      return existing;
    }
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final rows = await NeonHttp.instance.query(
      '''
        INSERT INTO app.users (phone, name)
        VALUES (\$1, \$2)
        ON CONFLICT (phone) DO UPDATE SET updated_at = now()
        RETURNING id
      ''',
      [phone, trimmed],
    );
    return _rowId(rows);
  }

  Future<int?> _storeId(String? code) async {
    if (code == null || code.isEmpty) {
      return null;
    }
    final rows = await NeonHttp.instance.query(
      'SELECT id FROM app.shield_store WHERE code = \$1 LIMIT 1',
      [code],
    );
    return _rowId(rows);
  }

  /// Finds the member's matching address or writes a new one, returning its id.
  /// Matched on the house / area / pincode triple so a member who checks out
  /// repeatedly to the same place does not accumulate duplicate rows.
  Future<int?> _upsertAddress(int memberId, DeliveryAddressInput a) async {
    final existing = await NeonHttp.instance.query(
      '''
        SELECT id FROM app.member_address
        WHERE member_id = \$1
          AND lower(house) = lower(\$2)
          AND lower(area) = lower(\$3)
          AND pincode = \$4
          AND deleted_at IS NULL
        LIMIT 1
      ''',
      [memberId, a.house, a.area, a.pincode],
    );
    if (existing.isNotEmpty) {
      return _rowId(existing);
    }
    final inserted = await NeonHttp.instance.query(
      '''
        INSERT INTO app.member_address (
          member_id, label, house, area, landmark, pincode, city, state,
          first_name, last_name, phone
        )
        VALUES (
          \$1, \$2::app.address_label, \$3, \$4, \$5,
          \$6, \$7, \$8, \$9, \$10, \$11
        )
        RETURNING id
      ''',
      [
        memberId,
        a.label,
        a.house,
        a.area,
        a.landmark,
        a.pincode,
        a.city.isEmpty ? null : a.city,
        a.state.isEmpty ? null : a.state,
        a.firstName,
        a.lastName,
        a.phone,
      ],
    );
    return _rowId(inserted);
  }

  /// Resolves the patient to a row id: by `uuid` when the app carries one,
  /// then by (member, name, dob), inserting only when neither matched.
  Future<int?> _upsertPatient(int memberId, PrescriptionPatientInput p) async {
    final uuid = p.remoteUuid;
    if (uuid != null && uuid.isNotEmpty) {
      final byUuid = await NeonHttp.instance.query(
        'SELECT id FROM app.patient WHERE uuid = \$1::uuid LIMIT 1',
        [uuid],
      );
      if (byUuid.isNotEmpty) {
        return _rowId(byUuid);
      }
    }
    final byIdentity = await NeonHttp.instance.query(
      '''
        SELECT id FROM app.patient
        WHERE member_id = \$1
          AND lower(name) = lower(\$2)
          AND dob = \$3::date
          AND deleted_at IS NULL
        LIMIT 1
      ''',
      [memberId, p.name, _isoDate(p.dob)],
    );
    if (byIdentity.isNotEmpty) {
      return _rowId(byIdentity);
    }
    final inserted = await NeonHttp.instance.query(
      '''
        INSERT INTO app.patient
          (member_id, name, phone, address, dob, gender, abha_id, relation)
        VALUES (
          \$1, \$2, \$3, \$4, \$5::date,
          \$6::app.gender, \$7, \$8::app.patient_relation
        )
        RETURNING id
      ''',
      [
        memberId,
        p.name,
        p.phone,
        p.address,
        _isoDate(p.dob),
        p.gender,
        p.abhaId,
        p.relation,
      ],
    );
    return _rowId(inserted);
  }

  /// The `app.prescription` row an uploaded script already has, or null when
  /// there is none to reuse: matched by the pinned `uuid` first, then by the
  /// member's most recent not-yet-ordered script with the same file name.
  Future<int?> _resolvePrescriptionId(int memberId, PrescriptionInput rx) async {
    final uuid = rx.remoteUuid;
    if (uuid != null && uuid.isNotEmpty) {
      final byUuid = await NeonHttp.instance.query(
        'SELECT id FROM app.prescription '
        'WHERE uuid = \$1::uuid AND deleted_at IS NULL',
        [uuid],
      );
      if (byUuid.isNotEmpty) {
        return _rowId(byUuid);
      }
    }
    if (rx.fileName.isEmpty) {
      return null;
    }
    final byFile = await NeonHttp.instance.query(
      '''
        SELECT id FROM app.prescription
        WHERE member_id = \$1 AND file_name = \$2
          AND status <> 'ORDERED' AND deleted_at IS NULL
        ORDER BY created_at DESC
        LIMIT 1
      ''',
      [memberId, rx.fileName],
    );
    return _rowId(byFile);
  }

  /// Inserts the `app."order"` shell shared by the prescription flow, or finds
  /// the existing one when the code has already been used. Returns null only if
  /// the row can neither be inserted nor found.
  Future<int?> _upsertOrderShell({
    required int memberId,
    required String code,
    required String kind,
    required int itemCount,
    int? addressId,
    String? storeCode,
    String? paymentMethodCode,
    required FulfillmentType fulfillmentType,
    bool paid = false,
  }) async {
    final inserted = await NeonHttp.instance.query(
      '''
        INSERT INTO app."order" (
          member_id, code, kind, status, item_count,
          mrp_total, paid_total, delivery_address_id, store_id, payment_method_id,
          fulfillment_type, payment_status, paid_at
        )
        VALUES (
          \$1, \$2, \$3::app.order_kind, 'PROCESSING', \$4,
          0, 0, \$5,
          (SELECT id FROM app.shield_store WHERE code = \$6),
          (SELECT id FROM app.payment_method WHERE code = \$7),
          \$8::app.fulfillment_type,
          \$9::app.order_payment_status,
          CASE WHEN \$10 THEN now() ELSE NULL END
        )
        ON CONFLICT (code) DO NOTHING
        RETURNING id
      ''',
      [
        memberId,
        code,
        kind,
        itemCount,
        addressId,
        storeCode,
        paymentMethodCode,
        fulfillmentType == FulfillmentType.storePickup
            ? 'STORE_PICKUP'
            : 'HOME_DELIVERY',
        paid ? 'PAID' : 'PENDING',
        paid,
      ],
    );
    if (inserted.isNotEmpty) {
      return _rowId(inserted);
    }
    final found = await NeonHttp.instance.query(
      'SELECT id FROM app."order" WHERE code = \$1 LIMIT 1',
      [code],
    );
    return _rowId(found);
  }

  Future<void> _insertPrescriptionMedicines(
    int prescriptionId,
    List<PrescriptionMedicineInput> medicines,
  ) async {
    if (medicines.isEmpty) {
      return;
    }
    await NeonHttp.instance.query(
      '''
        INSERT INTO app.prescription_medicine (
          prescription_id, sort, name, pack,
          dose_morning, dose_afternoon, dose_night, product_id
        )
        SELECT
          \$1, m.sort, m.name, m.pack, m.morning, m.afternoon, m.night,
          (SELECT id FROM app.product WHERE lower(name) = lower(m.name) LIMIT 1)
        FROM unnest(
          \$2::int[], \$3::text[], \$4::text[],
          \$5::int[], \$6::int[], \$7::int[]
        ) AS m(sort, name, pack, morning, afternoon, night)
      ''',
      [
        prescriptionId,
        [for (var i = 0; i < medicines.length; i++) i],
        [for (final m in medicines) m.name],
        [for (final m in medicines) m.pack],
        [for (final m in medicines) m.doseMorning],
        [for (final m in medicines) m.doseAfternoon],
        [for (final m in medicines) m.doseNight],
      ],
    );
  }

  /// Seeds the track graph at placement: the first stage done now, the second
  /// current, the rest still ahead — the same shape [OrderTrack] derives for a
  /// freshly placed order.
  Future<void> _seedTrackSteps(int orderId, List<String> titles) async {
    if (titles.isEmpty) {
      return;
    }
    final states = [
      for (var i = 0; i < titles.length; i++)
        if (i == 0) 'DONE' else if (i == 1) 'CURRENT' else 'UPCOMING',
    ];
    await NeonHttp.instance.query(
      '''
        INSERT INTO app.order_track_step (order_id, sort, title, state, occurred_at)
        SELECT
          \$1, t.sort, t.title, t.state::app.track_state,
          CASE WHEN t.sort = 0 THEN now() ELSE NULL END
        FROM unnest(\$2::int[], \$3::text[], \$4::text[]) AS t(sort, title, state)
      ''',
      [
        orderId,
        [for (var i = 0; i < titles.length; i++) i],
        titles,
        states,
      ],
    );
  }

  /// Runs [body], swallowing everything — a missing `DATABASE_URL`, a network
  /// error, a SQL error — the same way [MemberRepository] does. A failed write
  /// is logged, never thrown.
  Future<void> _guard(String label, Future<void> Function() body) async {
    if (!NeonHttp.isConfigured) {
      return;
    }
    try {
      await body();
    } catch (error) {
      NeonHttp.log('OrderRepository.$label failed', error: error);
    }
  }

  /// The `id` of the first returned row as an int, or null when there is none.
  /// Neon's `/sql` endpoint returns every value as text, so the id comes back
  /// as a string.
  static int? _rowId(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return null;
    }
    final value = rows.first['id'] ?? rows.first.values.firstOrNull;
    if (value == null) {
      return null;
    }
    return value is int ? value : int.tryParse(value.toString());
  }

  /// `2026-08-31` — an unambiguous value for a `date` column, or null.
  static String? _isoDate(DateTime? date) {
    if (date == null) {
      return null;
    }
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
