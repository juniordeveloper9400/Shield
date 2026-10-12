import 'package:flutter/foundation.dart';

import 'investor_directory.dart';
import 'investor_model.dart';

/// Access into the investor world: resolving who the signed-in investor is.
///
/// [_remote] is the `app.investor` row [PersonaGate] applied for the
/// signed-in member — a conversion the Super Admin made, via
/// `GET /v1/investor/me`. This used to instead pull the *entire*
/// `app.investor` table ([InvestorRepository.fetchAll], now gone) and
/// search it client-side for a phone match — every investor's name, phone
/// and holdings, bulk-readable by anyone who extracted the compiled-in
/// Neon credential, to answer a question that is really just "is this one
/// signed-in member an investor". [PersonaGate] already asks exactly that,
/// scoped to the session, so there is nothing left for this class to load
/// on its own.
class InvestorService extends ChangeNotifier {
  InvestorService._();

  static final InvestorService instance = InvestorService._();

  /// The investor row [PersonaGate] applied for the signed-in member, or
  /// null when they are not one (or nothing has resolved yet).
  Investor? _remote;

  /// Whether the signed-in investor has asked to switch their return plan.
  ///
  /// Set for the session when the portal's "Request … plan" action is used, so
  /// the button reads back as "Change requested" and cannot be tapped twice.
  /// The durable record is the `app.investor_plan_change_request` row
  /// `BackendInvestorRepository` writes; this is only the running app's memory of it.
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

  /// Applies — or, with null, clears — the `app.investor` row the console
  /// created for the signed-in member. Called by [PersonaGate] whenever it
  /// resolves (or re-resolves) the signed-in member's persona.
  void applyRemoteInvestor(Investor? investor) {
    if (_remote == investor) {
      return;
    }
    _remote = investor;
    notifyListeners();
  }

  /// The investor for [phone], or null when the number is not one. Prefers
  /// the admin-applied row, then the bundled demo persona (so the Investor
  /// Access card still has something to show before [PersonaGate]'s first
  /// check lands, or in a build with no backend configured at all).
  Investor? investorForPhone(String? phone) {
    if (phone == null) {
      return null;
    }
    final clean = phone.trim();
    if (_remote != null && _remote!.phone == clean) {
      return _remote;
    }
    for (final investor in InvestorDirectory.seed) {
      if (investor.phone == clean) {
        return investor;
      }
    }
    return null;
  }

  @visibleForTesting
  void reset() {
    _remote = null;
    _planChangeRequested = false;
    notifyListeners();
  }
}
