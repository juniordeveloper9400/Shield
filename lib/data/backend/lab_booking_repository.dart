import '../../module/labtest/lab_booking_record.dart';
import 'backend_http.dart';

/// Reads the signed-in member's lab bookings, and the report the lab
/// attached to one, through `backend/api`'s `/v1/member/lab-bookings` routes
/// (see `booking.service.ts`), never a direct Neon connection.
///
/// Best-effort like every read here: `null` when the backend is not
/// configured or unreachable, so the screen can say "could not load"
/// instead of showing an empty list that looks like "no bookings".
class LabBookingRepository {
  const LabBookingRepository._();

  static const LabBookingRepository instance = LabBookingRepository._();

  /// Every booking the member has made, newest first — `GET /v1/member/
  /// lab-bookings` (`BookingService.listLabBookingsForMember`) already
  /// returns exactly the camelCase shape [LabBookingRecord.fromJson] reads.
  /// [phone] is accepted for parity with the old direct-Neon signature; the
  /// backend resolves the member from the session, not this value.
  Future<List<LabBookingRecord>?> fetchForMember({String phone = ''}) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final rows =
          await BackendHttp.instance.request('GET', '/v1/member/lab-bookings')
              as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          LabBookingRecord.fromJson(row),
      ];
    } catch (error) {
      BackendHttp.log('LabBookingRepository.fetchForMember failed', error: error);
      return null;
    }
  }

  /// The report pages (`data:` URIs) of one of the member's own bookings, in
  /// order — `GET /v1/member/lab-bookings/:id/report`
  /// (`BookingService.getLabReportForMember`). The route itself is the
  /// ownership check: a booking id that isn't this member's 404s. [phone] is
  /// accepted for parity with the old direct-Neon signature; unused.
  Future<List<String>?> fetchReportPages({
    required int bookingId,
    String phone = '',
  }) async {
    if (!BackendHttp.isConfigured) {
      return null;
    }
    try {
      final body = await BackendHttp.instance.request(
            'GET',
            '/v1/member/lab-bookings/$bookingId/report',
          )
          as Map<String, dynamic>;
      final pages = (body['pages'] as List<dynamic>?) ?? const [];
      return [
        for (final page in pages.cast<Map<String, dynamic>>())
          if ((page['image'] ?? '').toString().isNotEmpty)
            page['image'].toString(),
      ];
    } catch (error) {
      BackendHttp.log('LabBookingRepository.fetchReportPages failed', error: error);
      return null;
    }
  }
}
