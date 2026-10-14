-- 00_helpers.sql
-- Test scaffolding: helper functions + fixture users.
-- Run ONCE on a freshly seeded database before running any test script.
-- Wrap everything in a schema so it never pollutes public.

create schema if not exists tests;

-- ──────────────────────────────────────────────────────────────────
-- act_as(p_user) — switches the session to an authenticated user
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.act_as(p_user uuid)
returns void language sql as $$
  select set_config('role', 'authenticated', true);
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- ──────────────────────────────────────────────────────────────────
-- act_as_anon() — switches the session to the anon role
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.act_as_anon()
returns void language sql as $$
  select set_config('role', 'anon', true);
  select set_config('request.jwt.claims', '', true);
$$;

-- ──────────────────────────────────────────────────────────────────
-- reset_role() — resets back to postgres (superuser)
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.reset_role()
returns void language sql as $$
  select set_config('role', 'postgres', true);
  select set_config('request.jwt.claims', '', true);
$$;

-- ──────────────────────────────────────────────────────────────────
-- expect_rows(label, sql, min_rows)
-- Executes p_sql and asserts the row count >= p_min.
-- Prints PASS <label> or FAIL <label> <detail>.
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.expect_rows(
  p_label text,
  p_sql   text,
  p_min   bigint default 1
)
returns void language plpgsql as $$
declare
  v_count bigint;
begin
  execute 'select count(*) from (' || p_sql || ') _t' into v_count;
  if v_count >= p_min then
    raise notice 'PASS %', p_label;
  else
    raise notice 'FAIL % — expected >= % rows, got %', p_label, p_min, v_count;
  end if;
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- expect_zero_rows(label, sql)
-- Asserts the query returns 0 rows.
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.expect_zero_rows(
  p_label text,
  p_sql   text
)
returns void language plpgsql as $$
declare
  v_count bigint;
begin
  execute 'select count(*) from (' || p_sql || ') _t' into v_count;
  if v_count = 0 then
    raise notice 'PASS %', p_label;
  else
    raise notice 'FAIL % — expected 0 rows, got %', p_label, v_count;
  end if;
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- expect_error(label, sql, msg_like)
-- Executes p_sql inside a savepoint; asserts it raises an exception.
-- Optionally checks that the message ILIKE p_msg_like.
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.expect_error(
  p_label    text,
  p_sql      text,
  p_msg_like text default null
)
returns void language plpgsql as $$
declare
  v_msg text;
begin
  begin
    execute p_sql;
    -- If we reach here, no exception was raised — FAIL.
    raise notice 'FAIL % — expected an error but none was raised', p_label;
    return;
  exception when others then
    get stacked diagnostics v_msg = message_text;
    if p_msg_like is null or v_msg ilike p_msg_like then
      raise notice 'PASS %', p_label;
    else
      raise notice 'FAIL % — error raised but message "%" does not match "%"',
        p_label, v_msg, p_msg_like;
    end if;
  end;
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- Fixture users
-- Inserted directly into auth.users; the handle_new_user trigger
-- creates matching profiles rows with role='customer'.
-- ──────────────────────────────────────────────────────────────────

-- Fixture UUIDs — stable across runs.
-- cust_a  : b0000000-0000-0000-0000-000000000001
-- cust_b  : b0000000-0000-0000-0000-000000000002
-- rls_admin: b0000000-0000-0000-0000-000000000003

insert into auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data, aud, role
) values
  (
    'b0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'rls-a@example.com',
    crypt('password123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Customer A"}'::jsonb,
    'authenticated', 'authenticated'
  ),
  (
    'b0000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'rls-b@example.com',
    crypt('password123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Customer B"}'::jsonb,
    'authenticated', 'authenticated'
  ),
  (
    'b0000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'rls-admin@example.com',
    crypt('password123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Test Admin"}'::jsonb,
    'authenticated', 'authenticated'
  )
on conflict (id) do nothing;

-- Promote the test admin
update public.profiles
   set role = 'admin'
 where id = 'b0000000-0000-0000-0000-000000000003';

-- Verify fixture setup
do $$
declare v_count int;
begin
  select count(*) into v_count from public.profiles
   where id in (
     'b0000000-0000-0000-0000-000000000001',
     'b0000000-0000-0000-0000-000000000002',
     'b0000000-0000-0000-0000-000000000003'
   );
  if v_count = 3 then
    raise notice 'PASS 00_helpers — fixture users created (%)', v_count;
  else
    raise notice 'FAIL 00_helpers — expected 3 fixture profiles, got %', v_count;
  end if;
end;
$$;
