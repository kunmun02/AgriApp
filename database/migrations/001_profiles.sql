-- 001_profiles.sql
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
