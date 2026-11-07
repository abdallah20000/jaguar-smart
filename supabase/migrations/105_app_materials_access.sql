-- Control-center app (/app): the owner also manages access to the building-materials store
-- (مواد البناء) from the Team page. Builds on 104 (app_is_owner) and 100/101 (mat_profiles,
-- mat_staff_invites, mat_ensure_profile). Owner only; the owner cannot change themselves.
-- Run once by hand in the Supabase SQL editor.

-- Materials access of every account: the profile role (if any) and a pending invite (if any).
create or replace function public.app_mat_access()
returns table (user_id uuid, mat_role text, invite_role text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.app_is_owner() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
  select u.id, p.role, i.role
  from auth.users u
  left join public.mat_profiles p on p.user_id = u.id
  left join public.mat_staff_invites i on lower(i.email) = lower(u.email);
end $$;
revoke execute on function public.app_mat_access() from public, anon;
grant execute on function public.app_mat_access() to authenticated;

-- Set one person's materials role: '' (none), 'staff' or 'admin'.
-- With a profile row: change its role (none = back to customer). Without one: keep an invite by
-- email, which mat_ensure_profile() applies on their first sign-in to the store.
create or replace function public.app_set_mat_access(p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_email text;
begin
  if not public.app_is_owner() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select u.email into v_email from auth.users u where u.id = p_user;
  if v_email is null then raise exception 'no such user'; end if;
  if lower(v_email) = lower(coalesce(auth.jwt() ->> 'email', '')) then
    raise exception 'owner cannot change their own access';
  end if;

  if coalesce(p_role, '') = '' then
    update public.mat_profiles set role = 'customer' where user_id = p_user and role in ('staff','admin');
    delete from public.mat_staff_invites where lower(email) = lower(v_email);
    return;
  end if;

  if p_role not in ('staff','admin') then raise exception 'bad materials role'; end if;
  update public.mat_profiles set role = p_role where user_id = p_user;
  if not found then
    delete from public.mat_staff_invites where lower(email) = lower(v_email) and email <> lower(v_email);
    insert into public.mat_staff_invites (email, role) values (lower(v_email), p_role)
    on conflict (email) do update set role = excluded.role;
  end if;
end $$;
revoke execute on function public.app_set_mat_access(uuid, text) from public, anon;
grant execute on function public.app_set_mat_access(uuid, text) to authenticated;
