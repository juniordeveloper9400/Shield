import '../../module/registration/shield_store.dart';
import 'neon_http.dart';

/// Reads the SHIELD branch list — `app.shield_store` — from Neon over the HTTP
/// SQL endpoint (see [NeonHttp]).
///
/// Read-only. Branches are created and maintained from the admin console
/// (`shieldweb`), never from the app; this repository only lists the active
/// ones so `StoreCatalog` can swap them in for the bundled seed.
///
/// Best-effort, like the other Neon repositories: with no `DATABASE_URL`
/// compiled in (tests, or a web build that was not given the define), the
/// network down, or a SQL error, [fetchAll] returns `null` — never an empty
/// list — so `StoreCatalog` keeps the seed rather than blanking the store
/// picker.
class StoreRepository {
  const StoreRepository._();

  static const StoreRepository instance = StoreRepository._();

  /// Whether a read would actually reach the database.
  bool get isAvailable => NeonHttp.isConfigured;

  /// Every active branch, in the console's display order, mapped to
  /// [ShieldStore] (the `code` becomes [ShieldStore.id]). `null` when the
  /// database is off, unreachable, or the query failed; an empty result also
  /// maps to `null` so the caller can keep the seed.
  Future<List<ShieldStore>?> fetchAll() async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(r'''
        SELECT code,
               name,
               area,
               city,
               state,
               pincode,
               phone,
               hours,
               latitude::text  AS latitude,
               longitude::text AS longitude,
               maps_url,
               bank_account_name,
               bank_account_number,
               bank_ifsc,
               bank_name
        FROM app.shield_store
        WHERE is_active
        ORDER BY sort, name
      ''');
      final stores = rows
          .map(ShieldStore.fromRow)
          .whereType<ShieldStore>()
          .toList(growable: false);
      return stores.isEmpty ? null : stores;
    } catch (error) {
      NeonHttp.log('StoreRepository.fetchAll failed', error: error);
      return null;
    }
  }
}
