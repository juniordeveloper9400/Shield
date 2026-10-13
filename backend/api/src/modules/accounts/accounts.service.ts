import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'drizzle-orm';
import { DRIZZLE, type Database } from '../../db/client';

type Row = Record<string, unknown>;

function num(value: unknown): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value.trim() !== '') return Number(value);
  return 0;
}

function isoRequired(value: unknown): string {
  if (!value) return new Date(0).toISOString();
  if (value instanceof Date) return value.toISOString();
  return String(value);
}

export type MoneyFlowKind = 'order' | 'lab_booking' | 'appointment' | 'privilege_load' | 'agent_payout';

/**
 * Ported from shieldweb's `src/api/accounts.ts` — the console's Accounts
 * page used to run these five queries directly against Neon from the
 * browser. Read-only: nothing here writes anything. SQL kept verbatim
 * (same tables, same CANCELLED/PENDING exclusions) rather than rewritten
 * against the Drizzle query builder, so this is a straight move of where
 * the query runs, not a reimplementation of the business logic.
 */
@Injectable()
export class AccountsService {
  constructor(@Inject(DRIZZLE) private readonly db: Database) {}

  async getMoneyFlowSummary() {
    const result = await this.db.execute<Row>(sql`
      SELECT
        COALESCE((SELECT SUM(paid_total) FROM app."order" WHERE status <> 'CANCELLED'), 0) AS orders_total,
        COALESCE((SELECT COUNT(*) FROM app."order" WHERE status <> 'CANCELLED'), 0) AS orders_count,
        COALESCE((SELECT SUM(total_price) FROM app.lab_booking WHERE status <> 'CANCELLED'), 0) AS lab_total,
        COALESCE((SELECT COUNT(*) FROM app.lab_booking WHERE status <> 'CANCELLED'), 0) AS lab_count,
        COALESCE((SELECT SUM(fee) FROM app.appointment WHERE status <> 'CANCELLED' AND fee IS NOT NULL), 0) AS appt_total,
        COALESCE((SELECT COUNT(*) FROM app.appointment WHERE status <> 'CANCELLED' AND fee IS NOT NULL AND fee > 0), 0) AS appt_count,
        COALESCE((SELECT SUM(amount) FROM app.wallet_card WHERE status = 'APPROVED'), 0) AS privilege_total,
        COALESCE((SELECT COUNT(*) FROM app.wallet_card WHERE status = 'APPROVED'), 0) AS privilege_count,
        COALESCE((SELECT SUM(amount) FROM app.agent_withdrawal WHERE status = 'PAID'), 0) AS agent_paid_total,
        COALESCE((SELECT COUNT(*) FROM app.agent_withdrawal WHERE status = 'PAID'), 0) AS agent_paid_count,
        COALESCE((SELECT SUM(amount) FROM app.agent_withdrawal WHERE status = 'PENDING'), 0) AS agent_pending_total,
        COALESCE((SELECT COUNT(*) FROM app.agent_withdrawal WHERE status = 'PENDING'), 0) AS agent_pending_count,
        COALESCE((SELECT SUM(balance) FROM app.wallet), 0) AS wallet_liability
    `);
    const r = result.rows[0] ?? {};

    const revenue = {
      ordersTotal: num(r.orders_total),
      ordersCount: num(r.orders_count),
      labBookingsTotal: num(r.lab_total),
      labBookingsCount: num(r.lab_count),
      appointmentsTotal: num(r.appt_total),
      appointmentsCount: num(r.appt_count),
      privilegeLoadsTotal: num(r.privilege_total),
      privilegeLoadsCount: num(r.privilege_count),
      total: 0,
    };
    revenue.total =
      revenue.ordersTotal + revenue.labBookingsTotal + revenue.appointmentsTotal + revenue.privilegeLoadsTotal;

    const payouts = {
      agentWithdrawalsTotal: num(r.agent_paid_total),
      agentWithdrawalsCount: num(r.agent_paid_count),
      total: num(r.agent_paid_total),
    };

    return {
      revenue,
      payouts,
      net: revenue.total - payouts.total,
      walletLiability: num(r.wallet_liability),
      pendingAgentWithdrawalsTotal: num(r.agent_pending_total),
      pendingAgentWithdrawalsCount: num(r.agent_pending_count),
    };
  }

  async listMoneyFlowEntries(limit = 50) {
    const result = await this.db.execute<Row>(sql`
      SELECT * FROM (
        SELECT o.id::text AS id, 'order' AS kind, 'in' AS direction,
               o.paid_total AS amount, o.placed_at AS occurred_at,
               o.code AS label, COALESCE(m.name, '—') AS detail
          FROM app."order" o
          LEFT JOIN app.users m ON m.id = o.member_id
         WHERE o.status <> 'CANCELLED'

        UNION ALL

        SELECT lb.id::text, 'lab_booking', 'in',
               lb.total_price, lb.created_at,
               'LB-' || lpad(lb.id::text, 4, '0'), COALESCE(m.name, '—')
          FROM app.lab_booking lb
          LEFT JOIN app.users m ON m.id = lb.member_id
         WHERE lb.status <> 'CANCELLED' AND lb.total_price > 0

        UNION ALL

        SELECT a.id::text, 'appointment', 'in',
               a.fee, a.created_at,
               COALESCE(a.doctor_name, 'Appointment'), COALESCE(m.name, '—')
          FROM app.appointment a
          LEFT JOIN app.users m ON m.id = a.member_id
         WHERE a.status <> 'CANCELLED' AND a.fee IS NOT NULL AND a.fee > 0

        UNION ALL

        SELECT wc.id::text, 'privilege_load', 'in',
               wc.amount, COALESCE(wc.reviewed_at, wc.submitted_at),
               mt.name, COALESCE(m.name, '—')
          FROM app.wallet_card wc
          JOIN app.wallet w      ON w.id  = wc.wallet_id
          JOIN app.users m       ON m.id  = w.member_id
          JOIN app.membership_tier mt ON mt.id = wc.tier_id
         WHERE wc.status = 'APPROVED'

        UNION ALL

        SELECT aw.id::text, 'agent_payout', 'out',
               aw.amount, COALESCE(aw.processed_on::timestamptz, aw.created_at),
               'Agent payout', COALESCE(ag.name, '—')
          FROM app.agent_withdrawal aw
          JOIN app.agent ag ON ag.id = aw.agent_id
         WHERE aw.status = 'PAID'
      ) flow
      ORDER BY occurred_at DESC
      LIMIT ${limit}
    `);
    return result.rows.map(toMoneyFlowEntry);
  }

  async listMemberTransactions(memberId: number, limit = 200) {
    const result = await this.db.execute<Row>(sql`
      SELECT * FROM (
        SELECT o.id::text AS id, 'order' AS kind, 'in' AS direction,
               o.paid_total AS amount, o.placed_at AS occurred_at,
               o.code AS label,
               CASE o.kind WHEN 'PRESCRIPTION' THEN 'Prescription order' ELSE 'Standard order' END AS detail
          FROM app."order" o
         WHERE o.status <> 'CANCELLED' AND o.member_id = ${memberId}

        UNION ALL

        SELECT lb.id::text, 'lab_booking', 'in',
               lb.total_price, lb.created_at,
               'LB-' || lpad(lb.id::text, 4, '0'), 'Lab test booking'
          FROM app.lab_booking lb
         WHERE lb.status <> 'CANCELLED' AND lb.total_price > 0 AND lb.member_id = ${memberId}

        UNION ALL

        SELECT a.id::text, 'appointment', 'in',
               a.fee, a.created_at,
               COALESCE(a.doctor_name, 'Appointment'), 'Consultation fee'
          FROM app.appointment a
         WHERE a.status <> 'CANCELLED' AND a.fee IS NOT NULL AND a.fee > 0 AND a.member_id = ${memberId}

        UNION ALL

        SELECT wc.id::text, 'privilege_load', 'in',
               wc.amount, COALESCE(wc.reviewed_at, wc.submitted_at),
               mt.name, 'Health Pass plan load'
          FROM app.wallet_card wc
          JOIN app.wallet w            ON w.id  = wc.wallet_id
          JOIN app.membership_tier mt  ON mt.id = wc.tier_id
         WHERE wc.status = 'APPROVED' AND w.member_id = ${memberId}

        UNION ALL

        SELECT aw.id::text, 'agent_payout', 'out',
               aw.amount, COALESCE(aw.processed_on::timestamptz, aw.created_at),
               'Agent payout', 'Commission withdrawal'
          FROM app.agent_withdrawal aw
          JOIN app.agent ag ON ag.id = aw.agent_id
         WHERE aw.status = 'PAID' AND ag.member_id = ${memberId}
      ) flow
      ORDER BY occurred_at DESC
      LIMIT ${limit}
    `);
    return result.rows.map(toMoneyFlowEntry);
  }

  /**
   * Buckets by calendar month in JS rather than SQL's `date_trunc`/`now()`/
   * `interval` — same sources and exclusions as the SQL version this
   * replaces, just with the grouping done after the fetch. Keeps this
   * query portable (no reliance on Postgres-specific date arithmetic) and
   * lets a single cutoff timestamp (computed once, here) define the
   * window instead of a moving `now()` evaluated inside the query.
   */
  async getMonthlyMoneyFlow(months = 6) {
    const now = new Date();
    const cutoff = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (months - 1), 1));

    const result = await this.db.execute<Row>(sql`
      SELECT d AS occurred_at, 'in' AS direction, amt AS amount
        FROM (
          SELECT placed_at AS d, paid_total AS amt FROM app."order" WHERE status <> 'CANCELLED'
          UNION ALL
          SELECT created_at, total_price FROM app.lab_booking WHERE status <> 'CANCELLED'
          UNION ALL
          SELECT created_at, fee FROM app.appointment
           WHERE status <> 'CANCELLED' AND fee IS NOT NULL AND fee > 0
          UNION ALL
          SELECT COALESCE(reviewed_at, submitted_at), amount
            FROM app.wallet_card WHERE status = 'APPROVED'
        ) sources
       WHERE d >= ${cutoff}

      UNION ALL

      SELECT COALESCE(processed_on::timestamptz, created_at), 'out', amount
        FROM app.agent_withdrawal
       WHERE status = 'PAID' AND COALESCE(processed_on::timestamptz, created_at) >= ${cutoff}
    `);

    const buckets = new Map<string, { in: number; out: number }>();
    const keyOf = (d: Date) => `${d.getUTCFullYear()}-${d.getUTCMonth()}`;
    const labelOf = (d: Date) => d.toLocaleDateString('en-IN', { month: 'short', year: 'numeric', timeZone: 'UTC' });

    const order: { key: string; label: string }[] = [];
    for (let i = months - 1; i >= 0; i -= 1) {
      const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
      const key = keyOf(d);
      order.push({ key, label: labelOf(d) });
      buckets.set(key, { in: 0, out: 0 });
    }

    for (const r of result.rows) {
      const d = new Date(String(r.occurred_at));
      const key = keyOf(d);
      const bucket = buckets.get(key);
      if (!bucket) continue; // outside the requested window (shouldn't happen given the cutoff filter)
      if (r.direction === 'in') bucket.in += num(r.amount);
      else bucket.out += num(r.amount);
    }

    return order.map(({ key, label }) => ({ month: label, ...buckets.get(key)! }));
  }

  async listMemberMoneyFlowSummaries() {
    const result = await this.db.execute<Row>(sql`
      WITH money_in AS (
        SELECT member_id, SUM(amt) AS total, COUNT(*) AS cnt
          FROM (
            SELECT member_id, paid_total AS amt
              FROM app."order" WHERE status <> 'CANCELLED'
            UNION ALL
            SELECT member_id, total_price
              FROM app.lab_booking WHERE status <> 'CANCELLED' AND total_price > 0
            UNION ALL
            SELECT member_id, fee
              FROM app.appointment WHERE status <> 'CANCELLED' AND fee IS NOT NULL AND fee > 0
            UNION ALL
            SELECT w.member_id, wc.amount
              FROM app.wallet_card wc
              JOIN app.wallet w ON w.id = wc.wallet_id
             WHERE wc.status = 'APPROVED'
          ) sources
         GROUP BY member_id
      ),
      money_out AS (
        SELECT ag.member_id, SUM(aw.amount) AS total, COUNT(*) AS cnt
          FROM app.agent_withdrawal aw
          JOIN app.agent ag ON ag.id = aw.agent_id
         WHERE aw.status = 'PAID'
         GROUP BY ag.member_id
      )
      SELECT u.id, u.name, u.phone, u.email,
             COALESCE(mi.total, 0) AS money_in, COALESCE(mi.cnt, 0) AS money_in_count,
             COALESCE(mo.total, 0) AS money_out, COALESCE(mo.cnt, 0) AS money_out_count,
             COALESCE(w.balance, 0) AS wallet_balance
        FROM app.users u
        LEFT JOIN money_in mi  ON mi.member_id = u.id
        LEFT JOIN money_out mo ON mo.member_id = u.id
        LEFT JOIN app.wallet w ON w.member_id = u.id
       WHERE COALESCE(mi.total, 0) > 0
          OR COALESCE(mo.total, 0) > 0
          OR COALESCE(w.balance, 0) > 0
       ORDER BY COALESCE(mi.total, 0) DESC
    `);

    return result.rows.map((r) => ({
      id: String(r.id),
      name: String(r.name ?? '—'),
      phone: String(r.phone ?? ''),
      email: String(r.email ?? ''),
      moneyIn: num(r.money_in),
      moneyInCount: num(r.money_in_count),
      moneyOut: num(r.money_out),
      moneyOutCount: num(r.money_out_count),
      walletBalance: num(r.wallet_balance),
    }));
  }
}

function toMoneyFlowEntry(r: Row) {
  return {
    id: `${String(r.kind)}-${String(r.id)}`,
    kind: r.kind as MoneyFlowKind,
    direction: r.direction as 'in' | 'out',
    amount: num(r.amount),
    label: String(r.label),
    detail: String(r.detail),
    occurredAt: isoRequired(r.occurred_at),
  };
}
