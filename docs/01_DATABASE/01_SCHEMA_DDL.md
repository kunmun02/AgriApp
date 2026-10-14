# 01_SCHEMA_DDL.md — Migrations 001–017 (complete SQL)

Files live in `database/migrations/` with EXACTLY these names, applied in order.
Rules: append-only; never edit an applied migration; fresh install = `supabase db reset` runs all 20 in order.
Conventions: all tables in `public`; `timestamptz` everywhere; money `NUMERIC`; UUID PKs via `gen_random_uuid()`.

---

## 001_profiles.sql

```sql
-- Profiles + auth integration + admin helper + guard triggers
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  email       text not null,
  phone       text,
  role        text not null default 'customer' check (role in ('customer','admin')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Generic updated_at maintenance (reused by later migrations)
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Auto-create a profile for every new auth user (role always starts as customer)
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Admin check helper used by RLS policies and RPCs everywhere
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and is_active
  );
$$;

-- Column-level protection RLS cannot express:
--  - nobody changes profiles.id
--  - only admins (or the postgres/migration role) change role / is_active / email
create or replace function public.profiles_guard()
returns trigger language plpgsql as $$
begin
  if new.id is distinct from old.id then
    raise exception '{"code":"VALIDATION_ERROR","message":"profile id is immutable"}'
      using errcode = 'P0001';
  end if;
  if current_user = 'postgres' or current_user = 'supabase_admin' then
    return new;  -- SQL editor / migrations / first-admin bootstrap
  end if;
  if not public.is_admin()
     and (
       new.role      is distinct from old.role
       or new.is_active is distinct from old.is_active
       or new.email  is distinct from old.email
     ) then
    raise exception '{"code":"FORBIDDEN","message":"only admins can change role/status/email"}'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger profiles_guard_trigger
before update on public.profiles
for each row execute function public.profiles_guard();

create trigger profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();
```

---

## 002_categories.sql

```sql
create table public.categories (
  id            uuid primary key default gen_random_uuid(),
  parent_id     uuid references public.categories(id) on delete restrict,
  name          text not null check (char_length(trim(name)) between 2 and 60),
  slug          text not null unique,
  description   text,
  image_path    text,
  display_order integer not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger categories_updated_at
before update on public.categories
for each row execute function public.set_updated_at();
```

---

## 003_category_attributes.sql

```sql
create table public.category_attributes (
  id             uuid primary key default gen_random_uuid(),
  category_id    uuid not null references public.categories(id) on delete cascade,
  name           text not null check (char_length(trim(name)) between 2 and 60),
  attribute_key  text not null check (attribute_key ~ '^[a-z][a-z0-9_]{1,39}$'),
  data_type      text not null check (data_type in ('text','number','boolean','select')),
  options        jsonb not null default '[]' check (jsonb_typeof(options) = 'array'),
  is_required    boolean not null default false,
  display_order  integer not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (category_id, attribute_key)
);

-- select needs 1–20 options; other types must have empty options
alter table public.category_attributes
  add constraint category_attributes_options_shape check (
    (data_type = 'select' and jsonb_array_length(options) between 1 and 20)
    or (data_type in ('text','number','boolean') and jsonb_array_length(options) = 0)
  );

create trigger category_attributes_updated_at
before update on public.category_attributes
for each row execute function public.set_updated_at();
```

---

## 004_products.sql

```sql
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
```

---

## 005_product_attributes.sql

```sql
create table public.product_attributes (
  id                    uuid primary key default gen_random_uuid(),
  product_id            uuid not null references public.products(id) on delete cascade,
  category_attribute_id uuid not null references public.category_attributes(id) on delete restrict,
  value_text            text,
  value_number          numeric,
  value_boolean         boolean,
  value_json            jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (product_id, category_attribute_id),
  -- exactly one of the four value columns is set, matching the attribute data_type
  constraint product_attributes_single_value check (
    (case when value_text    is not null then 1 else 0 end) +
    (case when value_number  is not null then 1 else 0 end) +
    (case when value_boolean is not null then 1 else 0 end) +
    (case when value_json    is not null then 1 else 0 end) = 1
  )
);

create trigger product_attributes_updated_at
before update on public.product_attributes
for each row execute function public.set_updated_at();
```

---

## 006_product_images.sql

```sql
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
```

---

## 007_inventory.sql

```sql
create table public.inventory (
  product_id        uuid primary key references public.products(id) on delete cascade,
  quantity          integer not null default 0 check (quantity >= 0),
  reserved_quantity integer not null default 0 check (reserved_quantity >= 0),
  min_stock_level   integer not null default 5 check (min_stock_level >= 0),
  updated_at        timestamptz not null default now()
);
```

---

## 008_inventory_transactions.sql

```sql
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
```

---

## 009_addresses.sql

```sql
create table public.addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  label          text not null default 'Home' check (char_length(label) between 1 and 30),
  recipient_name text not null check (char_length(trim(recipient_name)) between 2 and 80),
  phone          text not null check (phone ~ '^[6-9][0-9]{9}$'),
  line1          text not null check (char_length(trim(line1)) between 3 and 160),
  line2          text,
  city           text not null check (char_length(trim(city)) between 2 and 60),
  state          text not null,  -- validated in UI against the 36-item Indian states list
  postal_code    text not null check (postal_code ~ '^[1-9][0-9]{5}$'),
  country        text not null default 'India',
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- at most one default address per user
create unique index addresses_one_default_per_user
  on public.addresses (user_id) where is_default;

create trigger addresses_updated_at
before update on public.addresses
for each row execute function public.set_updated_at();
```

---

## 010_carts.sql

```sql
create table public.carts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger carts_updated_at
before update on public.carts
for each row execute function public.set_updated_at();
```

---

## 011_cart_items.sql

```sql
create table public.cart_items (
  id         uuid primary key default gen_random_uuid(),
  cart_id    uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity   integer not null check (quantity between 1 and 99),
  created_at timestamptz not null default now(),
  unique (cart_id, product_id)
);
```

---

## 012_orders.sql

```sql
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
```

---

## 013_order_items.sql

```sql
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
```

---

## 014_payments.sql

```sql
create table public.payments (
  id                 uuid primary key default gen_random_uuid(),
  order_id           uuid not null unique references public.orders(id) on delete cascade,
  method             text not null default 'COD' check (method in ('COD')),
  status             text not null default 'PENDING' check (status in ('PENDING','COLLECTED','CANCELLED')),
  amount             numeric(12,2) not null check (amount >= 0),
  provider_reference text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create trigger payments_updated_at
before update on public.payments
for each row execute function public.set_updated_at();
```

---

## 015_notifications.sql

```sql
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  type       text not null check (type in ('ORDER_STATUS','SYSTEM')),
  title      text not null check (char_length(title) between 1 and 120),
  body       text not null,
  data       jsonb not null default '{}',
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);
```

---

## 016_app_settings.sql

```sql
-- Single-row settings table: id is forced to true, so exactly one row can exist.
create table public.app_settings (
  id                      boolean primary key default true check (id),
  delivery_charge         numeric(10,2) not null default 40.00 check (delivery_charge >= 0),
  free_delivery_threshold numeric(10,2) not null default 500.00 check (free_delivery_threshold >= 0),
  updated_at              timestamptz not null default now()
);

insert into public.app_settings (id) values (true);

create trigger app_settings_updated_at
before update on public.app_settings
for each row execute function public.set_updated_at();
```

---

## 017_indexes.sql

```sql
create extension if not exists pg_trgm;

create index categories_parent_idx        on public.categories(parent_id);
create index categories_active_idx        on public.categories(is_active, display_order);
create index category_attributes_cat_idx  on public.category_attributes(category_id);
create index products_category_idx        on public.products(category_id);
create index products_published_idx       on public.products(is_active, is_published);
create index products_name_trgm_idx       on public.products using gin (name gin_trgm_ops);
create index product_attributes_prod_idx  on public.product_attributes(product_id);
create index product_attributes_attr_idx  on public.product_attributes(category_attribute_id);
create index product_images_prod_idx      on public.product_images(product_id, display_order);
create index inv_tx_prod_idx              on public.inventory_transactions(product_id, created_at desc);
create index addresses_user_idx           on public.addresses(user_id);
create index cart_items_product_idx       on public.cart_items(product_id);
create index orders_user_idx              on public.orders(user_id, created_at desc);
create index orders_status_idx            on public.orders(status, created_at desc);
create index order_items_order_idx        on public.order_items(order_id);
create index notifications_user_idx       on public.notifications(user_id, created_at desc);
create index notifications_unread_idx     on public.notifications(user_id) where not is_read;
```

---

## Post-migration check (017 applied)

```sql
select table_name from information_schema.tables
 where table_schema = 'public' order by table_name;
-- must list exactly: addresses, app_settings, cart_items, carts, categories,
-- category_attributes, inventory, inventory_transactions, notifications, order_items,
-- orders, payments, product_attributes, product_images, products, profiles
```
