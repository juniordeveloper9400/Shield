import '../../data/backend/backend_store_repository.dart';
import '../../data/neon/store_repository.dart';
import '../registration/shield_store.dart';

/// The bank account a store admin has published for manual transfers.
///
/// Kept by store rather than globally: a member pays the branch they chose,
/// and the receipt has to reach the same admin who can match it.
class StoreBankAccount {
  final String id;
  final String accountName;
  final String accountNumber;
  final String ifsc;
  final String bank;
  final String branch;

  const StoreBankAccount({
    required this.id,
    required this.accountName,
    required this.accountNumber,
    required this.ifsc,
    required this.bank,
    required this.branch,
  });

  String get shortLabel => '$bank · $branch';
}

/// Store-specific payees. In production these come from the pharmacy admin.
abstract final class ShieldPayees {
  static const StoreBankAccount melatturPrimary = StoreBankAccount(
    id: 'mel-sbi',
    accountName: 'SHIELD Pharmacy Melattur',
    accountNumber: '6724 0031 9182',
    ifsc: 'SBIN0070326',
    bank: 'State Bank of India',
    branch: 'Melattur',
  );

  static const StoreBankAccount makkaraparambaPrimary = StoreBankAccount(
    id: 'mkp-fed',
    accountName: 'SHIELD Pharmacy Makkaraparamba',
    accountNumber: '1489 2210 4470',
    ifsc: 'FDRL0001489',
    bank: 'Federal Bank',
    branch: 'Makkaraparamba',
  );

  static const Map<String, List<StoreBankAccount>> _byStore = {
    'SHD-MEL': [melatturPrimary],
    'SHD-MKP': [makkaraparambaPrimary],
    'SHD-TIR': [
      StoreBankAccount(
        id: 'tir-canara',
        accountName: 'SHIELD Pharmacy Tirur',
        accountNumber: '0982 4500 7613',
        ifsc: 'CNRB0006761',
        bank: 'Canara Bank',
        branch: 'Tirur',
      ),
    ],
    'SHD-KKT': [
      StoreBankAccount(
        id: 'kkt-sbi',
        accountName: 'SHIELD Pharmacy Karinkallathani',
        accountNumber: '6724 0031 9321',
        ifsc: 'SBIN0079321',
        bank: 'State Bank of India',
        branch: 'Karinkallathani',
      ),
    ],
    'SHD-MJR': [
      StoreBankAccount(
        id: 'mjr-federal',
        accountName: 'SHIELD Pharmacy Manjery',
        accountNumber: '1489 2210 4121',
        ifsc: 'FDRL0004121',
        bank: 'Federal Bank',
        branch: 'Manjery',
      ),
    ],
    'SHD-ALN': [
      StoreBankAccount(
        id: 'aln-sbi',
        accountName: 'SHIELD Pharmacy Alanallur',
        accountNumber: '6724 0031 8601',
        ifsc: 'SBIN0078601',
        bank: 'State Bank of India',
        branch: 'Alanallur',
      ),
    ],
    'SHD-TRD': [
      StoreBankAccount(
        id: 'trd-canara',
        accountName: 'SHIELD Pharmacy Tirurangadi',
        accountNumber: '0982 4500 7306',
        ifsc: 'CNRB0007306',
        bank: 'Canara Bank',
        branch: 'Tirurangadi',
      ),
    ],
    'SHD-KNP': [
      StoreBankAccount(
        id: 'knp-fed',
        accountName: 'SHIELD Pharmacy Kunnumpuram',
        accountNumber: '1489 2210 4505',
        ifsc: 'FDRL0004505',
        bank: 'Federal Bank',
        branch: 'Kunnumpuram',
      ),
    ],
    'SHD-KND': [
      StoreBankAccount(
        id: 'knd-sbi',
        accountName: 'SHIELD Pharmacy Kondotty',
        accountNumber: '6724 0031 7638',
        ifsc: 'SBIN0077638',
        bank: 'State Bank of India',
        branch: 'Kondotty',
      ),
    ],
    'SHD-ARK': [
      StoreBankAccount(
        id: 'ark-canara',
        accountName: 'SHIELD Pharmacy Areekode',
        accountNumber: '0982 4500 7639',
        ifsc: 'CNRB0007639',
        bank: 'Canara Bank',
        branch: 'Areekode',
      ),
    ],
  };

  static List<StoreBankAccount> forStore(ShieldStore store) {
    // A branch loaded from the database carries its own published account —
    // prefer that over the bundled map so an admin-added branch is payable
    // straight away. Only ever true for a Neon-sourced [ShieldStore]: a
    // backend-sourced one never carries bank fields (see
    // [BackendStoreRepository]'s own doc) — [liveAccountFor] is what
    // refines this case instead.
    if (store.bankAccountNumber.isNotEmpty) {
      return [
        StoreBankAccount(
          id: '${store.id.toLowerCase()}-store',
          accountName: store.bankAccountName.isEmpty
              ? store.name
              : store.bankAccountName,
          accountNumber: store.bankAccountNumber,
          ifsc: store.bankIfsc,
          bank: store.bankName,
          branch: store.area,
        ),
      ];
    }
    return _byStore[store.id] ?? [melatturPrimary];
  }

  /// [forStore]'s live refinement: fetches [store]'s actual bank details —
  /// backend first, then direct-Neon — and returns the account to show once
  /// one of them answers, or null when neither could (so the caller keeps
  /// showing whatever [forStore] already returned instantly).
  ///
  /// Exists because `StoreCatalog`'s branch list stopped carrying bank
  /// fields once it started preferring `backend/api` (a public bulk
  /// bank-details dump was a real leak — see `catalogue.service.ts`'s own
  /// doc on `listStores`) — without this, any branch not already in
  /// [_byStore] (every branch added through the console after this map was
  /// written) would silently show [melatturPrimary]'s account instead of
  /// its own. Checkout calls this as a best-effort refinement alongside
  /// [forStore], never in place of it — see `checkout_screen.dart`'s own
  /// `_refreshLiveBankAccount`.
  static Future<StoreBankAccount?> liveAccountFor(ShieldStore store) async {
    Map<String, String>? details;
    final backend = BackendStoreRepository.instance;
    if (backend.canFetchBankDetails) {
      details = await backend.fetchBankDetails(store.id);
    }
    details ??= await StoreRepository.instance.fetchBankDetails(store.id);
    if (details == null) {
      return null;
    }
    final number = details['bankAccountNumber'] ?? '';
    if (number.isEmpty) {
      // A genuine "no bank details on file yet" — not something to prefer
      // over whatever forStore already found (its own bundled fallback is
      // more useful than a known-blank live answer).
      return null;
    }
    final accountName = details['bankAccountName'] ?? '';
    return StoreBankAccount(
      id: '${store.id.toLowerCase()}-live',
      accountName: accountName.isEmpty ? store.name : accountName,
      accountNumber: number,
      ifsc: details['bankIfsc'] ?? '',
      bank: details['bankName'] ?? '',
      branch: store.area,
    );
  }
}
