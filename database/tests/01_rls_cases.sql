-- 01_rls_cases.sql
-- RLS authorization cases C01–C12 + supplementary cases.
-- Run AFTER 00_helpers.sql on a freshly seeded database.
-- Output: PASS / FAIL lines via RAISE NOTICE.
-- Uses savepoints so each case rolls back independently without
-- aborting the whole script (compatible with Supabase SQL Editor).

begin;

-- Fixture IDs (created by 00_helpers.sql):
--   cust_a   = b0000000-0000-0000-0000-000000000001
--   cust_b   = b0000000-0000-0000-0000-000000000002
--   rls_admin = b0000000-0000-0000-0000-000000000003

-- ──────────────────────────────────────────────────────────────────
-- Setup: give cust_a a cart and one order so SELECT tests have rows.
-- Runs as postgres (superuser) — no RLS restriction.
-- ──────────────────────────────────────────────────────────────────
do $$
declare
  v_order_a uuid := gen_random_uuid();
begin
  insert into public.carts (user_id) values
    ('b0000000-0000-0000-0000-000000000001'),
    ('b0000000-0000-0000-0000-000000000002')
  on conflict (user_id) do nothing;

  insert into public.orders
    (id, order_number, user_id, status, subtotal, delivery_charge, tax, discount, total,
     shipping_snapshot, idempotency_key)
  values
    (v_order_a, 'AGR-TEST-000001',
     'b0000000-0000-0000-0000-000000000001',
     'NEW', 149.00, 40.00, 7.45, 0, 196.45,
     '{"recipient_name":"Customer A","line1":"123 Test St","city":"Mumbai",
       "state":"Maharashtra","postal_code":"400001","country":"India",
       "phone":"9876543210"}'::jsonb,
     gen_random_uuid())
  on conflict do nothing;

  raise notice 'RLS setup complete';
end;
$$;

-- ──────────────────────────────────────────────────────────────────
-- C01: customer A selects orders — sees only own rows
-- ──────────────────────────────────────────────────────────────────
savepoint c01;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_rows(
    'C01: cust_a sees own orders',
    'select * from public.orders where user_id = ''b0000000-0000-0000-0000-000000000001''',
    1
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c01;

-- ──────────────────────────────────────────────────────────────────
-- C02: customer A tries to see customer B's orders — 0 rows
-- ──────────────────────────────────────────────────────────────────
savepoint c02;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_zero_rows(
    'C02: cust_a cannot see cust_b orders',
    'select * from public.orders where user_id = ''b0000000-0000-0000-0000-000000000002'''
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c02;

-- ──────────────────────────────────────────────────────────────────
-- C03: customer A tries direct INSERT into orders — permission denied
-- ──────────────────────────────────────────────────────────────────
savepoint c03;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_error(
    'C03: cust_a cannot INSERT into orders directly',
    'insert into public.orders'
    ' (order_number, user_id, status, subtotal, delivery_charge, tax, discount, total,'
    '  shipping_snapshot, idempotency_key)'
    ' values (''X'', ''b0000000-0000-0000-0000-000000000001'', ''NEW'','
    '         0, 0, 0, 0, 0, ''{}'', gen_random_uuid())'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c03;

-- ──────────────────────────────────────────────────────────────────
-- C04: customer A selects inventory — 0 rows (no policy)
-- ──────────────────────────────────────────────────────────────────
savepoint c04;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_zero_rows(
    'C04: cust_a sees 0 inventory rows',
    'select * from public.inventory'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c04;

-- ──────────────────────────────────────────────────────────────────
-- C05: anon selects unpublished products — 0 rows
-- ──────────────────────────────────────────────────────────────────
savepoint c05;
do $$
begin
  perform tests.act_as_anon();
  perform tests.expect_zero_rows(
    'C05: anon sees 0 unpublished products',
    'select * from public.products where not is_published'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c05;

-- ──────────────────────────────────────────────────────────────────
-- C06: anon selects inactive categories — 0 rows
-- ──────────────────────────────────────────────────────────────────
savepoint c06;
do $$
begin
  perform tests.act_as_anon();
  perform tests.expect_zero_rows(
    'C06: anon sees 0 inactive categories',
    'select * from public.categories where not is_active'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c06;

-- ──────────────────────────────────────────────────────────────────
-- C07: customer A tries to self-escalate role to admin — FORBIDDEN
-- ──────────────────────────────────────────────────────────────────
savepoint c07;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_error(
    'C07: cust_a cannot set own role=admin',
    'update public.profiles set role = ''admin'''
    ' where id = ''b0000000-0000-0000-0000-000000000001''',
    '%FORBIDDEN%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c07;

-- ──────────────────────────────────────────────────────────────────
-- C08: customer A tries to deactivate own account — FORBIDDEN
-- ──────────────────────────────────────────────────────────────────
savepoint c08;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_error(
    'C08: cust_a cannot set is_active=false on own profile',
    'update public.profiles set is_active = false'
    ' where id = ''b0000000-0000-0000-0000-000000000001''',
    '%FORBIDDEN%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c08;

-- ──────────────────────────────────────────────────────────────────
-- C09: anon selects app_settings — 0 rows (no anon select policy)
-- ──────────────────────────────────────────────────────────────────
savepoint c09;
do $$
begin
  perform tests.act_as_anon();
  perform tests.expect_zero_rows(
    'C09: anon sees 0 app_settings rows',
    'select * from public.app_settings'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c09;

-- ──────────────────────────────────────────────────────────────────
-- C10: customer A selects v_product_availability — sees booleans only
-- ──────────────────────────────────────────────────────────────────
savepoint c10;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_rows(
    'C10: cust_a can read v_product_availability',
    'select * from public.v_product_availability',
    1
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c10;

-- ──────────────────────────────────────────────────────────────────
-- C11: customer A tries to insert a cart_item into customer B's cart
-- ──────────────────────────────────────────────────────────────────
savepoint c11;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_error(
    'C11: cust_a cannot insert cart_item into cust_b cart',
    'insert into public.cart_items (cart_id, product_id, quantity)'
    ' select c.id, ''aaaaaaaa-0000-0000-0000-000000000001'', 1'
    ' from public.carts c'
    ' where c.user_id = ''b0000000-0000-0000-0000-000000000002'''
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint c11;

-- ──────────────────────────────────────────────────────────────────
-- SUPP-A: customer A can insert own address
-- ──────────────────────────────────────────────────────────────────
savepoint supp_a;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  insert into public.addresses
    (user_id, recipient_name, phone, line1, city, state, postal_code)
  values
    ('b0000000-0000-0000-0000-000000000001',
     'Customer A', '9876543210', '1 Test Road', 'Mumbai', 'Maharashtra', '400001');
  perform tests.expect_rows(
    'SUPP-A: cust_a can insert own address',
    'select * from public.addresses where user_id = ''b0000000-0000-0000-0000-000000000001''',
    1
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint supp_a;

-- ──────────────────────────────────────────────────────────────────
-- SUPP-B: customer A cannot update customer B's notification
-- ──────────────────────────────────────────────────────────────────
savepoint supp_b;
do $$
begin
  perform tests.reset_role();
  insert into public.notifications (user_id, type, title, body)
  values ('b0000000-0000-0000-0000-000000000002', 'SYSTEM', 'Test', 'body');

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  update public.notifications
     set is_read = true
   where user_id = 'b0000000-0000-0000-0000-000000000002';

  perform tests.expect_zero_rows(
    'SUPP-B: cust_a update on cust_b notification affects 0 rows',
    'select * from public.notifications'
    ' where user_id = ''b0000000-0000-0000-0000-000000000002'' and is_read = true'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint supp_b;

-- ──────────────────────────────────────────────────────────────────
-- SUPP-C: admin can select orders of cust_a
-- ──────────────────────────────────────────────────────────────────
savepoint supp_c;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform tests.expect_rows(
    'SUPP-C: admin can see cust_a orders',
    'select * from public.orders where user_id = ''b0000000-0000-0000-0000-000000000001''',
    1
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint supp_c;

-- ──────────────────────────────────────────────────────────────────
-- SUPP-D: admin can update app_settings
-- ──────────────────────────────────────────────────────────────────
savepoint supp_d;
do $$
begin
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  update public.app_settings set delivery_charge = 50.00 where id = true;
  perform tests.expect_rows(
    'SUPP-D: admin can update app_settings',
    'select * from public.app_settings where delivery_charge = 50.00',
    1
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint supp_d;

-- C12: anon storage upload — verified via REST API (not SQL).
-- curl -X POST "$SUPABASE_URL/storage/v1/object/product-images/test.jpg"
--      -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY" --data-binary @test.jpg
-- Expected: 4xx response (denied). PASS if HTTP status != 200.
do $$ begin
  raise notice 'C12: verify anon storage upload via REST API (see comment above)';
end $$;

rollback;
