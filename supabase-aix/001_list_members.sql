-- AIX Supabase project (xenrnhgxwhujyvtpwmsk), NOT jaguar-smart.
-- Lets an AIX admin see and manage the AIX team from the control-center app (/app → الفريق → AIX).
-- team_members has RLS on and no policies, so a plain select returns nothing; these two
-- security-definer functions are the only new ways in, and both require has_role(array['admin']).
-- Changing permissions still goes through the existing set_member_permissions().
-- Run once by hand in the AIX project's SQL editor.

-- Everyone on the AIX team with their main role and permissions.
create or replace function public.aix_members()
returns table (email text, name text, role text, permissions text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_role(array['admin']) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
  select tm.email::text, tm.name::text, tm.role::text, coalesce(tm.permissions, '{}')::text[]
  from public.team_members tm
  order by tm.added_at nulls last, tm.email;
end $$;
revoke execute on function public.aix_members() from public, anon;
grant execute on function public.aix_members() to authenticated;

-- Remove someone from the AIX team. set_member_permissions with an empty list keeps their old
-- role (and so their access), so removal needs its own function. An admin cannot remove themselves.
create or replace function public.aix_remove_member(p_email text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_role(array['admin']) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if lower(coalesce(p_email, '')) = lower(coalesce(auth.jwt() ->> 'email', '')) then
    raise exception 'cannot remove yourself';
  end if;
  delete from public.team_members where lower(email) = lower(p_email);
end $$;
revoke execute on function public.aix_remove_member(text) from public, anon;
grant execute on function public.aix_remove_member(text) to authenticated;
