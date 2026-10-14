-- 008_inventory_transactions.sql

create table public.inventory_transactions (
  id               uuid primary key default gen_random_uuid(),
  product_id       uuid not null references public.products(id) on delete cascade,
  transaction_type text not null check (transaction_type in
                     ('PURCHASE','ADJUSTMENT','ORDER','ORDER_CANCEL','RETURN','INITIAL')),
  quantity_delta   integer not null check (quantity_delta <> 0),
  reference_type   text,
  reference_id     uuid,
  reason           text,
  created_by       uuid references auth.users(id) on delete set null,
  created_at       timestamptz not null default now()
);
