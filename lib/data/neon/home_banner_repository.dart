import 'package:flutter/foundation.dart';

import '../backend/backend_home_banner_repository.dart';

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

/// Reads a placement's own swipeable banner strip — `app.home_banner`
/// filtered to `placement` (migration 0069), maintained from the admin
/// console (`shieldweb`). `'home'` is the original hero carousel; `'lab'` is
/// the Lab section's own, added alongside it — same table, same shape,
/// different strip. Through `backend/api` (`BackendHomeBannerRepository`)
/// now, never a direct Neon connection — that path, and the compiled-in
/// database credential it depended on, is gone (see `docs/security.md`
/// and `backend/docs/migration-plan.md`'s Phase 5).
///
/// Read-only and best-effort: an unconfigured backend or a network failure
/// returns an empty list rather than throwing, so [HomeHeroBanner] falls
/// back to the bundled default banner (on the `'home'` placement only —
/// see its own `showBundledDefault`) instead of showing an error where a
/// promotion belongs.
class HomeBannerRepository {
  const HomeBannerRepository._();

  static const HomeBannerRepository instance = HomeBannerRepository._();

  bool get isAvailable => BackendHomeBannerRepository.instance.isAvailable;

  /// Every banner the admin has switched on for [placement], in display
  /// order. Rows with no image (should not happen — the console requires
  /// one) are dropped rather than shown as a blank slide.
  Future<List<HomeBannerModel>> listActive({String placement = 'home'}) =>
      BackendHomeBannerRepository.instance.listActive(placement: placement);
}
