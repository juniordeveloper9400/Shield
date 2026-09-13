/**
 * Creates one app.admin_user row directly — the only way to get the FIRST
 * staff account in, since POST /v1/staff/admins itself requires an existing
 * SUPERADMIN session (see backend/docs/build-playbook.md M9). Once at least
 * one SUPERADMIN exists, use the real API for every account after this.
 *
 * firebase_uid is deliberately left unset — it links automatically on this
 * account's first login (see auth.service.ts exchangeStaffToken), the same
 * way it always has.
 *
 * Usage:
 *   pnpm seed:staff -- --email=you@example.com --name="Your Name" --role=SUPERADMIN
 *   pnpm seed:staff -- --email=pharmacist@example.com --name="Melattur Pharmacist" --role=PHARMACY --store=SHD-MEL
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { eq } from 'drizzle-orm';
import { adminUser, shieldStore } from '../src/db/schema';

type Role = 'SUPERADMIN' | 'ADMIN' | 'PHARMACY' | 'LAB' | 'APPOINTMENTS';
const VALID_ROLES: Role[] = ['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS'];

function loadEnvFile(path: string): void {
  let content: string;
  try {
    content = readFileSync(path, 'utf-8');
  } catch {
    return; // fine — the file is optional, real env vars may already be set
  }
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    if (!(key in process.env)) process.env[key] = value;
  }
}

function parseArgs(): Record<string, string> {
  const args: Record<string, string> = {};
  for (const arg of process.argv.slice(2)) {
    const match = /^--([^=]+)=(.*)$/.exec(arg);
    if (match) args[match[1]] = match[2];
  }
  return args;
}

function isRole(value: string): value is Role {
  return (VALID_ROLES as string[]).includes(value);
}

async function main() {
  loadEnvFile(resolve(__dirname, '../.env.local'));
  loadEnvFile(resolve(__dirname, '../.env'));

  const args = parseArgs();
  const email = args.email?.trim();
  const name = args.name?.trim();
  const roleArg = (args.role ?? 'SUPERADMIN').toUpperCase();
  const storeCode = args.store?.trim();

  if (!email || !name) {
    console.error(
      'Usage: pnpm seed:staff -- --email=you@example.com --name="Your Name" ' +
        '[--role=SUPERADMIN|ADMIN|PHARMACY|LAB|APPOINTMENTS] [--store=SHD-MEL]',
    );
    process.exit(1);
  }
  if (!isRole(roleArg)) {
    console.error(`--role must be one of: ${VALID_ROLES.join(', ')}`);
    process.exit(1);
  }
  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is not set — fill it in backend/api/.env.local first.');
    process.exit(1);
  }

  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const db = drizzle(pool);

  try {
    let storeId: number | undefined;
    if (storeCode) {
      const [store] = await db.select({ id: shieldStore.id }).from(shieldStore).where(eq(shieldStore.code, storeCode)).limit(1);
      if (!store) {
        console.error(`No app.shield_store with code "${storeCode}" was found.`);
        process.exitCode = 1;
        return;
      }
      storeId = store.id;
    }

    const [existing] = await db.select({ id: adminUser.id }).from(adminUser).where(eq(adminUser.email, email)).limit(1);
    if (existing) {
      console.log(`A staff account for ${email} already exists (id ${existing.id}) — nothing to do.`);
      return;
    }

    const [created] = await db.insert(adminUser).values({ email, name, role: roleArg, storeId }).returning();
    console.log(
      `Created staff account: id=${created.id}, email=${created.email}, role=${created.role}` +
        (storeCode ? `, store=${storeCode}` : ''),
    );
    console.log("firebase_uid is not set — it links automatically the first time this account signs in.");
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Failed:', err instanceof Error ? err.message : err);
  process.exit(1);
});
