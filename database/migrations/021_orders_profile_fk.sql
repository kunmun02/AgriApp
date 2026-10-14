-- 021_orders_profile_fk.sql
-- Adds a foreign key from orders.user_id → public.profiles.id so that
-- PostgREST can resolve the orders→profiles relationship for embedded selects.
--
-- Why this is safe:
--   • profiles.id = auth.users.id (set in 001_profiles.sql)
--   • orders.user_id already references auth.users(id)
--   • Every auth user gets a profile row via the handle_new_user trigger
--   • The FK is NOT VALID initially so it runs without a full-table scan,
--     then validated in the same transaction — safe on existing data.

alter table public.orders
  add constraint orders_user_id_fkey_profiles
  foreign key (user_id) references public.profiles(id) on delete restrict;
