-- create_first_admin.sql
-- Run ONCE by the project owner in Supabase Dashboard → SQL Editor.
-- NEVER run from client code. NEVER commit real email addresses to the repo.
--
-- Step 1 (Dashboard): Authentication → Users → "Add user"
--                     Enter the admin email + a strong password.
--                     (Email confirmation is disabled for MVP — user is active immediately.)
--
-- Step 2: In the SQL Editor, replace the email below and run this script.

update public.profiles
   set role = 'admin'
 where email = 'admin@yourstore.example';  -- <-- replace with the actual admin email

-- Step 3: Verify exactly one admin exists.
select id, email, role, is_active
  from public.profiles
 where role = 'admin';

-- Why the guard trigger does not block this:
-- profiles_guard (001) allows current_user = 'postgres'.
-- The SQL Editor runs as postgres. Client connections run as authenticated/anon and are blocked.
