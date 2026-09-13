/**
 * Creates (or resets the password of) one app.admin_user row directly — the
 * only way to get the FIRST staff account in, since POST /v1/staff/admins
 * itself requires an existing SUPERADMIN session (see
 * backend/docs/build-playbook.md M9). Once at least one SUPERADMIN exists,
 * use the real API for every account after this.
 *
 * Staff log in with a login id (a short handle, e.g. 'pharmacy_mel' — not
 * an email) + password (see auth.service.ts loginStaff) — no Firebase
 * account needed for staff at all; the password is bcrypt-hashed here
 * before it ever touches the database.
 *
 * Usage:
 *   pnpm seed:staff -- --login-id=superadmin --name="Your Name" --password=... --role=SUPERADMIN
 *   pnpm seed:staff -- --login-id=pharmacy_mel --name="Melattur Pharmacist" --password=... --role=PHARMACY --store=SHD-MEL
 *
 * Running it again for a login id that already exists resets that
 * account's password to the one given (everything else about the row is
 * left alone).
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { hash } from 'bcryptjs';
import { Pool } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { eq } from 'drizzle-orm';
import { adminUser, shieldStore } from '../src/db/schema';

type Role = 'SUPERADMIN' | 'ADMIN' | 'PHARMACY' | 'LAB' | 'APPOINTMENTS';
const VALID_ROLES: Role[] = ['SUPERADMIN', 'ADMIN', 'PHARMACY', 'LAB', 'APPOINTMENTS'];
const BCRYPT_ROUNDS = 12;

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
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
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
  const loginId = args['login-id']?.trim();
  const name = args.name?.trim();
  const password = args.password;
  const roleArg = (args.role ?? 'SUPERADMIN').toUpperCase();
  const storeCode = args.store?.trim();

  if (!loginId || !name || !password) {
    console.error(
      'Usage: pnpm seed:staff -- --login-id=superadmin --name="Your Name" --password=... ' +
        '[--role=SUPERADMIN|ADMIN|PHARMACY|LAB|APPOINTMENTS] [--store=SHD-MEL]',
    );
    process.exit(1);
  }
  if (password.length < 8) {
    console.error('--password must be at least 8 characters.');
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

    const passwordHash = await hash(password, BCRYPT_ROUNDS);
    const [existing] = await db.select({ id: adminUser.id }).from(adminUser).where(eq(adminUser.loginId, loginId)).limit(1);

    if (existing) {
      await db.update(adminUser).set({ passwordHash }).where(eq(adminUser.id, existing.id));
      console.log(`Account for "${loginId}" already existed (id ${existing.id}) — password reset to the one given.`);
      return;
    }

    const [created] = await db
      .insert(adminUser)
      .values({ loginId, name, passwordHash, role: roleArg, storeId })
      .returning({ id: adminUser.id, loginId: adminUser.loginId, role: adminUser.role });
    console.log(
      `Created staff account: id=${created.id}, loginId=${created.loginId}, role=${created.role}` +
        (storeCode ? `, store=${storeCode}` : ''),
    );
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error('Failed:', err instanceof Error ? err.message : err);
  process.exit(1);
});
