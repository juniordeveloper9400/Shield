/**
 * Maps a `/v1/staff/*` request to the shieldweb sidebar module it belongs
 * to — the server-side half of config/permissions.ts's MODULES list (kept
 * in sync by hand the same way modulesSchema in admin/dto.ts is). Built
 * from a full audit of every page's own API calls against every backend
 * controller's own route list (not guessed from naming) — see the PR that
 * introduced this file for that audit's own notes.
 *
 * ModuleGuard uses this to enforce an account's own custom `modules` list
 * (app.admin_user.modules) on top of — never instead of — its existing
 * @RequireRole check.
 *
 * Each entry's `pattern` is matched against the WHOLE request path, with
 * `:param` segments standing in for exactly one path segment — deliberately
 * an exact match, not a prefix: several routes split by HTTP method on the
 * identical path (e.g. GET vs POST `/catalogue/stores`), and a handful of
 * sibling leaf actions under the same `/orders/:id/...` resource belong to
 * different modules entirely, so a loose prefix would either over- or
 * under-restrict them.
 *
 * A route deliberately left OUT of this table (see the "never mapped"
 * notes below) is never restricted beyond its existing @RequireRole — the
 * safe default. Two kinds of route are left out on purpose:
 *   1. Genuinely shared utility reads more than one module legitimately
 *      calls (e.g. the plain store list, the plain order list, a member's
 *      wallet card by id) — gating these to one module would 403 a
 *      legitimate call from another module's own page.
 *   2. Routes already open to "any staff role" by the backend itself
 *      (order status, appointments list from any role) — narrowing these
 *      per-module would add a restriction the role gate itself doesn't
 *      have, which isn't this feature's job.
 * A route missing here is therefore no less safe than before this feature
 * existed; it just isn't one a Super Admin can additionally dial down
 * per account.
 */
interface ModuleRoute {
  pattern: string;
  /** Restricts the match to these HTTP methods; omitted = any method. */
  methods?: string[];
  /** Allowed if the account's custom modules list includes ANY of these —
   *  more than one only where a route is a legitimate shared resource for
   *  exactly those modules (lab bookings: Lab Orders and Lab Bills both
   *  work the same underlying rows). */
  modules: string[];
}

const ROUTES: ModuleRoute[] = [
  // ---- admins ----
  { pattern: '/v1/staff/admins', modules: ['admins'] },
  { pattern: '/v1/staff/admins/:id', modules: ['admins'] },

  // ---- audit_log ----
  { pattern: '/v1/staff/audit-log', modules: ['audit_log'] },

  // ---- stores ---- (plain GET is open to any staff role — left unmapped;
  // every write is stores-only)
  { pattern: '/v1/staff/catalogue/stores', methods: ['POST'], modules: ['stores'] },
  { pattern: '/v1/staff/catalogue/stores/:id', modules: ['stores'] },
  { pattern: '/v1/staff/catalogue/stores/:id/active', modules: ['stores'] },
  { pattern: '/v1/staff/catalogue/stores/:id/offers-lab', modules: ['stores'] },
  { pattern: '/v1/staff/catalogue/contact/admin-whatsapp', modules: ['stores'] },

  // ---- products ----
  { pattern: '/v1/staff/catalogue/products', modules: ['products'] },
  { pattern: '/v1/staff/catalogue/products/:id', modules: ['products'] },
  { pattern: '/v1/staff/catalogue/products/:id/detail', modules: ['products'] },
  { pattern: '/v1/staff/catalogue/products/:id/status', modules: ['products'] },
  { pattern: '/v1/staff/catalogue/products/:id/sections', modules: ['products'] },
  { pattern: '/v1/staff/catalogue/brands', modules: ['products'] },
  { pattern: '/v1/staff/catalogue/brands/:id', modules: ['products'] },

  // ---- banners ---- (plain GET categories is shared with products — left
  // unmapped; everything else under categories/subcategories/banners is
  // this page's own)
  { pattern: '/v1/staff/catalogue/categories', methods: ['POST'], modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/categories/:id', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/categories/:id/active', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/categories/:id/sort', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/categories/:id/subcategories', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/subcategories/:id', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/banners', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/banners/:id', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/banners/:id/sort', modules: ['banners'] },
  { pattern: '/v1/staff/catalogue/banners/:id/active', modules: ['banners'] },

  // ---- customer_videos ----
  { pattern: '/v1/staff/catalogue/review-videos', modules: ['customer_videos'] },
  { pattern: '/v1/staff/catalogue/review-videos/:id', modules: ['customer_videos'] },
  { pattern: '/v1/staff/catalogue/review-video-media', modules: ['customer_videos'] },
  { pattern: '/v1/staff/catalogue/review-video-media/cleanup', modules: ['customer_videos'] },
  { pattern: '/v1/staff/catalogue/review-video-media/:id', modules: ['customer_videos'] },
  { pattern: '/v1/staff/catalogue/review-video-media/:id/chunks/:index', modules: ['customer_videos'] },
  { pattern: '/v1/staff/catalogue/review-video-media/:id/complete', modules: ['customer_videos'] },

  // ---- orders ---- (the order board is this page's own; of the per-order
  // actions under /orders/:id/*, only the ones exclusively used by the
  // Orders page are mapped — status/bill(PUT)/fulfilment-status/
  // delivery-boy/complete/invoice/the bare list stay unmapped: each is
  // either "any staff" already or genuinely shared with Bills/Deliveries)
  { pattern: '/v1/staff/order-board', modules: ['orders'] },
  { pattern: '/v1/staff/order-board/:id', modules: ['orders'] },
  { pattern: '/v1/staff/orders/:id/review', modules: ['orders'] },
  { pattern: '/v1/staff/orders/:id/converted-to-bill', modules: ['orders'] },
  { pattern: '/v1/staff/orders/:id/store-contacted', modules: ['orders'] },
  { pattern: '/v1/staff/orders/:id/picture', modules: ['orders'] },
  { pattern: '/v1/staff/orders/:id/bill', methods: ['DELETE'], modules: ['orders'] },

  // ---- bills ----
  { pattern: '/v1/staff/orders/:id/collect-wallet', modules: ['bills'] },
  { pattern: '/v1/staff/orders/:id/wallet-preview', modules: ['bills'] },
  { pattern: '/v1/staff/orders/:id/receive', modules: ['bills'] },

  // ---- prescriptions ---- (the two users/:id/* routes it also reads are
  // shared with Users — left unmapped)
  { pattern: '/v1/staff/prescriptions', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/status', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/details', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/branch', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/fulfillment', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/patient', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/images/:imageId/rotation', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/intake', modules: ['prescriptions'] },
  { pattern: '/v1/staff/prescriptions/:id/order', modules: ['prescriptions'] },

  // ---- activations + health_passes ---- (wallet-cards/member/:id is
  // shared with Users — left unmapped; wallet-cards/reserve is its own
  // module, below. The bare list and the per-member summary are shared
  // between Activations' approval queue and the Health Passes browse page.)
  { pattern: '/v1/staff/wallet-cards', modules: ['activations', 'health_passes'] },
  { pattern: '/v1/staff/wallet-cards/member/:memberId/summary', modules: ['health_passes', 'users'] },
  { pattern: '/v1/staff/wallet-cards/:id', modules: ['activations'] },
  { pattern: '/v1/staff/wallet-cards/:id/wallet-activity', modules: ['activations'] },
  { pattern: '/v1/staff/wallet-cards/:id/verification', modules: ['activations'] },
  { pattern: '/v1/staff/wallet-cards/:id/approve', modules: ['activations'] },
  { pattern: '/v1/staff/wallet-cards/:id/reject', modules: ['activations'] },
  { pattern: '/v1/staff/wallet-cards/:id/hold', modules: ['activations'] },

  // ---- agent_approvals ---- (agent-options is shared with Users — left
  // unmapped)
  { pattern: '/v1/staff/agent-requests', modules: ['agent_approvals'] },
  { pattern: '/v1/staff/agent-requests/:id', modules: ['agent_approvals'] },
  { pattern: '/v1/staff/agent-requests/:id/approve', modules: ['agent_approvals'] },
  { pattern: '/v1/staff/agent-requests/:id/reject', modules: ['agent_approvals'] },
  { pattern: '/v1/staff/agents', modules: ['agent_approvals', 'agent_portal'] },
  { pattern: '/v1/staff/agents/:id', modules: ['agent_approvals', 'agent_portal'] },
  { pattern: '/v1/staff/agents/:id/position', modules: ['agent_approvals'] },
  { pattern: '/v1/staff/agents/:id/active', modules: ['agent_approvals'] },

  // ---- agent_portal ---- (the full national-to-ward tree and each
  // agent's own money-flow detail; agent_approvals keeps edit rights —
  // see agents/:id/position and /active above)
  { pattern: '/v1/staff/agents/:id/customers', modules: ['agent_portal'] },
  { pattern: '/v1/staff/agents/:id/withdrawals', modules: ['agent_portal'] },

  // ---- agent_withdrawals ----
  { pattern: '/v1/staff/agent-withdrawals', modules: ['agent_withdrawals'] },
  { pattern: '/v1/staff/agent-withdrawals/:id/resolve', modules: ['agent_withdrawals'] },

  // ---- lab_orders + lab_bills ---- (every lab-booking route is worked
  // from both the Lab Orders and Lab Bills pages — allowed if either is
  // in the account's list)
  { pattern: '/v1/staff/lab-bookings', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/status', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/bill', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/collect-wallet', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/wallet-balance', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/details', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-staff', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/staff', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/report-pages', modules: ['lab_orders', 'lab_bills'] },
  { pattern: '/v1/staff/lab-bookings/:id/report-pages/:pageId', modules: ['lab_orders', 'lab_bills'] },

  // ---- lab_tests ----
  { pattern: '/v1/staff/lab-tests', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-tests/:id', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-categories', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-categories/:id', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-categories/:id/active', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-categories/:id/sort', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-packages', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-packages/test-picker', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-packages/:id/test-ids', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-packages/:id', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-packages/:id/active', modules: ['lab_tests'] },
  { pattern: '/v1/staff/lab-packages/:id/price', modules: ['lab_tests'] },

  // ---- appointments ---- (DashboardPage itself checks canAccess before
  // calling this, so mapping it here doesn't conflict with the dashboard
  // widget — see config/permissions.ts)
  { pattern: '/v1/staff/appointments', modules: ['appointments'] },
  { pattern: '/v1/staff/appointments/:id/status', modules: ['appointments'] },

  // ---- accounts ---- (member-transactions/:id is shared with Users —
  // left unmapped)
  { pattern: '/v1/staff/accounts/money-flow-summary', modules: ['accounts'] },
  { pattern: '/v1/staff/accounts/money-flow-entries', modules: ['accounts'] },
  { pattern: '/v1/staff/accounts/monthly-money-flow', modules: ['accounts'] },
  { pattern: '/v1/staff/accounts/member-summaries', modules: ['accounts'] },

  // ---- users ---- (the bare list is shared with Ledger — left unmapped)
  { pattern: '/v1/staff/users/:id', modules: ['users'] },
  { pattern: '/v1/staff/users/:id/detail', modules: ['users'] },
  { pattern: '/v1/staff/users/:id/convert-to-agent', modules: ['users'] },
  { pattern: '/v1/staff/users/:id/convert-to-investor', modules: ['users'] },
  { pattern: '/v1/staff/users/:id/persona', modules: ['users'] },

  // ---- deliveries ---- (fulfilment-status/delivery-boy/the delivery-boys
  // list are shared with Orders — left unmapped)
  { pattern: '/v1/staff/orders/:id/cash-collected', modules: ['deliveries'] },
  { pattern: '/v1/staff/deliveries/available', modules: ['deliveries'] },
  { pattern: '/v1/staff/deliveries/assigned-to-me', modules: ['deliveries'] },

  // ---- commission_reserve ----
  { pattern: '/v1/staff/wallet-cards/reserve', modules: ['commission_reserve'] },

  // ---- ledger ----
  { pattern: '/v1/staff/ledger/entities', modules: ['ledger'] },
  { pattern: '/v1/staff/ledger/entities/:entityId/periods/close', modules: ['ledger'] },
  { pattern: '/v1/staff/ledger/accounts', modules: ['ledger'] },
  { pattern: '/v1/staff/ledger/trial-balance', modules: ['ledger'] },
  { pattern: '/v1/staff/ledger/periods', modules: ['ledger'] },
  { pattern: '/v1/staff/ledger/subject-ledger', modules: ['ledger'] },
  { pattern: '/v1/staff/ledger/agent-commissions', modules: ['ledger'] },
];

interface CompiledRoute {
  regex: RegExp;
  methods?: string[];
  modules: string[];
}

const COMPILED: CompiledRoute[] = ROUTES.map((r) => ({
  regex: new RegExp(`^${r.pattern.replace(/:[^/]+/g, '[^/]+').replace(/\//g, '\\/')}$`),
  methods: r.methods,
  modules: r.modules,
}));

/** The module(s) a request belongs to, or undefined if this route isn't in
 *  the table (see this file's own doc on why that's the safe default). */
export function modulesForRequest(method: string, path: string): string[] | undefined {
  for (const route of COMPILED) {
    if (route.methods && !route.methods.includes(method)) continue;
    if (route.regex.test(path)) return route.modules;
  }
  return undefined;
}
