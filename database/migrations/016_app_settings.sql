-- 016_app_settings.sql
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
