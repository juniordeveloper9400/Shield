/// The agent row the admin console created for a member, flattened to what the
/// app needs to build an [Agent].
class RemoteAgent {
  final String code;
  final String name;
  final String phone;

  /// Lowercase `AgentLevel` name — `national` … `ward`.
  final String level;
  final bool active;
  final String area;
  final int earned;
  final int redeemed;
  final int personalSales;

  /// The parent agent's `code`, or null at the top of the tree.
  final String? parentCode;

  const RemoteAgent({
    required this.code,
    required this.name,
    required this.phone,
    required this.level,
    required this.active,
    required this.area,
    required this.earned,
    required this.redeemed,
    required this.personalSales,
    required this.parentCode,
  });
}

/// The investor row the admin console created for a member.
class RemoteInvestor {
  final String code;
  final String name;
  final String phone;
  final int totalUnits;
  final int unitPrice;
  final DateTime investedSince;
  final double roiPercent;

  /// Lowercase `InvestorPlanType` name — `yearly` / `monthly`.
  final String planType;

  /// The `app.shield_store.code` this stake is in, or null.
  final String? storeCode;

  const RemoteInvestor({
    required this.code,
    required this.name,
    required this.phone,
    required this.totalUnits,
    required this.unitPrice,
    required this.investedSince,
    required this.roiPercent,
    required this.planType,
    required this.storeCode,
  });
}

/// What a phone resolves to on Neon — at most one of [agent] / [investor], or
/// neither for a plain member. [deleted] wins over both: an admin who has
/// soft-deleted the `app.users` row (`deleted_at`) has revoked the account
/// entirely, regardless of any agent/investor row still sitting under it.
class PersonaSnapshot {
  final RemoteAgent? agent;
  final RemoteInvestor? investor;
  final bool deleted;

  const PersonaSnapshot({this.agent, this.investor, this.deleted = false});

  static const PersonaSnapshot none = PersonaSnapshot();
  static const PersonaSnapshot deletedAccount = PersonaSnapshot(deleted: true);

  bool get isAgent => agent != null;
  bool get isInvestor => investor != null;
}

// The repository that used to read these straight from `app.agent`/
// `app.investor`/`app.users` over a direct Neon connection
// (`PersonaRepository`) is gone — see `BackendPersonaRepository`'s own
// doc for the backend/api routes it replaced it with
// (`GET /v1/agent/me`, `GET /v1/investor/me`, `GET /v1/member/me`). The
// three data classes above stay here; `BackendPersonaRepository` builds
// them from the backend's own JSON instead of a SQL row.
