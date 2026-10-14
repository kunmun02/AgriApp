-- 015_notifications.sql

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
