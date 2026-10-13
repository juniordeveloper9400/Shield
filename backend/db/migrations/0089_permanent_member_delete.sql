-- Permanent admin deletion. Installing this function does not delete data.
-- Invocation irreversibly erases the member's owned rows, sessions and journal
-- history; reports change. Run only through the authenticated admin endpoint.
-- Shared users, geography, stores and another agent's subtree are preserved.
BEGIN;

CREATE OR REPLACE FUNCTION app.permanently_delete_member(
  p_member_id bigint, p_staff_session uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog, app, backend AS $$
DECLARE
  member_phone text;
  relation record;
  fk record;
  inserted_count integer;
  changed integer;
  ownership_filter text;
  has_shared_rows boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM backend.auth_session s
    JOIN app.admin_user a ON s.subject_id = a.id::text
    WHERE s.id = p_staff_session AND s.subject_type::text = 'STAFF'
      AND s.revoked_at IS NULL AND s.expires_at > now()
      AND a.is_active AND a.role::text IN ('ADMIN', 'SUPERADMIN')
  ) THEN
    RAISE EXCEPTION 'Only an active Admin or Super Admin may permanently delete members'
      USING ERRCODE = '42501';
  END IF;

  SELECT phone INTO member_phone FROM app.users WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;

  CREATE TEMP TABLE IF NOT EXISTS member_purge_rows (
    relation_id oid NOT NULL, row_id text NOT NULL, depth integer NOT NULL,
    PRIMARY KEY(relation_id, row_id)
  ) ON COMMIT DROP;
  TRUNCATE pg_temp.member_purge_rows;
  INSERT INTO pg_temp.member_purge_rows VALUES ('app.users'::regclass, p_member_id::text, 0);

  -- Ownership columns, including relationships whose FK would only SET NULL.
  FOR relation IN
    SELECT c.oid, c.relname, a.attname FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_attribute a ON a.attrelid=c.oid
    WHERE n.nspname='app' AND c.relkind='r' AND NOT a.attisdropped
      AND a.attname IN ('member_id','user_id','inviter_member_id','invitee_member_id')
  LOOP
    EXECUTE format(
      'INSERT INTO pg_temp.member_purge_rows SELECT %s, id::text, 1 FROM %s WHERE %I=$1 ON CONFLICT DO NOTHING',
      relation.oid, relation.oid::regclass, relation.attname
    ) USING p_member_id;
  END LOOP;

  -- Registration requests and detached legacy personas have phone ownership.
  FOR relation IN
    SELECT c.oid, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='app' AND c.relname IN ('agent_request','agent','investor','agent_customer')
  LOOP
    EXECUTE format(
      'INSERT INTO pg_temp.member_purge_rows SELECT %s,id::text,1 FROM %s WHERE right(regexp_replace(phone,''[^0-9]'','''',''g''),10)=right(regexp_replace($1,''[^0-9]'','''',''g''),10) %s ON CONFLICT DO NOTHING',
      relation.oid, relation.oid::regclass,
      CASE WHEN relation.relname='agent_request' THEN '' ELSE 'AND (member_id IS NULL OR member_id=$2)' END
    ) USING member_phone, p_member_id;
  END LOOP;
  INSERT INTO pg_temp.member_purge_rows
    SELECT 'backend.auth_session'::regclass,id::text,1 FROM backend.auth_session
    WHERE subject_type::text='MEMBER' AND subject_id=p_member_id::text ON CONFLICT DO NOTHING;

  -- Follow owned FK dependants. SET NULL links point to shared rows, so leave
  -- those rows intact and let PostgreSQL detach them when their parent goes.
  LOOP
    changed := 0;
    FOR fk IN
      SELECT con.conrelid, con.confrelid, child.attname AS child_column,
             parent.attname AS parent_column
      FROM pg_constraint con
      JOIN pg_attribute child ON child.attrelid=con.conrelid AND child.attnum=con.conkey[1]
      JOIN pg_attribute parent ON parent.attrelid=con.confrelid AND parent.attnum=con.confkey[1]
      WHERE con.contype='f' AND con.confdeltype IN ('c','a','r')
        AND cardinality(con.conkey)=1 AND parent.attname='id'
        AND EXISTS(SELECT 1 FROM pg_temp.member_purge_rows WHERE relation_id=con.confrelid)
    LOOP
      -- A restrictive FK is a reference, not proof of ownership. Protect
      -- another member's primary records, and financial rows in their wallet.
      SELECT coalesce(string_agg(format(' AND (c.%I IS NULL OR c.%I=$1)',a.attname,a.attname),''),'')
        INTO ownership_filter FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
        WHERE a.attrelid=fk.conrelid AND NOT a.attisdropped
          AND a.attname IN ('member_id','user_id')
          AND c.relname NOT IN ('agent_customer','referral');
      IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=fk.conrelid AND attname='wallet_id' AND NOT attisdropped) THEN
        ownership_filter := ownership_filter || ' AND EXISTS(SELECT 1 FROM app.wallet w WHERE w.id=c.wallet_id AND w.member_id=$1)';
      END IF;
      EXECUTE format(
        'INSERT INTO pg_temp.member_purge_rows SELECT %s,c.id::text,p.depth+1 FROM %s c JOIN pg_temp.member_purge_rows p ON p.relation_id=%s AND c.%I::text=p.row_id WHERE true %s ON CONFLICT DO NOTHING',
        fk.conrelid, fk.conrelid::regclass, fk.confrelid, fk.child_column, ownership_filter
      ) USING p_member_id;
      GET DIAGNOSTICS inserted_count = ROW_COUNT;
      changed := changed + inserted_count;
    END LOOP;
    IF to_regclass('app.journal_entry') IS NOT NULL THEN
      INSERT INTO pg_temp.member_purge_rows
        SELECT 'app.journal_entry'::regclass,j.id::text,p.depth+1
        FROM app.journal_entry j JOIN pg_temp.member_purge_rows p ON p.row_id=j.source_id
        JOIN pg_class c ON c.oid=p.relation_id
        WHERE j.source_table IN (c.relname,'app.'||c.relname)
        ON CONFLICT DO NOTHING;
      GET DIAGNOSTICS inserted_count = ROW_COUNT;
      changed := changed + inserted_count;
    END IF;
    EXIT WHEN changed=0;
  END LOOP;

  -- Surviving records may refer to an owned patient or financial source.
  -- Detach nullable links; a non-nullable peer link must abort, including
  -- CASCADE links that would otherwise silently erase that peer's record.
  FOR fk IN
    SELECT con.conrelid,con.confrelid,child.attname,child.attnotnull
    FROM pg_constraint con JOIN pg_attribute child
      ON child.attrelid=con.conrelid AND child.attnum=con.conkey[1]
    JOIN pg_attribute parent ON parent.attrelid=con.confrelid AND parent.attnum=con.confkey[1]
    WHERE con.contype='f' AND cardinality(con.conkey)=1 AND parent.attname='id'
      AND EXISTS(SELECT 1 FROM pg_temp.member_purge_rows WHERE relation_id=con.confrelid)
  LOOP
    IF fk.attnotnull THEN
      EXECUTE format(
        'SELECT EXISTS(SELECT 1 FROM %s c JOIN pg_temp.member_purge_rows p ON p.relation_id=%s AND c.%I::text=p.row_id WHERE NOT EXISTS(SELECT 1 FROM pg_temp.member_purge_rows own WHERE own.relation_id=%s AND own.row_id=c.id::text))',
        fk.conrelid::regclass,fk.confrelid,fk.attname,fk.conrelid
      ) INTO has_shared_rows;
      IF has_shared_rows THEN
        RAISE EXCEPTION 'A surviving member record has a required link to this account; deletion was cancelled'
          USING ERRCODE='23503';
      END IF;
    ELSE
      EXECUTE format(
        'UPDATE %s c SET %I=NULL WHERE c.%I::text IN (SELECT row_id FROM pg_temp.member_purge_rows WHERE relation_id=%s) AND NOT EXISTS(SELECT 1 FROM pg_temp.member_purge_rows own WHERE own.relation_id=%s AND own.row_id=c.id::text)',
        fk.conrelid::regclass,fk.attname,fk.attname,fk.confrelid,fk.conrelid
      );
    END IF;
  END LOOP;

  -- Detach nullable edges inside doomed rows to break cycles (prescription /
  -- order, patients, journal reversals). No surviving row is edited here.
  FOR fk IN
    SELECT con.conrelid, child.attname
    FROM pg_constraint con JOIN pg_attribute child
      ON child.attrelid=con.conrelid AND child.attnum=con.conkey[1]
    WHERE con.contype='f' AND cardinality(con.conkey)=1 AND NOT child.attnotnull
      AND EXISTS(SELECT 1 FROM pg_temp.member_purge_rows WHERE relation_id=con.conrelid)
  LOOP
    EXECUTE format('UPDATE %s SET %I=NULL WHERE id::text IN (SELECT row_id FROM pg_temp.member_purge_rows WHERE relation_id=%s)',
      fk.conrelid::regclass,fk.attname,fk.conrelid);
  END LOOP;

  FOR relation IN
    SELECT relation_id,max(depth) AS depth FROM pg_temp.member_purge_rows
    GROUP BY relation_id ORDER BY max(depth) DESC,relation_id
  LOOP
    EXECUTE format('DELETE FROM %s WHERE id::text IN (SELECT row_id FROM pg_temp.member_purge_rows WHERE relation_id=%s)',
      relation.relation_id::regclass,relation.relation_id);
  END LOOP;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION app.permanently_delete_member(bigint,uuid) FROM PUBLIC;
COMMIT;
