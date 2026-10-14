-- 020_broadcast_rpc.sql
-- Adds a server-side broadcast_notification RPC so admins can send a SYSTEM
-- notification to all active customers in a single atomic INSERT … SELECT,
-- bypassing the need for a client-side RLS INSERT policy on notifications.
--
-- Replaces the previous N-sequential-inserts approach in the Flutter client
-- (AdminNotificationRepository.broadcast), which was blocked by RLS because
-- there is no INSERT policy for admins on public.notifications — inserts are
-- intentionally gated to security-definer RPCs only (see 018_rls.sql comment).

create or replace function public.broadcast_notification(
  p_title text,
  p_body  text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_sent  integer;
begin
  -- Only admins may broadcast.
  if v_admin is null or not public.is_admin() then
    raise exception '{"code":"FORBIDDEN","message":"admin role required"}'
      using errcode = 'P0001';
  end if;

  -- Validate inputs (mirrors the check constraint on notifications.title).
  if coalesce(trim(p_title), '') = '' then
    raise exception '{"code":"VALIDATION_ERROR","message":"title is required"}'
      using errcode = 'P0001';
  end if;

  if char_length(trim(p_title)) > 120 then
    raise exception '{"code":"VALIDATION_ERROR","message":"title must be 120 characters or fewer"}'
      using errcode = 'P0001';
  end if;

  if coalesce(trim(p_body), '') = '' then
    raise exception '{"code":"VALIDATION_ERROR","message":"body is required"}'
      using errcode = 'P0001';
  end if;

  -- Insert one SYSTEM notification per active customer in a single statement.
  -- security definer means RLS on notifications is bypassed for this function.
  insert into public.notifications (user_id, type, title, body, data, is_read)
  select
    p.id,
    'SYSTEM',
    trim(p_title),
    trim(p_body),
    '{}'::jsonb,
    false
  from public.profiles p
  where p.role = 'customer'
    and p.is_active = true;

  get diagnostics v_sent = row_count;

  return jsonb_build_object('sent', v_sent);
end;
$$;
