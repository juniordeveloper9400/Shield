import 'package:flutter/foundation.dart';

import '../../data/neon/investor_repository.dart';
import 'investor_directory.dart';
import 'investor_model.dart';

/// Access into the investor world: resolving who the signed-in investor is.
///
/// [_live] starts as the bundled demo ([InvestorDirectory.seed]) and is
/// replaced by the real `app.investor` roster once [ensureLoaded] has pulled
/// it — the same best-effort, seed-until-loaded contract as `StoreCatalog` and
/// `AgentGeo`. So the home screen's Investor Access card (via
/// [investorForPhone]) only ever matches a number the admin console has
/// actually converted, not a hardcoded demo, once the database is reachable.
class InvestorService extends ChangeNotifier {
  InvestorService._();

  static final InvestorService instance = InvestorService._();

  List<Investor> _live = InvestorDirectory.seed;

  bool _loaded = false;
  bool _fromDatabase = false;
  bool _attempted = false;

  /// Whether [investorForPhone] is reading the database copy rather than the
  /// bundled demo.
  bool get isFromDatabase => _fromDatabase;

  /// True once a load has run to completion at least once — success, empty
  /// table, or failure. Lets a screen tell "still loading" from "loaded and
  /// there is genuinely no investor for this number".
  bool get hasAttempted => _attempted;

  Future<void>? _inFlight;

  /// Whether the signed-in investor has asked to switch their return plan.
  ///
  /// Set for the session when the portal's "Request … plan" action is used, so
  /// the button reads back as "Change requested" and cannot be tapped twice.
  /// The durable record is the `app.investor_plan_change_request` row
  /// [InvestorRepository] writes; this is only the running app's memory of it.
  bool _planChangeRequested = false;

  bool get planChangeRequested => _planChangeRequested;

  /// Records that a plan-change request has been sent.
  void markPlanChangeRequested() {
    if (_planChangeRequested) {
      return;
    }
    _planChangeRequested = true;
    notifyListeners();
  }

  /// Loads the real investor roster from Neon once (best-effort — a missing
  /// database just leaves the bundled demo in place). Safe to call from every
  /// screen's `initState`; only the first call does any work unless [force].
  Future<void> ensureLoaded({bool force = false}) {
    if (force) {
      _loaded = false;
      _inFlight = null;
    }
    if (_loaded) return Future<void>.value();
    return _inFlight ??= _load();
  }

  Future<void> _load() async {
    try {
      final investors = await InvestorRepository.instance.fetchAll();
      if (investors != null && investors.isNotEmpty) {
        _live = investors;
        _fromDatabase = true;
        _loaded = true;
      }
      // Otherwise nothing came back — endpoint not configured, or the table
      // was empty. Leave [_loaded] false so the next ensureLoaded() retries.
    } catch (error) {
      debugPrint('InvestorService: roster load failed — $error');
    } finally {
      _attempted = true;
      _inFlight = null;
      notifyListeners();
    }
  }

  /// The investor for [phone], or null when the number is not one. Reads the
  /// database roster once loaded, the bundled demo until then.
  Investor? investorForPhone(String? phone) {
    if (phone == null) {
      return null;
    }
    final clean = phone.trim();
    for (final investor in _live) {
      if (investor.phone == clean) {
        return investor;
      }
    }
    return null;
  }

  /// Test hook — stand in [investors] for what a database load would return.
  @visibleForTesting
  void useInvestors(List<Investor> investors) {
    _live = List<Investor>.unmodifiable(investors);
    _loaded = true;
    _fromDatabase = true;
    _attempted = true;
    _inFlight = null;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _live = InvestorDirectory.seed;
    _loaded = false;
    _fromDatabase = false;
    _attempted = false;
    _inFlight = null;
    _planChangeRequested = false;
    notifyListeners();
  }
}
