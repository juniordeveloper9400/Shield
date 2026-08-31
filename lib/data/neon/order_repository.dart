import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import 'neon_database.dart';

/// One line of a placed order — a product name, how it is sold, the two prices
/// and the quantity. Carried as plain values so the call site does not have to
/// hand the data layer a cart type.
@immutable
class OrderLineInput {
  final String name;
  final String pack;
  final double unitPrice;
  final double mrp;
  final int qty;

  const OrderLineInput({
    required this.name,
    required this.pack,
    required this.unitPrice,
    required this.mrp,
    required this.qty,
  });
}

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

/// The payment-receipt claim submitted with a standard order. The file bytes
/// are not stored here — only what a person settling the transfer needs to
/// match it: who paid, the bank reference, the amount and the file name.
@immutable
class OrderReceiptInput {
  final String? payerName;
  final String? reference;
  final double? amount;
  final String? fileName;

  const OrderReceiptInput({
    this.payerName,
    this.reference,
    this.amount,
    this.fileName,
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
@immutable
class PrescriptionInput {
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

/// Writes placed orders, prescription submissions and lab bookings to the
/// `app` schema on Neon.
///
/// Every method is best-effort, the same contract as [MemberRepository]: when
/// the app was built without a `DATABASE_URL` (tests, a public release,
/// Flutter web) or the database is unreachable, the call is a no-op. A checkout
/// must never fail because the order could not be filed — the in-memory
/// services stay the source of truth the UI reads; this is the write-through.
///
/// Each method runs in one transaction, so a half-written order is never left
/// behind. The signed-in member is resolved by phone against `app.member`,
/// which sign-in / registration has already upserted; if that row is missing
/// the write is skipped rather than inventing one.
class OrderRepository {
  const OrderRepository._();

  static const OrderRepository instance = OrderRepository._();

  /// Whether a write would actually reach a database.
  bool get isAvailable => NeonDatabase.isConfigured;

  /// Files a standard product checkout: the `app."order"` row, its
  /// `app.order_line` rows, the initial `app.order_track_step` graph and, when
  /// one was submitted, the `app.order_receipt` claim.
  ///
  /// [code] is the order number the app already generated (`SHD-100512`); it is
  /// unique, so a retry with the same code is recognised and does nothing.
  Future<void> saveStandardOrder({
    required String phone,
    required String code,
    required List<OrderLineInput> lines,
    required int mrpTotal,
    required int paidTotal,
    required int deliveryFee,
    required int itemCount,
    String? storeCode,
    String? paymentMethodCode,
    String? reference,
    DeliveryAddressInput? address,
    OrderReceiptInput? receipt,
  }) {
    return _tx('saveStandardOrder', (tx) async {
      final memberId = await _memberId(tx, phone);
      if (memberId == null) {
        return;
      }
      final addressId =
          address == null ? null : await _upsertAddress(tx, memberId, address);

      final inserted = await tx.execute(
        Sql.named('''
          INSERT INTO app."order" (
            member_id, code, kind, status, item_count,
            mrp_total, paid_total, delivery_fee,
            delivery_address_id, store_id, payment_method_id, reference
          )
          VALUES (
            @member, @code, 'STANDARD', 'PROCESSING', @items,
            @mrp, @paid, @fee,
            @address,
            (SELECT id FROM app.shield_store WHERE code = @store),
            (SELECT id FROM app.payment_method WHERE code = @pm),
            @reference
          )
          ON CONFLICT (code) DO NOTHING
          RETURNING id
        '''),
        parameters: {
          'member': memberId,
          'code': code,
          'items': itemCount,
          'mrp': mrpTotal,
          'paid': paidTotal,
          'fee': deliveryFee,
          'address': addressId,
          'store': storeCode,
          'pm': paymentMethodCode,
          'reference': reference,
        },
      );
      if (inserted.isEmpty) {
        return; // already filed under this code
      }
      final orderId = inserted.first.first as int;

      await _insertLines(tx, orderId, lines);
      await _seedTrackSteps(tx, orderId, _standardStages);

      if (receipt != null) {
        await tx.execute(
          Sql.named('''
            INSERT INTO app.order_receipt
              (order_id, payer_name, reference, amount, file_name)
            VALUES (@order, @payer, @ref, @amount, @file)
          '''),
          parameters: {
            'order': orderId,
            'payer': receipt.payerName,
            'ref': receipt.reference,
            'amount': receipt.amount,
            'file': receipt.fileName,
          },
        );
      }
    });
  }

  /// Files a prescription checkout: for each prescription an `app.patient`
  /// (reused when it already exists), an `app.prescription` with its
  /// `app.prescription_medicine` lines, and a single `app."order"` of kind
  /// `PRESCRIPTION` that every `app.prescription_order` row links to.
  ///
  /// Nothing is priced here — `mrp_total` / `paid_total` stay zero until the
  /// pharmacist bills it — so the order carries only its line count.
  Future<void> savePrescriptionOrder({
    required String phone,
    required String orderCode,
    required List<PrescriptionInput> prescriptions,
    String? storeCode,
    String? paymentMethodCode,
    DeliveryAddressInput? address,
  }) {
    return _tx('savePrescriptionOrder', (tx) async {
      if (prescriptions.isEmpty) {
        return;
      }
      final memberId = await _memberId(tx, phone);
      if (memberId == null) {
        return;
      }
      final addressId =
          address == null ? null : await _upsertAddress(tx, memberId, address);

      final medicineCount = prescriptions.fold<int>(
        0,
        (sum, rx) => sum + rx.medicines.length,
      );
      final orderId = await _upsertOrderShell(
        tx,
        memberId: memberId,
        code: orderCode,
        kind: 'PRESCRIPTION',
        itemCount: medicineCount == 0 ? prescriptions.length : medicineCount,
        addressId: addressId,
        storeCode: storeCode,
        paymentMethodCode: paymentMethodCode,
      );
      if (orderId != null) {
        await _seedTrackSteps(tx, orderId, _prescriptionStages);
      }
      final storeId = await _storeId(tx, storeCode);

      for (final rx in prescriptions) {
        final patientId = await _upsertPatient(tx, memberId, rx.patient);
        if (patientId == null) {
          continue;
        }

        final row = await tx.execute(
          Sql.named('''
            INSERT INTO app.prescription (
              member_id, patient_id, code, file_name, doctor,
              duration, custom_days, recurring_from, recurring_until, status
            )
            VALUES (
              @member, @patient, @code, @file, @doctor,
              @duration::app.medicine_duration, @days,
              @from::date, @until::date, 'ORDERED'
            )
            ON CONFLICT (code) DO UPDATE SET
              patient_id      = EXCLUDED.patient_id,
              file_name       = EXCLUDED.file_name,
              doctor          = EXCLUDED.doctor,
              duration        = EXCLUDED.duration,
              custom_days     = EXCLUDED.custom_days,
              recurring_from  = EXCLUDED.recurring_from,
              recurring_until = EXCLUDED.recurring_until,
              status          = 'ORDERED',
              updated_at      = now()
            RETURNING id
          '''),
          parameters: {
            'member': memberId,
            'patient': patientId,
            'code': rx.code,
            'file': rx.fileName,
            'doctor': rx.doctor,
            'duration': rx.duration,
            'days': rx.customDays,
            'from': _isoDate(rx.recurringFrom),
            'until': _isoDate(rx.recurringUntil),
          },
        );
        final prescriptionId = row.first.first as int;

        // Re-key the lines so a re-submitted prescription reflects whatever the
        // pharmacy has added since.
        await tx.execute(
          Sql.named('DELETE FROM app.prescription_medicine '
              'WHERE prescription_id = @rx'),
          parameters: {'rx': prescriptionId},
        );
        for (var i = 0; i < rx.medicines.length; i++) {
          final m = rx.medicines[i];
          await tx.execute(
            Sql.named('''
              INSERT INTO app.prescription_medicine (
                prescription_id, sort, name, pack,
                dose_morning, dose_afternoon, dose_night, product_id
              )
              VALUES (
                @rx, @sort, @name, @pack,
                @morning, @afternoon, @night,
                (SELECT id FROM app.product WHERE lower(name) = lower(@name) LIMIT 1)
              )
            '''),
            parameters: {
              'rx': prescriptionId,
              'sort': i,
              'name': m.name,
              'pack': m.pack,
              'morning': m.doseMorning,
              'afternoon': m.doseAfternoon,
              'night': m.doseNight,
            },
          );
        }

        await tx.execute(
          Sql.named('''
            INSERT INTO app.prescription_order
              (prescription_id, order_id, store_id, status, customer_notes)
            VALUES (@rx, @order, @store, 'SUBMITTED', @notes)
          '''),
          parameters: {
            'rx': prescriptionId,
            'order': orderId,
            'store': storeId,
            'notes': rx.notes,
          },
        );
      }
    });
  }

  /// Files a lab basket: one `app.lab_booking` per package, each preceded by an
  /// upsert of the `app.lab_package` it points at (matched on a slug derived
  /// from the package name) so a package the backend has never seen is created
  /// rather than failing the not-null reference.
  Future<void> saveLabBookings({
    required String phone,
    required List<LabBookingInput> bookings,
    DeliveryAddressInput? address,
  }) {
    return _tx('saveLabBookings', (tx) async {
      if (bookings.isEmpty) {
        return;
      }
      final memberId = await _memberId(tx, phone);
      if (memberId == null) {
        return;
      }
      final addressId =
          address == null ? null : await _upsertAddress(tx, memberId, address);

      for (final b in bookings) {
        final pkg = await tx.execute(
          Sql.named('''
            INSERT INTO app.lab_package (
              slug, name, test_count, profile_count, rating, booked, report_in,
              price, mrp, saved, for_whom, age_range, preparation, sample, about
            )
            VALUES (
              @slug, @name, @tests, @profiles, @rating, @booked, @reportIn,
              @price, @mrp, @saved, @forWhom, @ageRange, @prep, @sample, @about
            )
            ON CONFLICT (slug) DO UPDATE SET
              name       = EXCLUDED.name,
              price      = EXCLUDED.price,
              mrp        = EXCLUDED.mrp,
              saved      = EXCLUDED.saved,
              updated_at = now()
            RETURNING id
          '''),
          parameters: {
            'slug': _slug(b.name),
            'name': b.name,
            'tests': b.testCount,
            'profiles': b.profileCount,
            'rating': b.rating,
            'booked': b.booked,
            'reportIn': b.reportIn,
            'price': b.unitPrice,
            'mrp': b.mrp,
            'saved': (b.mrp - b.unitPrice) < 0 ? 0 : b.mrp - b.unitPrice,
            'forWhom': b.forWhom,
            'ageRange': b.ageRange,
            'prep': b.preparation,
            'sample': b.sample,
            'about': b.about,
          },
        );
        final packageId = pkg.first.first as int;

        await tx.execute(
          Sql.named('''
            INSERT INTO app.lab_booking (
              member_id, lab_package_id, patients_count,
              unit_price, total_price, status, address_id
            )
            VALUES (@member, @pkg, @count, @unit, @total, 'REQUESTED', @address)
          '''),
          parameters: {
            'member': memberId,
            'pkg': packageId,
            'count': b.patients,
            'unit': b.unitPrice,
            'total': b.unitPrice * b.patients,
            'address': addressId,
          },
        );
      }
    });
  }

  // --- shared helpers ------------------------------------------------------

  static const List<String> _standardStages = [
    'Order placed',
    'Packed',
    'Dispatched',
    'Delivered',
  ];

  static const List<String> _prescriptionStages = [
    'Prescription received',
    'Pharmacist review',
    'Order confirmed',
    'Dispatched',
    'Delivered',
  ];

  Future<int?> _memberId(TxSession tx, String phone) async {
    final rows = await tx.execute(
      Sql.named('SELECT id FROM app.member '
          'WHERE phone = @phone AND deleted_at IS NULL LIMIT 1'),
      parameters: {'phone': phone},
    );
    return rows.isEmpty ? null : rows.first.first as int;
  }

  Future<int?> _storeId(TxSession tx, String? code) async {
    if (code == null || code.isEmpty) {
      return null;
    }
    final rows = await tx.execute(
      Sql.named('SELECT id FROM app.shield_store WHERE code = @code LIMIT 1'),
      parameters: {'code': code},
    );
    return rows.isEmpty ? null : rows.first.first as int;
  }

  /// Finds the member's matching address or writes a new one, returning its id.
  /// Matched on the house / area / pincode triple so a member who checks out
  /// repeatedly to the same place does not accumulate duplicate rows.
  Future<int> _upsertAddress(
    TxSession tx,
    int memberId,
    DeliveryAddressInput a,
  ) async {
    final existing = await tx.execute(
      Sql.named('''
        SELECT id FROM app.member_address
        WHERE member_id = @member
          AND lower(house) = lower(@house)
          AND lower(area) = lower(@area)
          AND pincode = @pincode
          AND deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {
        'member': memberId,
        'house': a.house,
        'area': a.area,
        'pincode': a.pincode,
      },
    );
    if (existing.isNotEmpty) {
      return existing.first.first as int;
    }
    final inserted = await tx.execute(
      Sql.named('''
        INSERT INTO app.member_address (
          member_id, label, house, area, landmark, pincode, city, state,
          first_name, last_name, phone
        )
        VALUES (
          @member, @label::app.address_label, @house, @area, @landmark,
          @pincode, @city, @state, @first, @last, @phone
        )
        RETURNING id
      '''),
      parameters: {
        'member': memberId,
        'label': a.label,
        'house': a.house,
        'area': a.area,
        'landmark': a.landmark,
        'pincode': a.pincode,
        'city': a.city.isEmpty ? null : a.city,
        'state': a.state.isEmpty ? null : a.state,
        'first': a.firstName,
        'last': a.lastName,
        'phone': a.phone,
      },
    );
    return inserted.first.first as int;
  }

  /// Resolves the patient to a row id: by `uuid` when the app carries one,
  /// then by (member, name, dob), inserting only when neither matched.
  Future<int?> _upsertPatient(
    TxSession tx,
    int memberId,
    PrescriptionPatientInput p,
  ) async {
    final uuid = p.remoteUuid;
    if (uuid != null && uuid.isNotEmpty) {
      final byUuid = await tx.execute(
        Sql.named('SELECT id FROM app.patient WHERE uuid = @uuid LIMIT 1'),
        parameters: {'uuid': uuid},
      );
      if (byUuid.isNotEmpty) {
        return byUuid.first.first as int;
      }
    }
    final byIdentity = await tx.execute(
      Sql.named('''
        SELECT id FROM app.patient
        WHERE member_id = @member
          AND lower(name) = lower(@name)
          AND dob = @dob::date
          AND deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {
        'member': memberId,
        'name': p.name,
        'dob': _isoDate(p.dob),
      },
    );
    if (byIdentity.isNotEmpty) {
      return byIdentity.first.first as int;
    }
    final inserted = await tx.execute(
      Sql.named('''
        INSERT INTO app.patient
          (member_id, name, phone, address, dob, gender, abha_id, relation)
        VALUES (
          @member, @name, @phone, @address, @dob::date,
          @gender::app.gender, @abha, @relation::app.patient_relation
        )
        RETURNING id
      '''),
      parameters: {
        'member': memberId,
        'name': p.name,
        'phone': p.phone,
        'address': p.address,
        'dob': _isoDate(p.dob),
        'gender': p.gender,
        'abha': p.abhaId,
        'relation': p.relation,
      },
    );
    return inserted.first.first as int;
  }

  /// Inserts the `app."order"` shell shared by the prescription flow, or finds
  /// the existing one when the code has already been used. Returns null only if
  /// the row can neither be inserted nor found.
  Future<int?> _upsertOrderShell(
    TxSession tx, {
    required int memberId,
    required String code,
    required String kind,
    required int itemCount,
    int? addressId,
    String? storeCode,
    String? paymentMethodCode,
  }) async {
    final inserted = await tx.execute(
      Sql.named('''
        INSERT INTO app."order" (
          member_id, code, kind, status, item_count,
          mrp_total, paid_total, delivery_address_id, store_id, payment_method_id
        )
        VALUES (
          @member, @code, @kind::app.order_kind, 'PROCESSING', @items,
          0, 0, @address,
          (SELECT id FROM app.shield_store WHERE code = @store),
          (SELECT id FROM app.payment_method WHERE code = @pm)
        )
        ON CONFLICT (code) DO NOTHING
        RETURNING id
      '''),
      parameters: {
        'member': memberId,
        'code': code,
        'kind': kind,
        'items': itemCount,
        'address': addressId,
        'store': storeCode,
        'pm': paymentMethodCode,
      },
    );
    if (inserted.isNotEmpty) {
      return inserted.first.first as int;
    }
    final found = await tx.execute(
      Sql.named('SELECT id FROM app."order" WHERE code = @code LIMIT 1'),
      parameters: {'code': code},
    );
    return found.isEmpty ? null : found.first.first as int;
  }

  Future<void> _insertLines(
    TxSession tx,
    int orderId,
    List<OrderLineInput> lines,
  ) async {
    for (final line in lines) {
      await tx.execute(
        Sql.named('''
          INSERT INTO app.order_line
            (order_id, product_id, name, pack, unit_price, mrp, qty)
          VALUES (
            @order,
            (SELECT id FROM app.product WHERE lower(name) = lower(@name) LIMIT 1),
            @name, @pack, @price, @mrp, @qty
          )
        '''),
        parameters: {
          'order': orderId,
          'name': line.name,
          'pack': line.pack,
          'price': line.unitPrice,
          'mrp': line.mrp,
          'qty': line.qty,
        },
      );
    }
  }

  /// Seeds the track graph at placement: the first stage done now, the second
  /// current, the rest still ahead — the same shape [OrderTrack] derives for a
  /// freshly placed order.
  Future<void> _seedTrackSteps(
    TxSession tx,
    int orderId,
    List<String> titles,
  ) async {
    final now = DateTime.now().toUtc();
    for (var i = 0; i < titles.length; i++) {
      final state = i == 0
          ? 'DONE'
          : i == 1
              ? 'CURRENT'
              : 'UPCOMING';
      await tx.execute(
        Sql.named('''
          INSERT INTO app.order_track_step (order_id, sort, title, state, occurred_at)
          VALUES (@order, @sort, @title, @state::app.track_state, @at)
        '''),
        parameters: {
          'order': orderId,
          'sort': i,
          'title': titles[i],
          'state': state,
          'at': i == 0 ? now : null,
        },
      );
    }
  }

  /// Runs [body] in one transaction against the shared connection, swallowing
  /// everything — a missing `DATABASE_URL`, a socket error, a SQL error — the
  /// same way [MemberRepository] does. A failed write is logged, never thrown.
  Future<void> _tx(
    String label,
    Future<void> Function(TxSession tx) body,
  ) async {
    if (!NeonDatabase.isConfigured) {
      return;
    }
    try {
      final conn = await NeonDatabase.instance.connection();
      await conn.runTx(body);
    } catch (error) {
      debugPrint('OrderRepository.$label: $error');
    }
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

  /// `Preventive Plus` -> `preventive-plus`, the key lab packages are matched
  /// on so the same panel booked twice updates one row.
  static String _slug(String name) {
    final lower = name.toLowerCase();
    final dashed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return dashed.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
