-- 007_inventory.sql

create table public.inventory (
  product_id        uuid primary key references public.products(id) on delete cascade,
  quantity          integer not null default 0 check (quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0),
  min_stock_level   integer not null default 5 check (min_stock_level >= 0),
  updated_at        timestamptz not null default now()
);
