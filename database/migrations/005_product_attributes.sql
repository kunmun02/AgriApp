-- 005_product_attributes.sql

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
