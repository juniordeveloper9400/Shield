import 'package:flutter/foundation.dart';

import '../neon/home_banner_repository.dart' show HomeBannerModel;
import 'backend_http.dart';

/// Reads the home-screen hero banner from `backend/api`'s
/// `GET /v1/public/catalogue/banners` (`catalogue.service.ts`'s
/// `listBanners`), maintained from the admin console (`shieldweb`).
///
/// Reuses [HomeBannerModel.fromRow] as-is rather than a separate JSON
/// mapper: every field on `app.home_banner` this model reads (`id`,
/// `title`, `subtitle`, `image`, `cta`, `target`, `sort`) is a single word,
/// so the backend's camelCase JSON and Neon's raw SQL row use the identical
/// keys — unlike the multi-word columns (`bank_account_name`, `tab_label`,
/// …) other repositories in this migration needed a separate mapper for.
///
/// `lib/data/neon/home_banner_repository.dart` (the class `HomeHeroBanner`
/// actually calls) tries this first and falls back to its own direct-Neon
/// path when the backend is unavailable or this fails.
///
/// Read-only and best-effort like the other backend repositories: an
/// unconfigured backend or a network failure returns an empty list rather
/// than throwing, so the caller falls back to the bundled default banner
/// instead of showing an error where a promotion belongs.
class BackendHomeBannerRepository {
  BackendHomeBannerRepository._({BackendHttp? http}) : _http = http ?? BackendHttp.instance;

  static final BackendHomeBannerRepository instance = BackendHomeBannerRepository._();

  /// Test-only: an instance wired to an injected [BackendHttp].
  @visibleForTesting
  factory BackendHomeBannerRepository.test({required BackendHttp http}) =>
      BackendHomeBannerRepository._(http: http);

  final BackendHttp _http;

  bool get isAvailable => _http.isEnabled;

  /// Every banner the admin has switched on, in display order. Rows with no
  /// image (should not happen — the console requires one) are dropped
  /// rather than shown as a blank slide.
  Future<List<HomeBannerModel>> listActive() async {
    if (!isAvailable) {
      return const [];
    }
    try {
      final rows = await _http.request(
        'GET',
        '/v1/public/catalogue/banners',
        auth: false,
      ) as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(HomeBannerModel.fromRow)
          .where((banner) => banner.image.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      BackendHttp.log('BackendHomeBannerRepository.listActive failed', error: error);
      return const [];
    }
  }
}
