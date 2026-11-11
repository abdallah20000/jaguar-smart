-- «نظام الشركات» Phase 1 (/sys): companies, per-company roles, people, cash book with audit.
-- STATUS: NOT RUN ANYWHERE YET. Review first, then run once by hand in the Supabase SQL editor (jaguar-smart project).
--
-- Security model
--   * Login = Supabase auth (email + password, hashed by Supabase). No passwords in these tables.
--   * memberships(user_id, company_id, role): one role per person per company; the same person can
--     hold different roles in different companies.
--   * Members see only rows of their own companies (RLS on every table).
--   * Salaries / commission % / partner shares live in a SEPARATE table (people_pay) whose RLS lets
--     only the company's OWNER read or write it. The people table itself has no money columns, so a
--     non-owner cannot reach them by any select, view or join.
--   * Cash entries are never deleted (no delete policy + delete revoked + trigger that refuses).
--     Every update writes a cash_audit row (who, when, old and new values) from a trigger.

begin;

-- ---------- companies ----------
create table if not exists public.companies (
  id         text primary key check (id ~ '^[a-z0-9-]{2,30}$'),
  name       text not null,
  color      text not null default '#F59A4A' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now()
);
insert into public.companies (id, name, color) values
  ('aix',       'AIX',       '#2EC4E6'),
  ('tuya-suez', 'Tuya Suez', '#FF6B35'),
  ('jaguar',    'Jaguar',    '#E9B44C')
on conflict (id) do nothing;

-- ---------- memberships (roles per company) ----------
-- owner = مالك/شريك, ops = مدير تشغيل, cash = كاش/حسابات, sales = مبيعات, field = ميدان/فني, stock = مخزن/مشتريات
create table if not exists public.memberships (
  user_id    uuid not null references auth.users(id) on delete cascade,
  company_id text not null references public.companies(id),
  role       text not null check (role in ('owner','ops','cash','sales','field','stock')),
  created_at timestamptz not null default now(),
  primary key (user_id, company_id)
);
create index if not exists memberships_company_idx on public.memberships(company_id);

-- ---------- helpers (security definer so they can read memberships under RLS) ----------
create or replace function public.sys_role(p_company text)
returns text language sql stable security definer set search_path = '' as $$
  select m.role from public.memberships m
  where m.user_id = auth.uid() and m.company_id = p_company;
$$;

create or replace function public.sys_is_member(p_company text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.memberships m where m.user_id = auth.uid() and m.company_id = p_company);
$$;

create or replace function public.sys_has_role(p_company text, p_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.memberships m
                 where m.user_id = auth.uid() and m.company_id = p_company and m.role = any(p_roles));
$$;

create or replace function public.sys_is_owner(p_company text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.sys_has_role(p_company, array['owner']);
$$;

-- what the app needs right after login: my companies and my role in each
create or replace function public.sys_my_companies()
returns table (company_id text, name text, color text, role text)
language sql stable security definer set search_path = '' as $$
  select c.id, c.name, c.color, m.role
  from public.memberships m join public.companies c on c.id = m.company_id
  where m.user_id = auth.uid()
  order by c.name;
$$;

-- ---------- people (no money columns here) ----------
create table if not exists public.people (
  id         uuid primary key default gen_random_uuid(),
  company_id text not null references public.companies(id),
  full_name  text not null check (length(trim(full_name)) between 2 and 80),
  role       text not null check (role in ('owner','ops','cash','sales','field','stock')),
  user_id    uuid references auth.users(id) on delete set null,
  phone      text,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists people_company_idx on public.people(company_id);

-- ---------- people_pay: salaries, commission %, partner share. OWNER ONLY. ----------
create table if not exists public.people_pay (
  person_id         uuid primary key references public.people(id) on delete cascade,
  company_id        text not null references public.companies(id),
  monthly_salary    numeric(12,2) check (monthly_salary is null or monthly_salary >= 0),
  commission_pct    numeric(5,2)  check (commission_pct is null or commission_pct between 0 and 100),
  partner_share_pct numeric(5,2)  check (partner_share_pct is null or partner_share_pct between 0 and 100),
  updated_at        timestamptz not null default now(),
  updated_by        uuid default auth.uid()
);
-- company_id must match the person's company (so an owner of company A can't price people of company B)
create or replace function public.sys_pay_company_check()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from public.people p where p.id = new.person_id and p.company_id = new.company_id) then
    raise exception 'person does not belong to this company';
  end if;
  new.updated_at := now(); new.updated_by := auth.uid();
  return new;
end $$;
drop trigger if exists people_pay_check on public.people_pay;
create trigger people_pay_check before insert or update on public.people_pay
  for each row execute function public.sys_pay_company_check();

-- ---------- cash book ----------
create table if not exists public.cash_entries (
  id          uuid primary key default gen_random_uuid(),
  company_id  text not null references public.companies(id),
  direction   text not null check (direction in ('in','out')),          -- داخل / خارج
  amount      numeric(14,2) not null check (amount > 0),
  category    text not null check (category in (
                'goods','shipping','salaries','commissions','rent','ads','transport','partner_draw'
              )),  -- بضاعة، شحن، مرتبات، عمولات، إيجار، إعلانات، مواصلات، سحب شريك
  person_id   uuid references public.people(id),
  client      text check (client is null or length(client) <= 120),
  note        text check (note is null or length(note) <= 500),
  receipt_path text,                                                     -- object in storage bucket sys-receipts
  entry_date  date not null default (now() at time zone 'Africa/Cairo')::date,
  status      text not null default 'pending' check (status in ('pending','approved')),
  created_by  uuid not null default auth.uid() references auth.users(id),
  created_at  timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz
);
create index if not exists cash_entries_company_idx on public.cash_entries(company_id, entry_date desc);

create table if not exists public.cash_audit (
  id         bigint generated always as identity primary key,
  entry_id   uuid not null references public.cash_entries(id),
  company_id text not null references public.companies(id),
  changed_by uuid,
  changed_at timestamptz not null default now(),
  fields     text[] not null,
  old_row    jsonb not null,
  new_row    jsonb not null
);
create index if not exists cash_audit_entry_idx on public.cash_audit(entry_id, changed_at desc);

-- no delete, ever
create or replace function public.sys_cash_no_delete()
returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'cash entries cannot be deleted' using errcode = '42501'; end $$;
drop trigger if exists cash_entries_no_delete on public.cash_entries;
create trigger cash_entries_no_delete before delete on public.cash_entries
  for each row execute function public.sys_cash_no_delete();

-- guard + audit on every update
create or replace function public.sys_cash_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare f text[] := '{}';
begin
  if new.company_id <> old.company_id or new.created_by <> old.created_by or new.created_at <> old.created_at then
    raise exception 'company, creator and creation time cannot change';
  end if;
  -- approving is for owner / cash only; approval stamps who and when
  if new.status <> old.status then
    if not public.sys_has_role(old.company_id, array['owner','cash']) then
      raise exception 'only owner or cash can approve' using errcode = '42501';
    end if;
    if new.status = 'approved' then new.approved_by := auth.uid(); new.approved_at := now(); end if;
  end if;
  if new.direction  is distinct from old.direction  then f := f || 'direction'; end if;
  if new.amount     is distinct from old.amount     then f := f || 'amount'; end if;
  if new.category   is distinct from old.category   then f := f || 'category'; end if;
  if new.person_id  is distinct from old.person_id  then f := f || 'person_id'; end if;
  if new.client     is distinct from old.client     then f := f || 'client'; end if;
  if new.note       is distinct from old.note       then f := f || 'note'; end if;
  if new.receipt_path is distinct from old.receipt_path then f := f || 'receipt_path'; end if;
  if new.entry_date is distinct from old.entry_date then f := f || 'entry_date'; end if;
  if new.status     is distinct from old.status     then f := f || 'status'; end if;
  if array_length(f, 1) is null then return new; end if;
  insert into public.cash_audit (entry_id, company_id, changed_by, fields, old_row, new_row)
  values (old.id, old.company_id, auth.uid(), f, to_jsonb(old), to_jsonb(new));
  return new;
end $$;
drop trigger if exists cash_entries_guard on public.cash_entries;
create trigger cash_entries_guard before update on public.cash_entries
  for each row execute function public.sys_cash_guard();

-- running balance per company (approved and pending shown separately). security_invoker => RLS of the caller applies.
create or replace view public.cash_balance with (security_invoker = true) as
  select company_id,
         coalesce(sum(case when direction = 'in' then amount else -amount end), 0)                              as balance_all,
         coalesce(sum(case when status = 'approved' then (case when direction = 'in' then amount else -amount end) end), 0) as balance_approved,
         count(*) filter (where status = 'pending')                                                              as pending_count,
         count(*) filter (where entry_date = (now() at time zone 'Africa/Cairo')::date)                          as today_count
  from public.cash_entries
  group by company_id;

-- ---------- RLS ----------
alter table public.companies    enable row level security;
alter table public.memberships  enable row level security;
alter table public.people       enable row level security;
alter table public.people_pay   enable row level security;
alter table public.cash_entries enable row level security;
alter table public.cash_audit   enable row level security;

-- nothing for anonymous visitors
revoke all on public.companies, public.memberships, public.people, public.people_pay,
              public.cash_entries, public.cash_audit, public.cash_balance from anon, public;
grant select on public.companies, public.memberships, public.people, public.cash_entries,
                public.cash_audit, public.cash_balance to authenticated;
grant insert, update on public.people, public.cash_entries to authenticated;
grant insert, update, delete on public.memberships to authenticated;
grant select, insert, update on public.people_pay to authenticated;
revoke delete on public.cash_entries, public.cash_audit from authenticated;

-- companies: members see their companies
drop policy if exists companies_read on public.companies;
create policy companies_read on public.companies for select to authenticated
  using (public.sys_is_member(id));

-- memberships: I see my own rows; an owner sees and manages the company's rows
drop policy if exists memberships_read on public.memberships;
create policy memberships_read on public.memberships for select to authenticated
  using (user_id = auth.uid() or public.sys_is_owner(company_id));
drop policy if exists memberships_owner_write on public.memberships;
create policy memberships_owner_write on public.memberships for all to authenticated
  using (public.sys_is_owner(company_id) and user_id <> auth.uid())        -- an owner cannot demote themselves
  with check (public.sys_is_owner(company_id) and user_id <> auth.uid());

-- people: members read their company; owner / ops add and edit
drop policy if exists people_read on public.people;
create policy people_read on public.people for select to authenticated
  using (public.sys_is_member(company_id));
drop policy if exists people_write on public.people;
create policy people_write on public.people for insert to authenticated
  with check (public.sys_has_role(company_id, array['owner','ops']));
drop policy if exists people_update on public.people;
create policy people_update on public.people for update to authenticated
  using (public.sys_has_role(company_id, array['owner','ops']))
  with check (public.sys_has_role(company_id, array['owner','ops']));

-- people_pay: OWNER ONLY, for read and write. This is the salary / partner-share protection.
drop policy if exists people_pay_owner on public.people_pay;
create policy people_pay_owner on public.people_pay for all to authenticated
  using (public.sys_is_owner(company_id))
  with check (public.sys_is_owner(company_id));

-- cash_entries: members read; any member adds a PENDING entry as themselves; owner / cash edit and approve
drop policy if exists cash_read on public.cash_entries;
create policy cash_read on public.cash_entries for select to authenticated
  using (public.sys_is_member(company_id));
drop policy if exists cash_insert on public.cash_entries;
create policy cash_insert on public.cash_entries for insert to authenticated
  with check (public.sys_is_member(company_id) and created_by = auth.uid()
              and status = 'pending' and approved_by is null and approved_at is null);
drop policy if exists cash_update on public.cash_entries;
create policy cash_update on public.cash_entries for update to authenticated
  using (public.sys_has_role(company_id, array['owner','cash']))
  with check (public.sys_has_role(company_id, array['owner','cash']));

-- cash_audit: read by owner / ops / cash of the company; written only by the trigger (no insert policy)
drop policy if exists cash_audit_read on public.cash_audit;
create policy cash_audit_read on public.cash_audit for select to authenticated
  using (public.sys_has_role(company_id, array['owner','ops','cash']));

-- helper execute rights
revoke execute on function public.sys_role(text), public.sys_is_member(text), public.sys_has_role(text, text[]),
                          public.sys_is_owner(text), public.sys_my_companies() from public, anon;
grant execute on function public.sys_role(text), public.sys_is_member(text), public.sys_has_role(text, text[]),
                         public.sys_is_owner(text), public.sys_my_companies() to authenticated;

-- ---------- receipts: private bucket, path = <company_id>/<uuid>.jpg ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sys-receipts', 'sys-receipts', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists sys_receipts_read on storage.objects;
create policy sys_receipts_read on storage.objects for select to authenticated
  using (bucket_id = 'sys-receipts' and public.sys_is_member(split_part(name, '/', 1)));
drop policy if exists sys_receipts_add on storage.objects;
create policy sys_receipts_add on storage.objects for insert to authenticated
  with check (bucket_id = 'sys-receipts' and public.sys_is_member(split_part(name, '/', 1)));
-- no update / delete policies on receipts: a receipt, once uploaded, stays

commit;

-- ---------- after running: first owner, by hand (replace the email) ----------
-- insert into public.memberships (user_id, company_id, role)
-- select u.id, c.id, 'owner' from auth.users u cross join public.companies c
-- where lower(u.email) = lower('OWNER_EMAIL_HERE')
-- on conflict (user_id, company_id) do update set role = 'owner';
--
-- ---------- checks to run as a NON-owner test account (should return 0 rows / error) ----------
-- select * from public.people_pay;                    -- 0 rows
-- delete from public.cash_entries where true;         -- permission denied
-- update public.cash_entries set status='approved';   -- 0 rows unless owner/cash
