-- 02_rpc_cases.sql
-- RPC business-logic cases R2–R12.
-- Run AFTER 00_helpers.sql on a freshly seeded database.
-- Uses savepoints for per-case isolation (Supabase SQL Editor compatible).
--
-- Fixture IDs:
--   cust_a    = b0000000-0000-0000-0000-000000000001
--   cust_b    = b0000000-0000-0000-0000-000000000002
--   rls_admin = b0000000-0000-0000-0000-000000000003

-- ──────────────────────────────────────────────────────────────────
-- Shared setup helper: create a cart + address for a user and add a
-- product to the cart. Returns the address_id.
-- Defined outside the transaction so it persists for later test files.
-- ──────────────────────────────────────────────────────────────────
create or replace function tests.setup_cart(
  p_user_id    uuid,
  p_product_id uuid,
  p_qty        integer default 1
) returns uuid language plpgsql as $$
declare
  v_cart_id uuid;
  v_addr_id uuid;
begin
  insert into public.carts (user_id)
  values (p_user_id)
  on conflict (user_id) do update set updated_at = now()
  returning id into v_cart_id;

  if v_cart_id is null then
    select id into v_cart_id from public.carts where user_id = p_user_id;
  end if;

  delete from public.cart_items where cart_id = v_cart_id;

  insert into public.cart_items (cart_id, product_id, quantity)
  values (v_cart_id, p_product_id, p_qty)
  on conflict (cart_id, product_id) do update set quantity = p_qty;

  insert into public.addresses
    (user_id, recipient_name, phone, line1, city, state, postal_code)
  values
    (p_user_id, 'Test User', '9876543210', '1 Test Rd', 'Mumbai', 'Maharashtra', '400001')
  returning id into v_addr_id;

  return v_addr_id;
end;
$$;

begin;

-- ──────────────────────────────────────────────────────────────────
-- R2: Idempotency — same key twice returns duplicate:true
-- ──────────────────────────────────────────────────────────────────
savepoint r2;
do $$
declare
  v_addr_id uuid;
  v_key     uuid := gen_random_uuid();
  v_result1 jsonb;
  v_result2 jsonb;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result1 := public.create_order(v_addr_id, v_key);
  v_result2 := public.create_order(v_addr_id, v_key);
  perform tests.reset_role();

  if (v_result2->>'duplicate')::boolean = true
     and (v_result1->>'order_id') = (v_result2->>'order_id') then
    raise notice 'PASS R2: idempotency — duplicate:true, same order_id';
  else
    raise notice 'FAIL R2: result1=% result2=%', v_result1, v_result2;
  end if;

  if (select count(*) from public.orders where idempotency_key = v_key) = 1 then
    raise notice 'PASS R2b: exactly 1 order row';
  else
    raise notice 'FAIL R2b: more than 1 order row for same key';
  end if;

  if (select count(*) from public.payments p
        join public.orders o on o.id = p.order_id
       where o.idempotency_key = v_key) = 1 then
    raise notice 'PASS R2c: exactly 1 payment row';
  else
    raise notice 'FAIL R2c: more than 1 payment row';
  end if;
end;
$$;
rollback to savepoint r2;

-- ──────────────────────────────────────────────────────────────────
-- R3: Subtotal >= threshold → delivery_charge = 0
-- NPK 450.00 × 2 = 900.00 >= threshold 500.00
-- ──────────────────────────────────────────────────────────────────
savepoint r3;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000003', 2);

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  select * into v_order from public.orders where id = (v_result->>'order_id')::uuid;

  if v_order.delivery_charge = 0 then
    raise notice 'PASS R3: subtotal % >= threshold, delivery_charge=0', v_order.subtotal;
  else
    raise notice 'FAIL R3: expected delivery_charge=0, got %', v_order.delivery_charge;
  end if;
end;
$$;
rollback to savepoint r3;

-- ──────────────────────────────────────────────────────────────────
-- R4: Subtotal < threshold → delivery_charge = 40
-- Tomato 149.00 × 1 = 149.00 < 500.00
-- ──────────────────────────────────────────────────────────────────
savepoint r4;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  select * into v_order from public.orders where id = (v_result->>'order_id')::uuid;

  if v_order.delivery_charge = 40.00 then
    raise notice 'PASS R4: subtotal % < threshold, delivery_charge=40', v_order.subtotal;
  else
    raise notice 'FAIL R4: expected delivery_charge=40, got %', v_order.delivery_charge;
  end if;
end;
$$;
rollback to savepoint r4;

-- ──────────────────────────────────────────────────────────────────
-- R5: Money math — price 149 × qty 1, tax 5%
--     line_total=149.00, line_tax=7.45, total=196.45
-- ──────────────────────────────────────────────────────────────────
savepoint r5;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
  v_item    public.order_items%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  select * into v_order from public.orders where id = (v_result->>'order_id')::uuid;
  select * into v_item  from public.order_items where order_id = v_order.id limit 1;

  if v_item.line_total = 149.00 and v_item.line_tax = 7.45
     and v_order.tax = 7.45
     and v_order.total = v_order.subtotal + v_order.tax + v_order.delivery_charge - v_order.discount then
    raise notice 'PASS R5: money math correct — line_total=% line_tax=% tax=% total=%',
      v_item.line_total, v_item.line_tax, v_order.tax, v_order.total;
  else
    raise notice 'FAIL R5: line_total=% line_tax=% tax=% total=% (expected 149/7.45/7.45/196.45)',
      v_item.line_total, v_item.line_tax, v_order.tax, v_order.total;
  end if;
end;
$$;
rollback to savepoint r5;

-- ──────────────────────────────────────────────────────────────────
-- R6: Customer B cannot call change_order_status — FORBIDDEN
-- ──────────────────────────────────────────────────────────────────
savepoint r6;
do $$
declare
  v_addr_id  uuid;
  v_result   jsonb;
  v_order_id uuid;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result   := public.create_order(v_addr_id, gen_random_uuid());
  v_order_id := (v_result->>'order_id')::uuid;

  perform tests.act_as('b0000000-0000-0000-0000-000000000002');
  perform tests.expect_error(
    'R6: cust_b cannot change_order_status',
    format('select public.change_order_status(%L, ''CONFIRMED'')', v_order_id),
    '%FORBIDDEN%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint r6;

-- ──────────────────────────────────────────────────────────────────
-- R7: PACKED → CANCELLED is CONFLICT
-- ──────────────────────────────────────────────────────────────────
savepoint r7;
do $$
declare
  v_addr_id  uuid;
  v_result   jsonb;
  v_order_id uuid;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result   := public.create_order(v_addr_id, gen_random_uuid());
  v_order_id := (v_result->>'order_id')::uuid;

  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform public.change_order_status(v_order_id, 'PROCESSING');
  perform public.change_order_status(v_order_id, 'PACKED');

  perform tests.expect_error(
    'R7: PACKED->CANCELLED is CONFLICT',
    format('select public.change_order_status(%L, ''CANCELLED'', ''test reason'')', v_order_id),
    '%CONFLICT%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint r7;

-- ──────────────────────────────────────────────────────────────────
-- R8: Cancel without reason → VALIDATION_ERROR
-- ──────────────────────────────────────────────────────────────────
savepoint r8;
do $$
declare
  v_addr_id  uuid;
  v_result   jsonb;
  v_order_id uuid;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result   := public.create_order(v_addr_id, gen_random_uuid());
  v_order_id := (v_result->>'order_id')::uuid;

  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform tests.expect_error(
    'R8: cancel without reason raises VALIDATION_ERROR',
    format('select public.change_order_status(%L, ''CANCELLED'')', v_order_id),
    '%VALIDATION_ERROR%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint r8;

-- ──────────────────────────────────────────────────────────────────
-- R9: Admin cancels NEW order → inventory restored, payment CANCELLED,
--     ORDER_STATUS notification created, ORDER_CANCEL tx logged
-- ──────────────────────────────────────────────────────────────────
savepoint r9;
do $$
declare
  v_addr_id    uuid;
  v_result     jsonb;
  v_order_id   uuid;
  v_inv_before integer;
  v_inv_after  integer;
  v_pay_status text;
  v_notif_cnt  integer;
  v_tx_cnt     integer;
begin
  select quantity into v_inv_before from public.inventory
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000001';

  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 2);
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result   := public.create_order(v_addr_id, gen_random_uuid());
  v_order_id := (v_result->>'order_id')::uuid;

  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CANCELLED', 'test cancel');
  perform tests.reset_role();

  select quantity into v_inv_after  from public.inventory
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  select status     into v_pay_status from public.payments where order_id = v_order_id;
  select count(*)   into v_notif_cnt  from public.notifications
   where (data->>'order_id')::uuid = v_order_id and type = 'ORDER_STATUS';
  select count(*)   into v_tx_cnt     from public.inventory_transactions
   where reference_id = v_order_id and transaction_type = 'ORDER_CANCEL';

  if v_inv_after = v_inv_before then
    raise notice 'PASS R9a: inventory restored (before=% after=%)', v_inv_before, v_inv_after;
  else
    raise notice 'FAIL R9a: inventory not restored (before=% after=%)', v_inv_before, v_inv_after;
  end if;

  if v_pay_status = 'CANCELLED' then
    raise notice 'PASS R9b: payment status=CANCELLED';
  else
    raise notice 'FAIL R9b: expected CANCELLED, got %', v_pay_status;
  end if;

  if v_notif_cnt >= 1 then
    raise notice 'PASS R9c: ORDER_STATUS notification created';
  else
    raise notice 'FAIL R9c: no ORDER_STATUS notification found';
  end if;

  if v_tx_cnt >= 1 then
    raise notice 'PASS R9d: ORDER_CANCEL inventory_transaction created';
  else
    raise notice 'FAIL R9d: no ORDER_CANCEL tx found';
  end if;
end;
$$;
rollback to savepoint r9;

-- ──────────────────────────────────────────────────────────────────
-- R10: adjust_inventory delta -100 when qty 50 → VALIDATION_ERROR,
--      quantity unchanged, no new tx row
-- ──────────────────────────────────────────────────────────────────
savepoint r10;
do $$
declare
  v_tx_before bigint;
  v_tx_after  bigint;
  v_qty       integer;
begin
  select count(*) into v_tx_before from public.inventory_transactions
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000003';

  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform tests.expect_error(
    'R10: adjust -100 on qty 50 raises VALIDATION_ERROR',
    'select public.adjust_inventory('
    '''aaaaaaaa-0000-0000-0000-000000000003'', -100, ''ADJUSTMENT'', ''test'')',
    '%VALIDATION_ERROR%'
  );
  perform tests.reset_role();

  select count(*) into v_tx_after from public.inventory_transactions
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000003';
  select quantity  into v_qty from public.inventory
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000003';

  if v_tx_before = v_tx_after then
    raise notice 'PASS R10b: no new inventory_transaction row written';
  else
    raise notice 'FAIL R10b: tx row was written (before=% after=%)', v_tx_before, v_tx_after;
  end if;

  if v_qty = 50 then
    raise notice 'PASS R10c: quantity still 50';
  else
    raise notice 'FAIL R10c: quantity changed to %', v_qty;
  end if;
end;
$$;
rollback to savepoint r10;

-- ──────────────────────────────────────────────────────────────────
-- R11: Order totals derive only from DB — total = subtotal+tax+delivery-discount
-- ──────────────────────────────────────────────────────────────────
savepoint r11;
do $$
declare
  v_addr_id    uuid;
  v_result     jsonb;
  v_order      public.orders%rowtype;
  v_recomputed numeric(12,2);
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);
  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  select * into v_order from public.orders where id = (v_result->>'order_id')::uuid;

  v_recomputed := v_order.subtotal + v_order.tax + v_order.delivery_charge - v_order.discount;

  if v_order.total = v_recomputed then
    raise notice 'PASS R11: total=% matches recomputed %', v_order.total, v_recomputed;
  else
    raise notice 'FAIL R11: total=% != recomputed %', v_order.total, v_recomputed;
  end if;
end;
$$;
rollback to savepoint r11;

-- ──────────────────────────────────────────────────────────────────
-- R12: Unpublished product in cart → PRODUCT_UNAVAILABLE,
--      0 new orders, inventory unchanged, cart intact
-- ──────────────────────────────────────────────────────────────────
savepoint r12;
do $$
declare
  v_addr_id    uuid;
  v_cart_id    uuid;
  v_order_cnt  bigint;
  v_qty_before integer;
  v_qty_after  integer;
  v_item_cnt   bigint;
begin
  insert into public.products
    (id, category_id, name, slug, sku, price, tax_percent, is_active, is_published)
  values
    ('ffff0000-0000-0000-0000-000000000001',
     '11111111-1111-1111-1111-111111111111',
     'Hidden Product', 'hidden-product', 'HIDDEN-001',
     99.00, 5, true, false)
  on conflict (id) do nothing;

  insert into public.inventory (product_id, quantity)
  values ('ffff0000-0000-0000-0000-000000000001', 10)
  on conflict (product_id) do nothing;

  insert into public.carts (user_id)
  values ('b0000000-0000-0000-0000-000000000001')
  on conflict (user_id) do nothing;

  select id into v_cart_id from public.carts
   where user_id = 'b0000000-0000-0000-0000-000000000001';

  delete from public.cart_items where cart_id = v_cart_id;
  insert into public.cart_items (cart_id, product_id, quantity)
  values (v_cart_id, 'ffff0000-0000-0000-0000-000000000001', 1);

  insert into public.addresses
    (user_id, recipient_name, phone, line1, city, state, postal_code)
  values
    ('b0000000-0000-0000-0000-000000000001',
     'Test User', '9876543210', '1 Test Rd', 'Mumbai', 'Maharashtra', '400001')
  returning id into v_addr_id;

  select count(*) into v_order_cnt  from public.orders
   where user_id = 'b0000000-0000-0000-0000-000000000001';
  select quantity into v_qty_before from public.inventory
   where product_id = 'ffff0000-0000-0000-0000-000000000001';
  select count(*) into v_item_cnt   from public.cart_items where cart_id = v_cart_id;

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  perform tests.expect_error(
    'R12: unpublished product → PRODUCT_UNAVAILABLE',
    format('select public.create_order(%L, gen_random_uuid())', v_addr_id),
    '%PRODUCT_UNAVAILABLE%'
  );
  perform tests.reset_role();

  if (select count(*) from public.orders
       where user_id = 'b0000000-0000-0000-0000-000000000001') = v_order_cnt then
    raise notice 'PASS R12b: no new order created';
  else
    raise notice 'FAIL R12b: unexpected order was created';
  end if;

  select quantity into v_qty_after from public.inventory
   where product_id = 'ffff0000-0000-0000-0000-000000000001';
  if v_qty_after = v_qty_before then
    raise notice 'PASS R12c: inventory unchanged (qty=%)', v_qty_after;
  else
    raise notice 'FAIL R12c: inventory changed (before=% after=%)', v_qty_before, v_qty_after;
  end if;

  if (select count(*) from public.cart_items where cart_id = v_cart_id) = v_item_cnt then
    raise notice 'PASS R12d: cart_items untouched';
  else
    raise notice 'FAIL R12d: cart_items were modified';
  end if;
end;
$$;
rollback to savepoint r12;

-- NOTE: R1 (concurrent race) requires two simultaneous sessions — cannot run in SQL Editor.
-- Manual procedure:
--   1. Set inventory qty to 1 for a product.
--   2. In two browser tabs, open the SQL Editor simultaneously.
--   3. In each tab run: select public.create_order(<addr_id>, gen_random_uuid());
--   4. Fire both at the same time.
--   Assert: exactly one returns success; the other returns OUT_OF_STOCK.
--   Assert: inventory.quantity >= 0; exactly 1 order row for that product.
do $$ begin
  raise notice 'R1: concurrent race — run manually (see comment above)';
end $$;

rollback;
