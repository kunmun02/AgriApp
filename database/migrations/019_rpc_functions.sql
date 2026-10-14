-- 019_rpc_functions.sql
-- All trusted business operations. RPCs are security definer and re-check authorization explicitly.
-- Every business failure raises SQLSTATE P0001 with a JSON message.

-- ------------------------------------------------------------------
-- create_order(p_address_id, p_idempotency_key) -> jsonb
-- Atomic COD checkout. Caller must be an authenticated customer.
-- Steps, all inside ONE transaction:
--   1. replay check on (user_id, idempotency_key) -> returns original order
--   2. validate address ownership
--   3. read cart items joined to purchasable products
--   4. lock inventory rows FOR UPDATE (deterministic product_id order)
--   5. verify stock; compute totals from DB prices + tax_percent + app_settings
--   6. insert order + items + COD payment; decrement inventory; write tx log
--   7. delete purchased cart items
-- Returns: {"duplicate":bool,"order_id":uuid,"order_number":text,"total":numeric}
-- ------------------------------------------------------------------
create or replace function public.create_order(
  p_address_id      uuid,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user       uuid := auth.uid();
  v_cart_id    uuid;
  v_address    public.addresses%rowtype;
  v_settings   public.app_settings%rowtype;
  v_row        record;
  v_item       jsonb;
  v_items      jsonb := '[]'::jsonb;
  v_line_total numeric(12,2);
  v_line_tax   numeric(12,2);
  v_subtotal   numeric(12,2) := 0;
  v_tax        numeric(12,2) := 0;
  v_delivery   numeric(10,2) := 0;
  v_total      numeric(12,2);
  v_order_id   uuid;
  v_existing   uuid;
  v_snapshot   jsonb;
  v_number     text;
begin
  if v_user is null then
    raise exception '{"code":"AUTH_REQUIRED","message":"sign in required"}'
      using errcode = 'P0001';
  end if;

  -- 1. idempotent replay
  select id into v_existing from public.orders
   where user_id = v_user and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return jsonb_build_object('duplicate', true, 'order_id', v_existing);
  end if;

  -- 2. address ownership
  select * into v_address from public.addresses
   where id = p_address_id and user_id = v_user;
  if v_address.id is null then
    raise exception '{"code":"NOT_FOUND","message":"address not found"}'
      using errcode = 'P0001';
  end if;

  -- 3. cart
  select id into v_cart_id from public.carts where user_id = v_user;
  if v_cart_id is null then
    raise exception '{"code":"VALIDATION_ERROR","message":"cart is empty"}'
      using errcode = 'P0001';
  end if;

  select * into v_settings from public.app_settings where id = true;

  v_snapshot := jsonb_build_object(
    'recipient_name', v_address.recipient_name,
    'phone',          v_address.phone,
    'line1',          v_address.line1,
    'line2',          v_address.line2,
    'city',           v_address.city,
    'state',          v_address.state,
    'postal_code',    v_address.postal_code,
    'country',        v_address.country
  );

  -- 4+5. lock inventory rows in product_id order (deadlock-safe), verify stock,
  --      compute all money from DB values. One read -> jsonb -> no drift.
  for v_row in
    select ci.product_id::text   as product_id,
           ci.quantity,
           p.name, p.sku, p.price, p.tax_percent,
           (inv.quantity - inv.reserved_quantity) as available
    from public.cart_items ci
    join public.products  p   on p.id  = ci.product_id and p.is_active and p.is_published
    join public.inventory inv on inv.product_id = p.id
    where ci.cart_id = v_cart_id
    order by ci.product_id
    for update of inv
  loop
    if v_row.quantity > v_row.available then
      raise exception
        '{"code":"OUT_OF_STOCK","message":"insufficient stock for %","details":{"product_id":"%","available":%}}',
        v_row.name, v_row.product_id, v_row.available
        using errcode = 'P0001';
    end if;

    v_line_total := v_row.price * v_row.quantity;
    v_line_tax   := round(v_line_total * v_row.tax_percent / 100, 2);
    v_subtotal   := v_subtotal + v_line_total;
    v_tax        := v_tax + v_line_tax;

    v_items := v_items || jsonb_build_object(
      'product_id',  v_row.product_id,
      'quantity',    v_row.quantity,
      'name',        v_row.name,
      'sku',         v_row.sku,
      'price',       v_row.price,
      'tax_percent', v_row.tax_percent,
      'line_total',  v_line_total,
      'line_tax',    v_line_tax
    );
  end loop;

  if jsonb_array_length(v_items) = 0 then
    raise exception '{"code":"VALIDATION_ERROR","message":"cart is empty or has no purchasable items"}'
      using errcode = 'P0001';
  end if;

  -- Strict cart rule: every cart item must be purchasable. No silent partial orders.
  if (select count(*) from public.cart_items where cart_id = v_cart_id)
     <> jsonb_array_length(v_items) then
    raise exception
      '{"code":"PRODUCT_UNAVAILABLE","message":"some items are no longer available","details":{"skipped":%}}',
      coalesce((
        select jsonb_agg(distinct p.name)
        from public.cart_items ci
        join public.products p on p.id = ci.product_id
        where ci.cart_id = v_cart_id
          and (not p.is_active or not p.is_published
               or not exists (select 1 from public.inventory inv where inv.product_id = p.id))
      ), '[]'::jsonb)
      using errcode = 'P0001';
  end if;

  if v_subtotal >= v_settings.free_delivery_threshold then
    v_delivery := 0;
  else
    v_delivery := v_settings.delivery_charge;
  end if;

  v_total := v_subtotal + v_tax + v_delivery;

  v_number := 'AGR-' || to_char(now() at time zone 'utc', 'YYMMDD') || '-' ||
              upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));

  -- 6a. order header
  insert into public.orders
    (order_number, user_id, subtotal, delivery_charge, tax, discount, total,
     shipping_snapshot, idempotency_key)
  values
    (v_number, v_user, v_subtotal, v_delivery, v_tax, 0, v_total,
     v_snapshot, p_idempotency_key)
  returning id into v_order_id;

  -- 6b. items + inventory + tx log + cart cleanup
  for v_item in select * from jsonb_array_elements(v_items)
  loop
    insert into public.order_items
      (order_id, product_id, product_name_snapshot, sku_snapshot, unit_price,
       tax_percent, quantity, line_total, line_tax)
    values
      (v_order_id,
       (v_item->>'product_id')::uuid,
       v_item->>'name',
       v_item->>'sku',
       (v_item->>'price')::numeric,
       (v_item->>'tax_percent')::numeric,
       (v_item->>'quantity')::int,
       (v_item->>'line_total')::numeric,
       (v_item->>'line_tax')::numeric);

    update public.inventory
       set quantity = quantity - (v_item->>'quantity')::int,
           updated_at = now()
     where product_id = (v_item->>'product_id')::uuid;

    insert into public.inventory_transactions
      (product_id, transaction_type, quantity_delta, reference_type, reference_id, reason, created_by)
    values
      ((v_item->>'product_id')::uuid, 'ORDER', -(v_item->>'quantity')::int,
       'ORDER', v_order_id, 'COD checkout', v_user);

    delete from public.cart_items
     where cart_id = v_cart_id and product_id = (v_item->>'product_id')::uuid;
  end loop;

  -- 6c. COD payment
  insert into public.payments (order_id, method, status, amount)
  values (v_order_id, 'COD', 'PENDING', v_total);

  return jsonb_build_object('duplicate', false, 'order_id', v_order_id,
                            'order_number', v_number, 'total', v_total);
end;
$$;

-- ------------------------------------------------------------------
-- change_order_status(p_order_id, p_target_status, p_reason) -> jsonb
-- Admin only. Enforces the state machine (Master §3.6).
-- CANCELLED  -> restocks inventory + writes ORDER_CANCEL tx + payment CANCELLED (requires p_reason)
-- DELIVERED  -> payment PENDING -> COLLECTED
-- Always     -> ORDER_STATUS notification to the order owner.
-- ------------------------------------------------------------------
create or replace function public.change_order_status(
  p_order_id      uuid,
  p_target_status text,
  p_reason        text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin  uuid := auth.uid();
  v_order  public.orders%rowtype;
  v_item   record;
begin
  if v_admin is null or not public.is_admin() then
    raise exception '{"code":"FORBIDDEN","message":"admin role required"}'
      using errcode = 'P0001';
  end if;

  if p_target_status not in
     ('CONFIRMED','PROCESSING','PACKED','SHIPPED','OUT_FOR_DELIVERY','DELIVERED','CANCELLED') then
    raise exception '{"code":"VALIDATION_ERROR","message":"unknown target status"}'
      using errcode = 'P0001';
  end if;

  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null then
    raise exception '{"code":"NOT_FOUND","message":"order not found"}'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from (values
      ('NEW','CONFIRMED'),            ('NEW','CANCELLED'),
      ('CONFIRMED','PROCESSING'),     ('CONFIRMED','CANCELLED'),
      ('PROCESSING','PACKED'),        ('PROCESSING','CANCELLED'),
      ('PACKED','SHIPPED'),
      ('SHIPPED','OUT_FOR_DELIVERY'),
      ('OUT_FOR_DELIVERY','DELIVERED')
    ) as t(frm, too)
    where t.frm = v_order.status and t.too = p_target_status
  ) then
    raise exception
      '{"code":"CONFLICT","message":"illegal transition % -> %","details":{"from":"%","to":"%"}}',
      v_order.status, p_target_status, v_order.status, p_target_status
      using errcode = 'P0001';
  end if;

  if p_target_status = 'CANCELLED' and coalesce(trim(p_reason), '') = '' then
    raise exception '{"code":"VALIDATION_ERROR","message":"cancel reason required"}'
      using errcode = 'P0001';
  end if;

  update public.orders
     set status = p_target_status,
         cancel_reason = case when p_target_status = 'CANCELLED' then p_reason
                              else cancel_reason end
   where id = p_order_id;

  if p_target_status = 'CANCELLED' then
    for v_item in select * from public.order_items
                   where order_id = p_order_id and product_id is not null
    loop
      update public.inventory
         set quantity = quantity + v_item.quantity, updated_at = now()
       where product_id = v_item.product_id;

      insert into public.inventory_transactions
        (product_id, transaction_type, quantity_delta, reference_type, reference_id, reason, created_by)
      values
        (v_item.product_id, 'ORDER_CANCEL', v_item.quantity, 'ORDER', p_order_id,
         p_reason, v_admin);
    end loop;

    update public.payments set status = 'CANCELLED' where order_id = p_order_id;
  end if;

  if p_target_status = 'DELIVERED' then
    update public.payments set status = 'COLLECTED' where order_id = p_order_id;
  end if;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    v_order.user_id,
    'ORDER_STATUS',
    'Order ' || v_order.order_number || ' updated',
    'Your order status is now ' || replace(p_target_status, '_', ' ') || '.',
    jsonb_build_object('order_id', p_order_id, 'status', p_target_status)
  );

  return jsonb_build_object('order_id', p_order_id, 'status', p_target_status);
end;
$$;

-- ------------------------------------------------------------------
-- adjust_inventory(p_product_id, p_delta, p_transaction_type, p_reason) -> jsonb
-- Admin only. Stock can never go below 0. Writes an inventory_transactions row.
-- p_transaction_type must be one of: PURCHASE, ADJUSTMENT, RETURN, INITIAL.
-- Returns {"product_id":uuid,"new_quantity":int}
-- ------------------------------------------------------------------
create or replace function public.adjust_inventory(
  p_product_id       uuid,
  p_delta            integer,
  p_transaction_type text,
  p_reason           text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_new   integer;
begin
  if v_admin is null or not public.is_admin() then
    raise exception '{"code":"FORBIDDEN","message":"admin role required"}'
      using errcode = 'P0001';
  end if;

  if p_transaction_type not in ('PURCHASE','ADJUSTMENT','RETURN','INITIAL') then
    raise exception '{"code":"VALIDATION_ERROR","message":"invalid transaction type"}'
      using errcode = 'P0001';
  end if;

  if coalesce(trim(p_reason), '') = '' then
    raise exception '{"code":"VALIDATION_ERROR","message":"reason required"}'
      using errcode = 'P0001';
  end if;

  select quantity + p_delta into v_new
    from public.inventory
   where product_id = p_product_id
   for update;

  if v_new is null then
    raise exception '{"code":"NOT_FOUND","message":"inventory row not found"}'
      using errcode = 'P0001';
  end if;

  if v_new < 0 then
    raise exception
      '{"code":"VALIDATION_ERROR","message":"stock cannot go below zero","details":{"resulting":%}}',
      v_new
      using errcode = 'P0001';
  end if;

  update public.inventory set quantity = v_new, updated_at = now()
   where product_id = p_product_id;

  insert into public.inventory_transactions
    (product_id, transaction_type, quantity_delta, reference_type, reason, created_by)
  values
    (p_product_id, p_transaction_type, p_delta, 'MANUAL', p_reason, v_admin);

  return jsonb_build_object('product_id', p_product_id, 'new_quantity', v_new);
end;
$$;

-- ------------------------------------------------------------------
-- mark_notification_read(p_notification_id) -> void
-- Owner-only convenience wrapper (RLS also enforces this, RPC is explicit).
-- ------------------------------------------------------------------
create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception '{"code":"AUTH_REQUIRED","message":"sign in required"}'
      using errcode = 'P0001';
  end if;

  update public.notifications set is_read = true
   where id = p_notification_id and user_id = auth.uid();

  if not found then
    raise exception '{"code":"NOT_FOUND","message":"notification not found"}'
      using errcode = 'P0001';
  end if;
end;
$$;
