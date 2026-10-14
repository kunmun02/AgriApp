-- 006_product_images.sql

create table public.product_images (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references public.products(id) on delete cascade,
  storage_path  text not null,
  is_primary    boolean not null default false,
  display_order integer not null default 0,
  created_at    timestamptz not null default now()
);

-- at most one primary image per product
create unique index product_images_one_primary
  on public.product_images (product_id) where is_primary;
