-- 003_category_attributes.sql

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
