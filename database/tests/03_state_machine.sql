-- 03_state_machine.sql
-- State machine cases SM-1 … SM-8 (Master §3.6 transition table).
-- Run AFTER 00_helpers.sql and 02_rpc_cases.sql (needs tests.setup_cart).
-- Uses savepoints for per-case isolation (Supabase SQL Editor compatible).
--
-- Fixture IDs:
--   cust_a    = b0000000-0000-0000-0000-000000000001
--   rls_admin = b0000000-0000-0000-0000-000000000003

-- Helper: create a clean NEW order and return its id.
-- Defined outside the transaction so it persists for use by all SM cases.
create or replace function tests.make_order(
  p_user_id    uuid,
  p_product_id uuid default 'aaaaaaaa-0000-0000-0000-000000000001',
  p_qty        integer default 1
) returns uuid language plpgsql as $$
declare
  v_addr_id uuid;
  v_result  jsonb;
begin
  v_addr_id := tests.setup_cart(p_user_id, p_product_id, p_qty);
  perform tests.act_as(p_user_id);
  v_result := public.create_order(v_addr_id, gen_random_uuid());
  perform tests.reset_role();
  return (v_result->>'order_id')::uuid;
end;
$$;

begin;

-- ──────────────────────────────────────────────────────────────────
-- SM-1: NEW → CONFIRMED succeeds; notification created
-- ──────────────────────────────────────────────────────────────────
savepoint sm1;
do $$
declare
  v_order_id uuid;
  v_status   text;
  v_notifs   integer;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform tests.reset_role();

  select status  into v_status from public.orders where id = v_order_id;
  select count(*) into v_notifs from public.notifications
   where (data->>'order_id')::uuid = v_order_id;

  if v_status = 'CONFIRMED' then
    raise notice 'PASS SM-1a: status = CONFIRMED';
  else
    raise notice 'FAIL SM-1a: status = %', v_status;
  end if;

  if v_notifs >= 1 then
    raise notice 'PASS SM-1b: notification row inserted';
  else
    raise notice 'FAIL SM-1b: no notification';
  end if;
end;
$$;
rollback to savepoint sm1;

-- ──────────────────────────────────────────────────────────────────
-- SM-2: CONFIRMED → CANCELLED with reason → restock + payment CANCELLED
-- ──────────────────────────────────────────────────────────────────
savepoint sm2;
do $$
declare
  v_order_id   uuid;
  v_status     text;
  v_pay_status text;
  v_inv_before integer;
  v_inv_after  integer;
begin
  select quantity into v_inv_before from public.inventory
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000001';

  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform public.change_order_status(v_order_id, 'CANCELLED', 'SM-2 test cancel');
  perform tests.reset_role();

  select status into v_status     from public.orders   where id = v_order_id;
  select status into v_pay_status from public.payments where order_id = v_order_id;
  select quantity into v_inv_after from public.inventory
   where product_id = 'aaaaaaaa-0000-0000-0000-000000000001';

  if v_status = 'CANCELLED' then
    raise notice 'PASS SM-2a: order status = CANCELLED';
  else
    raise notice 'FAIL SM-2a: status = %', v_status;
  end if;

  if v_pay_status = 'CANCELLED' then
    raise notice 'PASS SM-2b: payment status = CANCELLED';
  else
    raise notice 'FAIL SM-2b: payment status = %', v_pay_status;
  end if;

  if v_inv_after = v_inv_before then
    raise notice 'PASS SM-2c: inventory restored';
  else
    raise notice 'FAIL SM-2c: inventory before=% after=%', v_inv_before, v_inv_after;
  end if;
end;
$$;
rollback to savepoint sm2;

-- ──────────────────────────────────────────────────────────────────
-- SM-3: PACKED → CANCELLED is CONFLICT (cannot cancel after packed)
-- ──────────────────────────────────────────────────────────────────
savepoint sm3;
do $$
declare
  v_order_id uuid;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform public.change_order_status(v_order_id, 'PROCESSING');
  perform public.change_order_status(v_order_id, 'PACKED');

  perform tests.expect_error(
    'SM-3: PACKED->CANCELLED is CONFLICT',
    format('select public.change_order_status(%L, ''CANCELLED'', ''late cancel'')', v_order_id),
    '%CONFLICT%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint sm3;

-- ──────────────────────────────────────────────────────────────────
-- SM-4: OUT_FOR_DELIVERY → DELIVERED; payment → COLLECTED
-- ──────────────────────────────────────────────────────────────────
savepoint sm4;
do $$
declare
  v_order_id   uuid;
  v_status     text;
  v_pay_status text;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform public.change_order_status(v_order_id, 'PROCESSING');
  perform public.change_order_status(v_order_id, 'PACKED');
  perform public.change_order_status(v_order_id, 'SHIPPED');
  perform public.change_order_status(v_order_id, 'OUT_FOR_DELIVERY');
  perform public.change_order_status(v_order_id, 'DELIVERED');
  perform tests.reset_role();

  select status into v_status     from public.orders   where id = v_order_id;
  select status into v_pay_status from public.payments where order_id = v_order_id;

  if v_status = 'DELIVERED' then
    raise notice 'PASS SM-4a: order status = DELIVERED';
  else
    raise notice 'FAIL SM-4a: status = %', v_status;
  end if;

  if v_pay_status = 'COLLECTED' then
    raise notice 'PASS SM-4b: payment status = COLLECTED';
  else
    raise notice 'FAIL SM-4b: payment status = %', v_pay_status;
  end if;
end;
$$;
rollback to savepoint sm4;

-- ──────────────────────────────────────────────────────────────────
-- SM-5: DELIVERED → PROCESSING is CONFLICT (terminal state)
-- ──────────────────────────────────────────────────────────────────
savepoint sm5;
do $$
declare
  v_order_id uuid;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform public.change_order_status(v_order_id, 'PROCESSING');
  perform public.change_order_status(v_order_id, 'PACKED');
  perform public.change_order_status(v_order_id, 'SHIPPED');
  perform public.change_order_status(v_order_id, 'OUT_FOR_DELIVERY');
  perform public.change_order_status(v_order_id, 'DELIVERED');

  perform tests.expect_error(
    'SM-5: DELIVERED->PROCESSING is CONFLICT',
    format('select public.change_order_status(%L, ''PROCESSING'')', v_order_id),
    '%CONFLICT%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint sm5;

-- ──────────────────────────────────────────────────────────────────
-- SM-6: CANCELLED → CONFIRMED is CONFLICT (terminal state)
-- ──────────────────────────────────────────────────────────────────
savepoint sm6;
do $$
declare
  v_order_id uuid;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CANCELLED', 'SM-6 cancel');

  perform tests.expect_error(
    'SM-6: CANCELLED->CONFIRMED is CONFLICT',
    format('select public.change_order_status(%L, ''CONFIRMED'')', v_order_id),
    '%CONFLICT%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint sm6;

-- ──────────────────────────────────────────────────────────────────
-- SM-7: SHIPPED → PROCESSING (skip back) is CONFLICT
-- ──────────────────────────────────────────────────────────────────
savepoint sm7;
do $$
declare
  v_order_id uuid;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');
  perform public.change_order_status(v_order_id, 'CONFIRMED');
  perform public.change_order_status(v_order_id, 'PROCESSING');
  perform public.change_order_status(v_order_id, 'PACKED');
  perform public.change_order_status(v_order_id, 'SHIPPED');

  perform tests.expect_error(
    'SM-7: SHIPPED->PROCESSING is CONFLICT',
    format('select public.change_order_status(%L, ''PROCESSING'')', v_order_id),
    '%CONFLICT%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint sm7;

-- ──────────────────────────────────────────────────────────────────
-- SM-8: Unknown target status → VALIDATION_ERROR
-- ──────────────────────────────────────────────────────────────────
savepoint sm8;
do $$
declare
  v_order_id uuid;
begin
  v_order_id := tests.make_order('b0000000-0000-0000-0000-000000000001');
  perform tests.act_as('b0000000-0000-0000-0000-000000000003');

  perform tests.expect_error(
    'SM-8: unknown status MAGICAL raises VALIDATION_ERROR',
    format('select public.change_order_status(%L, ''MAGICAL'')', v_order_id),
    '%VALIDATION_ERROR%'
  );
  perform tests.reset_role();
end;
$$;
rollback to savepoint sm8;

rollback;
