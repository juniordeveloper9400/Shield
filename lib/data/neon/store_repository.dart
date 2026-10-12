import '../../module/registration/shield_store.dart';
import '../backend/backend_store_repository.dart';

/// Reads the Sahakar 360 branch list — `app.shield_store` — through
/// `backend/api` (`BackendStoreRepository`), never a direct Neon
/// connection. This used to also hold a direct-Neon fallback for when the
/// backend call failed, including a bulk SELECT of every branch's bank
/// account details — exactly the public bulk bank-details dump
/// `BackendStoreRepository`'s own doc says the backend deliberately never
/// carries. That path is gone now, along with the compiled-in database
/// credential it depended on (see `docs/security.md` and
/// `backend/docs/migration-plan.md`'s Phase 5).
///
/// Read-only. Branches are created and maintained from the admin console
/// (`shieldweb`), never from the app; this repository only lists the active
/// ones so `StoreCatalog` can swap them in for the bundled seed.
class StoreRepository {
  const StoreRepository._();

  static const StoreRepository instance = StoreRepository._();

  /// Whether a read would actually reach the backend.
  bool get isAvailable => BackendStoreRepository.instance.isConfigured;

  /// Every active branch, in the console's display order, mapped to
  /// [ShieldStore] (the `code` becomes [ShieldStore.id]). Never carries
  /// bank details (see [BackendStoreRepository]'s own doc — [liveAccountFor]
  /// is what refines a branch's actual bank account); `null` when the
  /// backend couldn't answer, so the caller can keep the seed.
  Future<List<ShieldStore>?> fetchAll() => BackendStoreRepository.instance.fetchAll();

  /// One active branch's bank details, by its stable [code] — requires a
  /// live member session (see [BackendStoreRepository.canFetchBankDetails]).
  /// Null when there is no session, the backend refused, or the read
  /// failed; the caller ([ShieldPayees.liveAccountFor]) falls back to
  /// whatever it already has rather than treating this as "no bank details
  /// on file".
  Future<Map<String, String>?> fetchBankDetails(String code) =>
      BackendStoreRepository.instance.fetchBankDetails(code);
}
