/**
 * READ-ONLY. Finds app.agent_request / app.agent rows corrupted by the
 * submitRequest bug (see agent.service.ts and dto.ts): a recruiter filling
 * in someone else's KYC form had that row's `name`/`phone` silently
 * overwritten with the recruiter's own session identity, while
 * `first_name`/`middle_name`/`last_name` (passed through untouched) stayed
 * correctly the recruit's. A row is flagged when it has a parent (recruited
 * by someone, not a self "become an agent" request) and its `name` doesn't
 * match the name its own first/middle/last would build.
 *
 * Prints what it would take to repair `name` (recoverable from
 * first/middle/last) and separately flags that `phone` cannot be recovered
 * this way — the recruit's real phone was never persisted anywhere once the
 * bug discarded it, so those need an admin to re-confirm the number by hand.
 *
 * Usage:
 *   pnpm exec ts-node scripts/find-mismatched-agent-names.ts
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { isNotNull, ne, sql } from 'drizzle-orm';
import { agent, agentRequest } from '../src/db/schema';

function loadEnvFile(path: string): void {
  let content: string;
  try {
    content = readFileSync(path, 'utf-8');
  } catch {
    return;
  }
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (!(key in process.env)) process.env[key] = value;
  }
}

const builtName = sql<string>`trim(concat_ws(' ', nullif(first_name, ''), nullif(middle_name, ''), nullif(last_name, '')))`;

async function main() {
  loadEnvFile(resolve(__dirname, '../.env.local'));
  loadEnvFile(resolve(__dirname, '../.env'));

  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set — fill it in backend/api/.env.local first.');
    process.exit(1);
  }

  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const db = drizzle(pool);

  try {
    const requests = await db
      .select({
        id: agentRequest.id,
        name: agentRequest.name,
        phone: agentRequest.phone,
        firstName: agentRequest.firstName,
        middleName: agentRequest.middleName,
        lastName: agentRequest.lastName,
        status: agentRequest.status,
        parentAgentId: agentRequest.parentAgentId,
        builtName,
      })
      .from(agentRequest)
      .where(sql`${isNotNull(agentRequest.parentAgentId)} AND ${ne(agentRequest.name, builtName)} AND ${builtName} <> ''`);

    const agents = await db
      .select({
        id: agent.id,
        name: agent.name,
        phone: agent.phone,
        firstName: agent.firstName,
        middleName: agent.middleName,
        lastName: agent.lastName,
        approvalStatus: agent.approvalStatus,
        parentId: agent.parentId,
        builtName,
      })
      .from(agent)
      .where(sql`${isNotNull(agent.parentId)} AND ${ne(agent.name, builtName)} AND ${builtName} <> ''`);

    console.log(`\napp.agent_request — ${requests.length} mismatched row(s):`);
    for (const r of requests) {
      console.log(
        `  id=${r.id} status=${r.status} parentAgentId=${r.parentAgentId}\n` +
          `    stored name: "${r.name}"  |  should be: "${r.builtName}"\n` +
          `    stored phone: "${r.phone}"  <- NOT recoverable from this row; confirm with the recruit directly`,
      );
    }

    console.log(`\napp.agent — ${agents.length} mismatched row(s):`);
    for (const a of agents) {
      console.log(
        `  id=${a.id} approvalStatus=${a.approvalStatus} parentId=${a.parentId}\n` +
          `    stored name: "${a.name}"  |  should be: "${a.builtName}"\n` +
          `    stored phone: "${a.phone}"  <- NOT recoverable from this row; confirm with the agent directly`,
      );
    }

    if (requests.length === 0 && agents.length === 0) {
      console.log('\nNo mismatched rows found.');
    } else {
      console.log(
        '\nThis was a read-only report — nothing was changed. Re-run with the companion ' +
          '--fix-names script (name only; phone still needs manual confirmation) once you\'ve reviewed these.',
      );
    }
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Failed:', err instanceof Error ? err.message : err);
  process.exit(1);
});
