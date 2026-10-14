-- 013_order_items.sql

create table public.order_items (
  id                     uuid primary key default gen_random_uuid(),
  order_id               uuid not null references public.orders(id) on delete cascade,
  product_id             uuid references public.products(id) on delete set null, -- nullable: historical
  product_name_snapshot  text not null,
  sku_snapshot           text not null,
  unit_price             numeric(10,2) not null check (unit_price >= 0),
  tax_percent            numeric(5,2)  not null default 0 check (tax_percent between 0 and 100),
  quantity               integer not null check (quantity > 0),
  line_total             numeric(12,2) not null check (line_total >= 0),
  line_tax               numeric(12,2) not null default 0 check (line_tax >= 0)
);
