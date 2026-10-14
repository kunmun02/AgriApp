-- 014_payments.sql

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
