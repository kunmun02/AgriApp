-- 004_products.sql

create table public.products (
  id           uuid primary key default gen_random_uuid(),
  category_id  uuid not null references public.categories(id) on delete restrict,
  name         text not null check (char_length(trim(name)) between 2 and 120),
  slug         text not null unique,
  sku          text not null unique check (sku ~ '^[A-Z0-9-]{3,40}$'),
  description  text,
  brand        text,
  price        numeric(10,2) not null check (price >= 0),
  mrp          numeric(10,2) check (mrp is null or mrp >= price),
  tax_percent  numeric(5,2)  not null default 0 check (tax_percent between 0 and 100),
  is_active    boolean not null default true,
  is_published boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger products_updated_at
before update on public.products
for each row execute function public.set_updated_at();
