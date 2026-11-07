-- Control-center app (/app): people sign up with their own email, then the owner grants access from the app.
-- Owner = team_members row with role 'admin' and company 'jaguar'.
-- Run once by hand in the Supabase SQL editor.

create or replace function public.app_is_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.team_members
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and role = 'admin' and company = 'jaguar'
  );
$$;
revoke execute on function public.app_is_owner() from public, anon;
grant execute on function public.app_is_owner() to authenticated;

-- Everyone with an account, newest sign-ups without access first. Owner only.
create or replace function public.app_people()
returns table (
  user_id uuid, email text, full_name text, created_at timestamptz, last_sign_in_at timestamptz,
  confirmed boolean, team_role text, team_company text, shahi_role text, shahi_active boolean
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.app_is_owner() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
  select u.id, u.email::text, coalesce(u.raw_user_meta_data ->> 'full_name', '')::text,
         u.created_at, u.last_sign_in_at, (u.email_confirmed_at is not null),
         t.role, t.company, s.role, s.active
  from auth.users u
  left join public.team_members t on lower(t.email) = lower(u.email)
  left join public.shahi_staff s on s.user_id = u.id
  order by (t.email is null and (s.user_id is null or not s.active)) desc, u.created_at desc;
end $$;
revoke execute on function public.app_people() from public, anon;
grant execute on function public.app_people() to authenticated;

-- Give or change one person's access. Empty role = remove that access. Owner only; the owner cannot change themselves.
create or replace function public.app_set_access(p_user uuid, p_company text, p_role text, p_shahi_role text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_email text; v_name text;
begin
  if not public.app_is_owner() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select u.email, coalesce(u.raw_user_meta_data ->> 'full_name', '') into v_email, v_name
  from auth.users u where u.id = p_user;
  if v_email is null then raise exception 'no such user'; end if;
  if lower(v_email) = lower(coalesce(auth.jwt() ->> 'email', '')) then
    raise exception 'owner cannot change their own access';
  end if;

  -- Jaguar Smart / Tuya Suez team
  if coalesce(p_role, '') = '' then
    delete from public.team_members where lower(email) = lower(v_email);
  else
    if p_role not in ('admin','crm','inventory','installs') or p_company not in ('jaguar','tuya-suez') then
      raise exception 'bad role or company';
    end if;
    update public.team_members set role = p_role, company = p_company where lower(email) = lower(v_email);
    if not found then
      insert into public.team_members (email, role, company, display_name)
      values (lower(v_email), p_role, p_company, nullif(v_name, ''));
    end if;
  end if;

  -- Shahi
  if coalesce(p_shahi_role, '') = '' then
    update public.shahi_staff set active = false where user_id = p_user;
  else
    if p_shahi_role not in ('admin','sales','ops','chef') then raise exception 'bad shahi role'; end if;
    insert into public.shahi_staff (user_id, email, full_name, role, active)
    values (p_user, v_email, coalesce(nullif(v_name, ''), split_part(v_email, '@', 1)), p_shahi_role, true)
    on conflict (user_id) do update set role = excluded.role, active = true;
  end if;
end $$;
revoke execute on function public.app_set_access(uuid, text, text, text) from public, anon;
grant execute on function public.app_set_access(uuid, text, text, text) to authenticated;
