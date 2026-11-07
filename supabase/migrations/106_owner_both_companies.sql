-- The owner (abdallahsad35@gmail.com) works in both companies: Jaguar Smart as before, and Tuya Suez
-- from the Tuya Suez pages. Nobody else changes: everyone else's my_company() is exactly their
-- team_members.company, as in 004.
--
-- How: on the Tuya Suez pages, once the owner is signed in, his requests carry the header
-- "x-company: tuya-suez". PostgREST puts request headers in request.headers for that one request
-- (transaction-local), so this is safe with connection pooling. my_company() honours the header only
-- for an admin listed in multi_company_users and only for a known company. All of 004 follows
-- (company isolation policies, column defaults, JS-Q-/Q- quote numbers, the same-company guards).
-- Without the header (Jaguar pages, the /app control center, server jobs) he is Jaguar, as today.
-- Run once by hand in the Supabase SQL editor (project jaguar-smart).

create table if not exists public.multi_company_users (
  email text primary key check (email = lower(email))
);
alter table public.multi_company_users enable row level security;   -- no policies: not readable from the API
revoke all on public.multi_company_users from anon, authenticated;
insert into public.multi_company_users (email) values ('abdallahsad35@gmail.com') on conflict do nothing;

create or replace function public.my_company()
returns text language sql stable security definer set search_path = '' as $$
  select case
    when t.role = 'admin'
     and exists (select 1 from public.multi_company_users m where m.email = lower(t.email))
     and (nullif(current_setting('request.headers', true), '')::json ->> 'x-company') in ('jaguar', 'tuya-suez')
    then nullif(current_setting('request.headers', true), '')::json ->> 'x-company'
    else t.company
  end
  from public.team_members t
  where lower(t.email) = lower(coalesce(auth.jwt() ->> 'email', ''));
$$;
revoke execute on function public.my_company() from public, anon;
grant execute on function public.my_company() to authenticated;

-- Which companies this account may work in. The pages use it to decide whether to send the header.
create or replace function public.my_companies()
returns text[] language sql stable security definer set search_path = '' as $$
  select case
    when t.role = 'admin' and exists (select 1 from public.multi_company_users m where m.email = lower(t.email))
    then array['jaguar', 'tuya-suez']
    else array[t.company]
  end
  from public.team_members t
  where lower(t.email) = lower(coalesce(auth.jwt() ->> 'email', ''));
$$;
revoke execute on function public.my_companies() from public, anon;
grant execute on function public.my_companies() to authenticated;
