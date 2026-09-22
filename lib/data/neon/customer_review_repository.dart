import '../../module/home/customer_reviews.dart';
import '../backend/backend_customer_review_repository.dart';
import 'neon_http.dart';

/// Reads "What our customers have to say" — `app.customer_review_video`.
///
/// Tries `backend/api` first (`BackendCustomerReviewRepository`) and falls
/// back to the direct-Neon read below only when the backend is unavailable
/// or the call fails — both read the identical table, this is a resilience
/// fallback during the migration off the compiled-in Neon credential, not
/// two independently maintained copies.
///
/// Read-only. Clips are added, ordered and hidden from the pharmacy admin
/// console (`shieldweb`), never from the app; this repository only lists what
/// the admin has switched on.
///
/// Best-effort, like the other Neon repositories: with no `DATABASE_URL`
/// compiled in (tests, or a web build that was not given the define) or the
/// network down, [listActive] returns `null` so the caller can tell "could
/// not load" from "the admin has added nothing yet" and fall back to the
/// clips bundled with the app.
class CustomerReviewRepository {
  const CustomerReviewRepository._();

  static const CustomerReviewRepository instance =
      CustomerReviewRepository._();

  /// Whether a read would actually reach a database — the backend or Neon.
  bool get isAvailable =>
      BackendCustomerReviewRepository.instance.isAvailable || NeonHttp.isConfigured;

  /// Every clip the admin has marked active, in display order.
  ///
  /// Returns `null` (not an empty list) when neither the backend nor Neon
  /// could answer, so a transient failure does not blank the reel — the
  /// caller falls back to the bundled clips instead.
  Future<List<CustomerReviewItem>?> listActive() async {
    final backend = BackendCustomerReviewRepository.instance;
    if (backend.isAvailable) {
      try {
        final items = await backend.listActive();
        if (items != null) {
          return items;
        }
      } catch (error) {
        NeonHttp.log('CustomerReviewRepository.listActive: backend failed, falling back to Neon', error: error);
      }
    }

    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(r'''
        SELECT uuid, name, subtitle, video_url, thumbnail
        FROM app.customer_review_video
        WHERE is_active = true
        ORDER BY sort, id
      ''');
      return rows
          .map(_fromRow)
          .whereType<CustomerReviewItem>()
          .toList(growable: false);
    } catch (error) {
      NeonHttp.log('CustomerReviewRepository.listActive failed', error: error);
      return null;
    }
  }

  /// Maps one row to a [CustomerReviewItem], or `null` when it has no name or
  /// no clip to play — a row like that has nothing a card can show.
  static CustomerReviewItem? _fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim() ?? '';
    final video = (row['video_url'] as String?)?.trim() ?? '';
    if (name.isEmpty || video.isEmpty) {
      return null;
    }
    final subtitle = (row['subtitle'] as String?)?.trim();
    final thumbnail = (row['thumbnail'] as String?)?.trim();
    return CustomerReviewItem(
      id: (row['uuid'] as String?)?.trim().isNotEmpty == true
          ? (row['uuid'] as String).trim()
          : video,
      name: name,
      video: video,
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      thumbnail: (thumbnail == null || thumbnail.isEmpty) ? null : thumbnail,
    );
  }
}
