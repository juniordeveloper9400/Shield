import '../../module/registration/shield_store.dart';
import '../backend/backend_store_repository.dart';
import 'neon_http.dart';

/// Reads the Sahakar 360 branch list — `app.shield_store`.
///
/// Tries `backend/api` first (`BackendStoreRepository`, the public
/// `v1/public/catalogue/stores` route) and falls back to the direct-Neon
/// read below only when the backend is unconfigured or the call fails —
/// both read the identical table, this is a resilience fallback during the
/// migration off the compiled-in Neon credential, not two independently
/// maintained copies. See the migration plan's own doc for why the Neon
/// path stays in place rather than being deleted outright.
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

  /// Whether a read would actually reach a database — the backend or Neon.
  bool get isAvailable =>
      BackendStoreRepository.instance.isConfigured || NeonHttp.isConfigured;

  /// Every active branch, in the console's display order, mapped to
  /// [ShieldStore] (the `code` becomes [ShieldStore.id]). Backend-sourced
  /// stores never carry bank details (see [BackendStoreRepository]'s own
  /// doc); `null` when neither the backend nor Neon could answer, or an
  /// empty result either way — never an empty list — so the caller can
  /// keep the seed.
  Future<List<ShieldStore>?> fetchAll() async {
    final backend = BackendStoreRepository.instance;
    if (backend.isConfigured) {
      try {
        final stores = await backend.fetchAll();
        if (stores != null) {
          return stores;
        }
      } catch (error) {
        NeonHttp.log('StoreRepository.fetchAll: backend failed, falling back to Neon', error: error);
      }
    }

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
               offers_lab_collection,
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

  /// One active branch's bank details, by its stable [code] — the
  /// direct-Neon fallback for [ShieldPayees.liveAccountFor] when the
  /// backend's own scoped, member-gated route
  /// (`BackendStoreRepository.fetchBankDetails`) is unavailable or fails.
  /// Null on any failure, exactly like every other read here.
  Future<Map<String, String>?> fetchBankDetails(String code) async {
    if (!NeonHttp.isConfigured) {
      return null;
    }
    try {
      final rows = await NeonHttp.instance.query(
        '''
          SELECT bank_account_name, bank_account_number, bank_ifsc, bank_name
          FROM app.shield_store
          WHERE code = \$1 AND is_active
          LIMIT 1
        ''',
        [code],
      );
      if (rows.isEmpty) {
        return null;
      }
      final row = rows.first;
      String str(Object? v) => (v ?? '').toString().trim();
      return {
        'bankAccountName': str(row['bank_account_name']),
        'bankAccountNumber': str(row['bank_account_number']),
        'bankIfsc': str(row['bank_ifsc']),
        'bankName': str(row['bank_name']),
      };
    } catch (error) {
      NeonHttp.log('StoreRepository.fetchBankDetails failed', error: error);
      return null;
    }
  }
}
