-- 009_addresses.sql

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
