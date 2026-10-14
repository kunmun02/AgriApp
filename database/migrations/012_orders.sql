-- 012_orders.sql

create table public.orders (
  id              uuid primary key default gen_random_uuid(),
  order_number    text not null unique,
  user_id         uuid not null references auth.users(id) on delete restrict,
  status          text not null default 'NEW' check (status in
                    ('NEW','CONFIRMED','PROCESSING','PACKED','SHIPPED','OUT_FOR_DELIVERY','DELIVERED','CANCELLED')),
  subtotal        numeric(12,2) not null check (subtotal >= 0),
  delivery_charge numeric(10,2) not null default 0 check (delivery_charge >= 0),
  tax             numeric(12,2) not null default 0 check (tax >= 0),
  discount        numeric(12,2) not null default 0 check (discount >= 0),
  total           numeric(12,2) not null check (total >= 0),
  shipping_snapshot jsonb not null,
  idempotency_key uuid not null,
  cancel_reason   text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- idempotent checkout: same key + same user can never produce two orders
  unique (user_id, idempotency_key)
);

create trigger orders_updated_at
before update on public.orders
for each row execute function public.set_updated_at();
