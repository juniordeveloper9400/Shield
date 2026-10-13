import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { PGlite } from '../../../.buildlog/pg-delete-test/node_modules/@electric-sql/pglite/dist/index.js';
import { pg_trgm } from '../../../.buildlog/pg-delete-test/node_modules/@electric-sql/pglite/dist/contrib/pg_trgm.js';

const migration = new URL('../migrations/0089_permanent_member_delete.sql', import.meta.url);

async function fixture() {
  const db = new PGlite();
  await db.exec(`
    CREATE SCHEMA app; CREATE SCHEMA backend;
    CREATE TABLE app.admin_user(id bigint PRIMARY KEY, role text, is_active boolean);
    CREATE TABLE backend.auth_session(id uuid PRIMARY KEY, subject_type text, subject_id text, revoked_at timestamptz, expires_at timestamptz);
    CREATE TABLE backend.refresh_token(id bigint PRIMARY KEY, session_id uuid REFERENCES backend.auth_session ON DELETE CASCADE);
    CREATE TABLE app.users(id bigserial PRIMARY KEY, phone text UNIQUE, name text, referred_by_member_id bigint REFERENCES app.users ON DELETE SET NULL);
    CREATE TABLE app.wallet(id bigint PRIMARY KEY, member_id bigint NOT NULL REFERENCES app.users ON DELETE CASCADE, balance numeric);
    CREATE TABLE app.wallet_card(id bigint PRIMARY KEY, wallet_id bigint NOT NULL REFERENCES app.wallet ON DELETE CASCADE);
    CREATE TABLE app.commission_reserve_entry(id bigint PRIMARY KEY, wallet_card_id bigint NOT NULL REFERENCES app.wallet_card);
    CREATE TABLE app.patient(id bigint PRIMARY KEY, member_id bigint NOT NULL REFERENCES app.users ON DELETE CASCADE);
    CREATE TABLE app.prescription(id bigint PRIMARY KEY, member_id bigint NOT NULL REFERENCES app.users ON DELETE CASCADE, patient_id bigint REFERENCES app.patient ON DELETE RESTRICT);
    CREATE TABLE app.lab_booking(id bigint PRIMARY KEY,member_id bigint NOT NULL REFERENCES app.users ON DELETE CASCADE);
    CREATE TABLE app.wallet_entry(id bigint PRIMARY KEY,wallet_id bigint NOT NULL REFERENCES app.wallet ON DELETE CASCADE,lab_booking_id bigint REFERENCES app.lab_booking);
    CREATE TABLE app.agent(id bigint PRIMARY KEY, member_id bigint REFERENCES app.users ON DELETE SET NULL, parent_id bigint REFERENCES app.agent ON DELETE SET NULL, phone text DEFAULT '');
    CREATE TABLE app.region(id bigint PRIMARY KEY, agent_id bigint REFERENCES app.agent ON DELETE SET NULL);
    CREATE TABLE app.agent_customer(id bigint PRIMARY KEY, agent_id bigint REFERENCES app.agent ON DELETE CASCADE, member_id bigint REFERENCES app.users ON DELETE SET NULL, phone text DEFAULT '');
    CREATE TABLE app.agent_request(id bigint PRIMARY KEY, phone text, agent_id bigint REFERENCES app.agent ON DELETE SET NULL);
    CREATE TABLE app.referral(id bigint PRIMARY KEY, inviter_member_id bigint NOT NULL REFERENCES app.users ON DELETE CASCADE, invitee_member_id bigint REFERENCES app.users ON DELETE SET NULL, invitee_phone text);
    CREATE TABLE app.journal_entry(id uuid PRIMARY KEY, source_table text, source_id text, reversal_of uuid REFERENCES app.journal_entry, reversed_by uuid REFERENCES app.journal_entry);
    CREATE TABLE app.journal_line(id bigint PRIMARY KEY, entry_id uuid NOT NULL REFERENCES app.journal_entry ON DELETE CASCADE);
    INSERT INTO app.admin_user VALUES (1,'ADMIN',true),(2,'PHARMACY',true);
    INSERT INTO backend.auth_session VALUES
      ('00000000-0000-0000-0000-000000000001','STAFF','1',null,now()+interval '1 day'),
      ('00000000-0000-0000-0000-000000000002','STAFF','2',null,now()+interval '1 day'),
      ('00000000-0000-0000-0000-000000000003','MEMBER','1',null,now()+interval '1 day');
    INSERT INTO backend.refresh_token VALUES(1,'00000000-0000-0000-0000-000000000003');
    INSERT INTO app.users(phone,name) VALUES('9000000001','Delete me'),('9000000002','Keep me');
    UPDATE app.users SET referred_by_member_id=1 WHERE id=2;
    INSERT INTO app.wallet VALUES(1,1,900),(2,2,300);
    INSERT INTO app.wallet_card VALUES(1,1),(2,2);
    INSERT INTO app.commission_reserve_entry VALUES(1,1),(2,2);
    INSERT INTO app.patient VALUES(1,1),(2,2);
    INSERT INTO app.prescription VALUES(1,1,1),(2,2,2),(3,2,1);
    INSERT INTO app.lab_booking VALUES(1,1);
    INSERT INTO app.wallet_entry VALUES(1,1,1),(2,2,1);
    INSERT INTO app.agent(id,member_id,parent_id) VALUES(1,1,null),(2,2,1);
    INSERT INTO app.region VALUES(1,1);
    INSERT INTO app.agent_customer(id,agent_id,member_id) VALUES(1,2,1);
    INSERT INTO app.agent_request VALUES(1,'9000000001',1);
    INSERT INTO app.referral VALUES(1,2,1,'9000000001');
    INSERT INTO app.journal_entry VALUES('10000000-0000-0000-0000-000000000001','wallet_card','1',null,null),('10000000-0000-0000-0000-000000000002','wallet_card','2',null,null);
    INSERT INTO app.journal_line VALUES(1,'10000000-0000-0000-0000-000000000001'),(2,'10000000-0000-0000-0000-000000000002');
  `);
  await db.exec(await readFile(migration, 'utf8'));
  return db;
}

test('permanent deletion removes owned data/sessions and permits fresh registration without harming peers', async () => {
  const db = await fixture();
  try {
    await db.query(`SELECT app.permanently_delete_member(1, '00000000-0000-0000-0000-000000000001')`);
    for (const table of ['users','wallet','wallet_card','commission_reserve_entry','patient','prescription','agent']) {
      assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.${table} WHERE id=1`)).rows[0].n, 0, table);
    }
    for (const table of ['agent_customer','agent_request','referral']) assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.${table}`)).rows[0].n,0,table);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM backend.auth_session WHERE subject_type='MEMBER'`)).rows[0].n,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM backend.refresh_token`)).rows[0].n,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.journal_line`)).rows[0].n,1);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.journal_entry`)).rows[0].n,1);
    assert.equal((await db.query(`SELECT balance FROM app.wallet WHERE id=2`)).rows[0].balance,'300');
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.prescription WHERE id=3`)).rows[0].n,1);
    assert.equal((await db.query(`SELECT patient_id FROM app.prescription WHERE id=3`)).rows[0].patient_id,null);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.wallet_entry WHERE id=2`)).rows[0].n,1);
    assert.equal((await db.query(`SELECT lab_booking_id FROM app.wallet_entry WHERE id=2`)).rows[0].lab_booking_id,null);
    assert.equal((await db.query(`SELECT parent_id FROM app.agent WHERE id=2`)).rows[0].parent_id,null);
    assert.equal((await db.query(`SELECT agent_id FROM app.region WHERE id=1`)).rows[0].agent_id,null);
    const fresh = (await db.query(`INSERT INTO app.users(phone,name) VALUES('9000000001','New member') RETURNING id`)).rows[0];
    assert.notEqual(fresh.id,1);
  } finally { await db.close(); }
});

test('branch staff cannot purge members', async () => {
  const db = await fixture();
  try {
    await assert.rejects(db.query(`SELECT app.permanently_delete_member(1, '00000000-0000-0000-0000-000000000002')`));
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.users`)).rows[0].n,2);
  } finally { await db.close(); }
});

test('a required peer link cancels deletion rather than cascading through another member', async () => {
  const db = await fixture();
  try {
    await db.exec('ALTER TABLE app.prescription ALTER COLUMN patient_id SET NOT NULL');
    await assert.rejects(db.query(`SELECT app.permanently_delete_member(1,'00000000-0000-0000-0000-000000000001')`), /surviving member record/);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM app.users WHERE id=1')).rows[0].n,1);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM app.prescription WHERE id=3')).rows[0].n,1);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM backend.refresh_token')).rows[0].n,1);
  } finally { await db.close(); }
});

test('a child deletion failure rolls back profile, sessions and all dependent records', async () => {
  const db = await fixture();
  try {
    await db.exec(`CREATE FUNCTION app.reject_delete() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'blocked fixture'; END $$; CREATE TRIGGER reject_delete BEFORE DELETE ON app.wallet FOR EACH ROW EXECUTE FUNCTION app.reject_delete();`);
    await assert.rejects(db.query(`SELECT app.permanently_delete_member(1, '00000000-0000-0000-0000-000000000001')`), /blocked fixture/);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.users WHERE id=1`)).rows[0].n,1);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM backend.refresh_token`)).rows[0].n,1);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.prescription WHERE id=1`)).rows[0].n,1);
  } finally { await db.close(); }
});

test('deletion works against the repository app schema and fresh users have no old profile or wallet', async () => {
  const db = new PGlite({ extensions: { pg_trgm } });
  try {
    await db.exec(await readFile(new URL('../app_schema.sql',import.meta.url),'utf8'));
    await db.exec(`CREATE SCHEMA backend; CREATE TABLE backend.auth_session(id uuid PRIMARY KEY, subject_type text, subject_id text, revoked_at timestamptz, expires_at timestamptz);
      INSERT INTO app.admin_user(login_id,name,role) VALUES('purge-admin','Purge Admin','SUPERADMIN');
      INSERT INTO backend.auth_session VALUES('00000000-0000-0000-0000-000000000001','STAFF','1',null,now()+interval '1 day');
      INSERT INTO app.users(phone,name,address,registration_completed_at,reward_points) VALUES('9000000001','Old member','Old address',now(),500),('9000000002','Peer',null,null,0);
      INSERT INTO app.wallet(member_id,balance) VALUES(1,800),(2,300);
      INSERT INTO app.cart(member_id) VALUES(1),(2);
      INSERT INTO app."order"(member_id,code,payment_status) VALUES(1,'DELETE-ORDER','PAID'),(2,'KEEP-ORDER','PAID');
      INSERT INTO app.bill(order_id,image,amount,status) VALUES(1,'',125,'PAID'),(2,'',75,'PAID');
      INSERT INTO app.bill_line(bill_id,name,unit_price) VALUES(1,'Deleted purchase',125),(2,'Peer purchase',75);`);
    await db.exec(await readFile(migration,'utf8'));
    await db.query(`SELECT app.permanently_delete_member(1,'00000000-0000-0000-0000-000000000001')`);
    const fresh=(await db.query(`INSERT INTO app.users(phone,name) VALUES('9000000001','New member') RETURNING id,address,registration_completed_at,reward_points`)).rows[0];
    assert.notEqual(Number(fresh.id),1);
    assert.equal(fresh.address,null);
    assert.equal(fresh.registration_completed_at,null);
    assert.equal(fresh.reward_points,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.wallet WHERE member_id=$1`,[fresh.id])).rows[0].n,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.cart WHERE member_id=1`)).rows[0].n,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.bill_line WHERE bill_id=1`)).rows[0].n,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app.bill WHERE id=1`)).rows[0].n,0);
    assert.equal((await db.query(`SELECT count(*)::int AS n FROM app."order" WHERE member_id=1`)).rows[0].n,0);
    assert.equal((await db.query(`SELECT amount FROM app.bill WHERE id=2`)).rows[0].amount,'75.00');
    assert.equal((await db.query(`SELECT balance FROM app.wallet WHERE member_id=2`)).rows[0].balance,'300.00');
  } finally { await db.close(); }
});
