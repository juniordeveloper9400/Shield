import 'package:flutter/foundation.dart';

import '../../module/home/customer_reviews.dart';
import 'backend_http.dart';

/// Reads "What our customers have to say" from `backend/api`'s
/// `GET /v1/public/catalogue/review-videos` — see `catalogue.service.ts`'s
/// `listActiveReviewVideos`.
///
/// Ported from `shield agent_invester/lib/data/backend/customer_review_repository.dart`.
/// `lib/data/neon/customer_review_repository.dart` (the class
/// `CustomerReviewsService` actually calls) tries this first and falls back
/// to its own direct-Neon path when the backend is unavailable or this
/// fails.
///
/// Best-effort: with an unconfigured backend or the network down,
/// [listActive] returns `null` so the caller can tell "could not load" from
/// "the admin has added nothing yet" and fall back to the clips bundled
/// with the app.
class BackendCustomerReviewRepository {
  BackendCustomerReviewRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendCustomerReviewRepository instance = BackendCustomerReviewRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendCustomerReviewRepository.test({required BackendHttp http}) =>
      BackendCustomerReviewRepository._(http: http);

  final BackendHttp _http;

  bool get isAvailable => _http.isEnabled;

  /// Every clip the admin has marked active, in display order. Returns
  /// `null` (not an empty list) when the backend is off or unreachable.
  Future<List<CustomerReviewItem>?> listActive() async {
    if (!isAvailable) {
      return null;
    }
    try {
      final rows = await _http.request(
        'GET',
        '/v1/public/catalogue/review-videos',
        auth: false,
      ) as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(_fromRow)
          .whereType<CustomerReviewItem>()
          .toList(growable: false);
    } catch (error) {
      BackendHttp.log('BackendCustomerReviewRepository.listActive failed', error: error);
      return null;
    }
  }

  /// Maps one row to a [CustomerReviewItem], or `null` when it has no name
  /// or no clip to play — a row like that has nothing a card can show.
  static CustomerReviewItem? _fromRow(Map<String, dynamic> row) {
    final name = (row['name'] as String?)?.trim() ?? '';
    final video = (row['videoUrl'] as String?)?.trim() ?? '';
    if (name.isEmpty || video.isEmpty) {
      return null;
    }
    final subtitle = (row['subtitle'] as String?)?.trim();
    final thumbnail = (row['thumbnail'] as String?)?.trim();
    final uuid = (row['uuid'] as String?)?.trim();
    return CustomerReviewItem(
      id: (uuid?.isNotEmpty ?? false) ? uuid! : video,
      name: name,
      video: video,
      subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
      thumbnail: (thumbnail == null || thumbnail.isEmpty) ? null : thumbnail,
    );
  }
}
