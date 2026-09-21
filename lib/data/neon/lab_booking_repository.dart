import '../../module/labtest/lab_booking_record.dart';
import 'neon_http.dart';

/// Reads the signed-in member's lab bookings, and the report the lab attached
/// to one, straight from Neon.
///
/// Best-effort like every read here: `null` when the database is not
/// configured or the network is down, so the screen can say "could not load"
/// instead of showing an empty list that looks like "no bookings".
class LabBookingRepository {
  const LabBookingRepository._();

  static const LabBookingRepository instance = LabBookingRepository._();

  /// Every booking [phone] has made, newest first. The report pages are only
  /// counted here — each is a large image, read by [fetchReportPages] when the
  /// member opens the report.
  Future<List<LabBookingRecord>?> fetchForMember({required String phone}) async {
    if (!NeonHttp.isConfigured || phone.isEmpty) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(
        r'''
          SELECT lb.id, lp.name AS package_name, lb.patients_count,
                 lb.total_price, lb.status::text AS status,
                 lb.scheduled_for, lb.note, lb.created_at,
                 (SELECT count(*)::int
                    FROM app.lab_booking_report r
                   WHERE r.lab_booking_id = lb.id) AS report_pages
          FROM app.lab_booking lb
          JOIN app.users u ON u.id = lb.member_id
          LEFT JOIN app.lab_package lp ON lp.id = lb.lab_package_id
          WHERE u.phone = $1
          ORDER BY lb.created_at DESC
        ''',
        [phone],
      );
      return [
        for (final row in rows)
          LabBookingRecord.fromJson({
            'id': row['id'],
            'packageName': row['package_name'],
            'patientsCount': row['patients_count'],
            'totalPrice': row['total_price'],
            'status': row['status'],
            'scheduledFor': row['scheduled_for'],
            'note': row['note'],
            'createdAt': row['created_at'],
            'reportPages': row['report_pages'],
          }),
      ];
    } catch (error) {
      NeonHttp.log('LabBookingRepository.fetchForMember failed', error: error);
      return null;
    }
  }

  /// The report pages (`data:` URIs) of one of [phone]'s own bookings, in
  /// order. The join on the member's phone is the ownership check: someone
  /// else's booking id reads back as an empty report, never as their pages.
  Future<List<String>?> fetchReportPages({
    required int bookingId,
    required String phone,
  }) async {
    if (!NeonHttp.isConfigured || phone.isEmpty) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(
        r'''
          SELECT r.image
          FROM app.lab_booking_report r
          JOIN app.lab_booking lb ON lb.id = r.lab_booking_id
          JOIN app.users u ON u.id = lb.member_id
          WHERE lb.id = $1 AND u.phone = $2
          ORDER BY r.sort, r.id
        ''',
        [bookingId, phone],
      );
      return [
        for (final row in rows)
          if ((row['image'] ?? '').toString().isNotEmpty)
            row['image'].toString(),
      ];
    } catch (error) {
      NeonHttp.log('LabBookingRepository.fetchReportPages failed', error: error);
      return null;
    }
  }
}
