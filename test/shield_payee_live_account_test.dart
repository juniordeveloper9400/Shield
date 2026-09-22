import 'package:flutter_test/flutter_test.dart';

import 'package:shield/module/checkout/shield_payee.dart';
import 'package:shield/module/registration/shield_store.dart';

void main() {
  const store = ShieldStore(
    id: 'SHD-ALT',
    name: 'Sahakar 360 Pharmacy Althaf',
    area: 'Demo',
    city: 'Demo',
    state: 'Kerala',
    pincode: '679322',
  );

  group('ShieldPayees.liveAccountFor', () {
    test('is null under `flutter test`, where neither backend nor Neon is configured', () async {
      // Both BackendHttp and NeonHttp report unconfigured under test — see
      // their own `_underTest` guards — so this must fail open (null),
      // never throw, matching every other best-effort read in this app.
      expect(await ShieldPayees.liveAccountFor(store), isNull);
    });

    test('forStore still returns something usable — the bundled fallback — for a branch with no live bank details yet', () {
      // SHD-ALT is not in ShieldPayees' own bundled map, so this proves the
      // documented fallback ("melatturPrimary") rather than a crash — the
      // exact case liveAccountFor exists to refine once it has an answer.
      final fallback = ShieldPayees.forStore(store);
      expect(fallback, [ShieldPayees.melatturPrimary]);
    });
  });
}
