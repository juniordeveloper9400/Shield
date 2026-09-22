import 'package:flutter/foundation.dart';

import '../backend/backend_home_banner_repository.dart';
import 'neon_http.dart';

/// One row of `app.home_banner` — a slide of the home hero carousel, exactly
/// as the admin console left it (device image upload, base64 in [image]).
@immutable
class HomeBannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String image;
  final String cta;
  final String target;
  final int sort;

  const HomeBannerModel({
    required this.id,
    required this.image,
    this.title = '',
    this.subtitle = '',
    this.cta = '',
    this.target = '',
    this.sort = 0,
  });

  factory HomeBannerModel.fromRow(Map<String, dynamic> row) {
    String str(Object? v) => (v ?? '').toString().trim();
    return HomeBannerModel(
      id: str(row['id']),
      title: str(row['title']),
      subtitle: str(row['subtitle']),
      image: str(row['image']),
      cta: str(row['cta']),
      target: str(row['target']),
      sort: int.tryParse(str(row['sort'])) ?? 0,
    );
  }
}

/// Reads the home-screen hero banner — `app.home_banner`, maintained from the
/// admin console (`shieldweb`).
///
/// Tries `backend/api` first (`BackendHomeBannerRepository`) and falls back
/// to the direct-Neon read below only when the backend is unavailable or
/// returns nothing — both read the identical table, this is a resilience
/// fallback during the migration off the compiled-in Neon credential, not
/// two independently maintained copies.
///
/// Read-only and best-effort like the other Neon repositories: a missing
/// `DATABASE_URL` or a network failure returns an empty list rather than
/// throwing, so [HomeHeroBanner] falls back to the bundled default banner
/// instead of showing an error where a promotion belongs.
class HomeBannerRepository {
  const HomeBannerRepository._();

  static const HomeBannerRepository instance = HomeBannerRepository._();

  bool get isAvailable =>
      BackendHomeBannerRepository.instance.isAvailable || NeonHttp.isConfigured;

  /// Every banner the admin has switched on, in display order. Rows with no
  /// image (should not happen — the console requires one) are dropped rather
  /// than shown as a blank slide.
  Future<List<HomeBannerModel>> listActive() async {
    final backend = BackendHomeBannerRepository.instance;
    if (backend.isAvailable) {
      final banners = await backend.listActive();
      if (banners.isNotEmpty) {
        return banners;
      }
      // Empty could mean "the admin published nothing" (a real answer,
      // trust it) or "the request itself failed" — BackendHomeBannerRepository
      // swallows both into the same empty list (matching this class's own
      // no-throw contract), so unlike every other repository in this
      // migration there is no way to tell them apart here and fall back
      // only on the second. Falling through to Neon either way is safe:
      // if the admin really published nothing, Neon answers the same empty
      // list right back.
    }

    if (!NeonHttp.isConfigured) {
      return const [];
    }
    try {
      final rows = await NeonHttp.instance.query(r'''
        SELECT id, title, subtitle, image, cta, target, sort
        FROM app.home_banner
        WHERE is_active
        ORDER BY sort, id
      ''');
      return rows
          .map(HomeBannerModel.fromRow)
          .where((banner) => banner.image.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      NeonHttp.log('HomeBannerRepository.listActive failed', error: error);
      return const [];
    }
  }
}
