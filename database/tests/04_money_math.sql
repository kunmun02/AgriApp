-- 04_money_math.sql
-- Money precision cases MONEY-1 … MONEY-3.
-- Run AFTER 00_helpers.sql and 02_rpc_cases.sql (needs tests.setup_cart).
-- Uses savepoints for per-case isolation (Supabase SQL Editor compatible).

begin;

-- ──────────────────────────────────────────────────────────────────
-- MONEY-1: price 149.00 × qty 1, tax 5%
--   line_total = 149.00
--   line_tax   = ROUND(149.00 * 5 / 100, 2) = 7.45
--   order.tax  = 7.45
--   total      = 149.00 + 7.45 + 40.00 = 196.45
-- ──────────────────────────────────────────────────────────────────
savepoint money1;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
  v_item    public.order_items%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000001', 1);  -- Tomato: price=149.00, tax=5%

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();

  select * into v_order from public.orders    where id = (v_result->>'order_id')::uuid;
  select * into v_item  from public.order_items where order_id = v_order.id limit 1;

  if v_item.line_total = 149.00 then
    raise notice 'PASS MONEY-1a: line_total = 149.00';
  else
    raise notice 'FAIL MONEY-1a: line_total = % (expected 149.00)', v_item.line_total;
  end if;

  if v_item.line_tax = 7.45 then
    raise notice 'PASS MONEY-1b: line_tax = 7.45';
  else
    raise notice 'FAIL MONEY-1b: line_tax = % (expected 7.45)', v_item.line_tax;
  end if;

  if v_order.tax = 7.45 then
    raise notice 'PASS MONEY-1c: order.tax = 7.45';
  else
    raise notice 'FAIL MONEY-1c: order.tax = % (expected 7.45)', v_order.tax;
  end if;

  if v_order.total = v_order.subtotal + v_order.tax + v_order.delivery_charge - v_order.discount then
    raise notice 'PASS MONEY-1d: total = % (arithmetic identity holds)', v_order.total;
  else
    raise notice 'FAIL MONEY-1d: total=% != subtotal+tax+delivery-discount=%',
      v_order.total,
      v_order.subtotal + v_order.tax + v_order.delivery_charge - v_order.discount;
  end if;
end;
$$;
rollback to savepoint money1;

-- ──────────────────────────────────────────────────────────────────
-- MONEY-2: NPK 450.00 × 1, tax 12%
--   line_tax   = ROUND(450.00 * 12 / 100, 2) = 54.00
--   delivery   = 40.00  (450 < threshold 500)
--   total      = 450.00 + 54.00 + 40.00 = 544.00
--   No float drift — verify stored NUMERIC identity.
-- ──────────────────────────────────────────────────────────────────
savepoint money2;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
  v_item    public.order_items%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000003', 1);  -- NPK: price=450.00, tax=12%

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();

  select * into v_order from public.orders    where id = (v_result->>'order_id')::uuid;
  select * into v_item  from public.order_items where order_id = v_order.id limit 1;

  if v_item.line_tax = 54.00 then
    raise notice 'PASS MONEY-2a: NPK line_tax = 54.00';
  else
    raise notice 'FAIL MONEY-2a: NPK line_tax = % (expected 54.00)', v_item.line_tax;
  end if;

  if v_order.delivery_charge = 40.00 then
    raise notice 'PASS MONEY-2b: delivery_charge = 40.00 (subtotal 450 < threshold 500)';
  else
    raise notice 'FAIL MONEY-2b: delivery_charge = % (expected 40.00)', v_order.delivery_charge;
  end if;

  if v_order.total = 544.00 then
    raise notice 'PASS MONEY-2c: total = 544.00 (450+54+40)';
  else
    raise notice 'FAIL MONEY-2c: total = % (expected 544.00)', v_order.total;
  end if;

  if v_order.total = v_order.subtotal + v_order.tax + v_order.delivery_charge - v_order.discount then
    raise notice 'PASS MONEY-2d: no float drift — arithmetic identity holds on stored row';
  else
    raise notice 'FAIL MONEY-2d: arithmetic identity does not hold';
  end if;
end;
$$;
rollback to savepoint money2;

-- ──────────────────────────────────────────────────────────────────
-- MONEY-3: Delivery threshold boundary (threshold = 500.00)
--   NPK 450 × 1 = 450.00 < 500  → delivery = 40
--   NPK 450 × 2 = 900.00 >= 500 → delivery = 0  (≥ rule)
-- ──────────────────────────────────────────────────────────────────
savepoint money3a;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000003', 1);  -- 450 < 500

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  select * into v_order from public.orders where id = (v_result->>'order_id')::uuid;

  if v_order.delivery_charge = 40.00 then
    raise notice 'PASS MONEY-3a: subtotal % < 500 → delivery = 40', v_order.subtotal;
  else
    raise notice 'FAIL MONEY-3a: subtotal % delivery = % (expected 40)', v_order.subtotal, v_order.delivery_charge;
  end if;
end;
$$;
rollback to savepoint money3a;

savepoint money3b;
do $$
declare
  v_addr_id uuid;
  v_result  jsonb;
  v_order   public.orders%rowtype;
begin
  v_addr_id := tests.setup_cart(
    'b0000000-0000-0000-0000-000000000001',
    'aaaaaaaa-0000-0000-0000-000000000003', 2);  -- 900 >= 500

  perform tests.act_as('b0000000-0000-0000-0000-000000000001');
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  select * into v_order from public.orders where id = (v_result->>'order_id')::uuid;

  if v_order.delivery_charge = 0 then
    raise notice 'PASS MONEY-3b: subtotal % >= 500 → delivery = 0', v_order.subtotal;
  else
    raise notice 'FAIL MONEY-3b: subtotal % delivery = % (expected 0)', v_order.subtotal, v_order.delivery_charge;
  end if;
end;
$$;
rollback to savepoint money3b;

rollback;
