-- 111 — لوحة الشركا at /tuya-suez/dashboard/ (one system, parametrised by company)
-- NOT RUN YET. Abdallah approves first, then it is run once in the Supabase SQL editor of the
-- same project the Tuya Suez CRM uses (snrsfpprlynixotjipmo).
--
-- Every dashboard table has a `company` column. Today only 'tuya-suez' is used; the same tables and
-- functions can later serve another company page with its own rows. Nothing existing is changed or dropped.
--
--   tsd_access_requests  one row per new sign-up (made by a trigger on auth.users). pending/approved/revoked.
--   tsd_memberships      who may use which company, with which role, and which areas a staff member sees.
--                        A new auth user has NO row here, so every policy below returns nothing for them:
--                        they only see «حسابك مستني موافقة».
--                        Only an owner (role 'owner' in that company) can insert/update/delete memberships.
--   tsd_areas            each area and its owner. Changeable from the dashboard.
--   tsd_area_history     who moved an area to whom (written by the functions only).
--   tsd_jobs             «بطاقة تسليم» per job: بضاعة ← فنيين ← تركيب ← تحصيل.
--   tsd_tasks            tasks under an area, with an assignee.
--   tsd_approvals        things waiting for the area owner's approval.
--   tsd_comments         comments by any member who can see the thing.
--   tsd_crm()            READ-ONLY live view of the CRM tables (leads + last follow-up, quotations, inventory,
--                        installations) for members, per area they can see. It is a STABLE function, so it
--                        cannot write; the CRM's own tables, policies and company isolation are untouched.
--
-- Roles: owner (مالك: everything + manages access), admin (أدمن: sees everything, edits/approves only in
-- areas he owns), staff (موظف: sees only the areas in see_areas or that he owns).
-- Editing and approving in an area = only its owner. Everyone else who can see it can only comment.
-- Planned admins: عبدالله (owner), أحمد مصطفى، عمر (admin). They sign up from the page and the owner
-- approves them in «طلبات الدخول». No invites are sent and no one else's email is stored here.

begin;

-- ---------- helpers ----------
create or replace function public.tsd_me()
returns text language sql stable security definer set search_path = '' as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;
revoke execute on function public.tsd_me() from public, anon;
grant execute on function public.tsd_me() to authenticated;

-- ---------- access requests (every sign-up lands here) ----------
create table if not exists public.tsd_access_requests (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text not null,
  full_name  text,
  created_at timestamptz not null default now(),
  status     text not null default 'pending' check (status in ('pending','approved','revoked')),
  decided_by text,
  decided_at timestamptz
);
alter table public.tsd_access_requests enable row level security;

create or replace function public.tsd_on_signup()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.tsd_access_requests (user_id, email, full_name)
  values (new.id, lower(new.email), nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''))
  on conflict (user_id) do nothing;
  return new;
end $$;
revoke execute on function public.tsd_on_signup() from public, anon, authenticated;
drop trigger if exists tsd_on_signup on auth.users;
create trigger tsd_on_signup after insert on auth.users for each row execute function public.tsd_on_signup();

-- ---------- memberships ----------
create table if not exists public.tsd_memberships (
  company    text not null check (company in ('tuya-suez','aix')),
  email      text not null check (email = lower(email)),
  role       text not null check (role in ('owner','admin','staff')),
  see_areas  text[] not null default '{}',
  display_name text,
  created_at timestamptz not null default now(),
  created_by text,
  primary key (company, email)
);
alter table public.tsd_memberships enable row level security;

create or replace function public.tsd_role(p_company text)
returns text language sql stable security definer set search_path = '' as $$
  select m.role from public.tsd_memberships m where m.company = p_company and m.email = public.tsd_me();
$$;
revoke execute on function public.tsd_role(text) from public, anon;
grant execute on function public.tsd_role(text) to authenticated;

create or replace function public.tsd_member(p_company text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.tsd_role(p_company) is not null;
$$;
revoke execute on function public.tsd_member(text) from public, anon;
grant execute on function public.tsd_member(text) to authenticated;

create or replace function public.tsd_is_owner(p_company text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.tsd_role(p_company) = 'owner', false);
$$;
revoke execute on function public.tsd_is_owner(text) from public, anon;
grant execute on function public.tsd_is_owner(text) to authenticated;

create or replace function public.tsd_is_any_owner()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.tsd_memberships m where m.email = public.tsd_me() and m.role = 'owner');
$$;
revoke execute on function public.tsd_is_any_owner() from public, anon;
grant execute on function public.tsd_is_any_owner() to authenticated;

-- members read their own company's member list; only an owner of that company writes it
create policy "members read members" on public.tsd_memberships for select to authenticated
  using ((select public.tsd_member(company)));
create policy "owner adds members" on public.tsd_memberships for insert to authenticated
  with check ((select public.tsd_is_owner(company)));
create policy "owner updates members" on public.tsd_memberships for update to authenticated
  using ((select public.tsd_is_owner(company))) with check ((select public.tsd_is_owner(company)));
create policy "owner removes members" on public.tsd_memberships for delete to authenticated
  using ((select public.tsd_is_owner(company)));

-- requests: the person sees his own; any owner sees and decides all
create policy "see own request" on public.tsd_access_requests for select to authenticated
  using (user_id = (select auth.uid()) or (select public.tsd_is_any_owner()));
create policy "owner decides requests" on public.tsd_access_requests for update to authenticated
  using ((select public.tsd_is_any_owner())) with check ((select public.tsd_is_any_owner()));

-- ---------- areas and owners ----------
create table if not exists public.tsd_areas (
  company     text not null check (company in ('tuya-suez','aix')),
  key         text not null check (key ~ '^[a-z_]{2,30}$'),
  name        text not null,
  sort_order  int not null default 0,
  owner_email text not null check (owner_email = lower(owner_email)),
  updated_at  timestamptz not null default now(),
  updated_by  text,
  primary key (company, key)
);
alter table public.tsd_areas enable row level security;

create or replace function public.tsd_owns(p_company text, p_area text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.tsd_member(p_company) and exists (
    select 1 from public.tsd_areas a where a.company = p_company and a.key = p_area and a.owner_email = public.tsd_me());
$$;
revoke execute on function public.tsd_owns(text, text) from public, anon;
grant execute on function public.tsd_owns(text, text) to authenticated;

create or replace function public.tsd_can_see(p_company text, p_area text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    public.tsd_role(p_company) in ('owner','admin')
    or exists (select 1 from public.tsd_memberships m where m.company = p_company and m.email = public.tsd_me() and p_area = any(m.see_areas))
    or public.tsd_owns(p_company, p_area), false);
$$;
revoke execute on function public.tsd_can_see(text, text) from public, anon;
grant execute on function public.tsd_can_see(text, text) to authenticated;

create policy "members read visible areas" on public.tsd_areas for select to authenticated
  using ((select public.tsd_can_see(company, key)));
create policy "owner adds areas" on public.tsd_areas for insert to authenticated
  with check ((select public.tsd_is_owner(company)));
-- owner changes go through tsd_set_area_owner()

create table if not exists public.tsd_area_history (
  id         uuid primary key default gen_random_uuid(),
  company    text not null,
  area_key   text not null,
  from_email text,
  to_email   text not null,
  changed_by text not null,
  changed_at timestamptz not null default now(),
  foreign key (company, area_key) references public.tsd_areas(company, key)
);
alter table public.tsd_area_history enable row level security;
create policy "members read area history" on public.tsd_area_history for select to authenticated
  using ((select public.tsd_can_see(company, area_key)));

-- the current owner of the area, the owner of 'responsibilities', or a company owner can hand it over,
-- and only to a member of that company
create or replace function public.tsd_set_area_owner(p_company text, p_area text, p_owner text)
returns public.tsd_areas language plpgsql security definer set search_path = '' as $$
declare a public.tsd_areas; v_owner text := lower(trim(p_owner));
begin
  if not public.tsd_member(p_company) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into a from public.tsd_areas where company = p_company and key = p_area for update;
  if not found then raise exception 'no such area'; end if;
  if not (a.owner_email = public.tsd_me() or public.tsd_owns(p_company, 'responsibilities') or public.tsd_is_owner(p_company)) then
    raise exception 'only the owner of this area can hand it over' using errcode = '42501';
  end if;
  if not exists (select 1 from public.tsd_memberships m where m.company = p_company and m.email = v_owner) then
    raise exception 'new owner must be a member of this company';
  end if;
  if v_owner = a.owner_email then return a; end if;
  insert into public.tsd_area_history (company, area_key, from_email, to_email, changed_by)
    values (p_company, a.key, a.owner_email, v_owner, public.tsd_me());
  update public.tsd_areas set owner_email = v_owner, updated_at = now(), updated_by = public.tsd_me()
    where company = p_company and key = a.key returning * into a;
  return a;
end $$;
revoke execute on function public.tsd_set_area_owner(text, text, text) from public, anon;
grant execute on function public.tsd_set_area_owner(text, text, text) to authenticated;

-- revoking a member hands his areas back to the company owner who revokes
create or replace function public.tsd_revoke_member(p_company text, p_email text)
returns void language plpgsql security definer set search_path = '' as $$
declare v text := lower(trim(p_email));
begin
  if not public.tsd_is_owner(p_company) then raise exception 'only an owner revokes' using errcode = '42501'; end if;
  if v = public.tsd_me() then raise exception 'cannot revoke yourself'; end if;
  insert into public.tsd_area_history (company, area_key, from_email, to_email, changed_by)
    select company, key, owner_email, public.tsd_me(), public.tsd_me() from public.tsd_areas where company = p_company and owner_email = v;
  update public.tsd_areas set owner_email = public.tsd_me(), updated_at = now(), updated_by = public.tsd_me()
    where company = p_company and owner_email = v;
  delete from public.tsd_memberships where company = p_company and email = v;
  if not exists (select 1 from public.tsd_memberships where email = v) then
    update public.tsd_access_requests set status = 'revoked', decided_by = public.tsd_me(), decided_at = now() where email = v;
  end if;
end $$;
revoke execute on function public.tsd_revoke_member(text, text) from public, anon;
grant execute on function public.tsd_revoke_member(text, text) to authenticated;

-- ---------- handover card (بطاقة تسليم) ----------
create table if not exists public.tsd_jobs (
  id              uuid primary key default gen_random_uuid(),
  company         text not null check (company in ('tuya-suez','aix')),
  created_at      timestamptz not null default now(),
  lead_id         uuid references public.leads(id) on delete set null,
  quotation_id    uuid references public.quotations(id) on delete set null,
  installation_id uuid references public.installations(id) on delete set null,
  customer_name   text not null check (length(trim(customer_name)) between 2 and 120),
  area_text       text,
  goods_status    text not null default 'pending' check (goods_status    in ('pending','in_progress','done','blocked')),
  techs_status    text not null default 'pending' check (techs_status    in ('pending','in_progress','done','blocked')),
  install_status  text not null default 'pending' check (install_status  in ('pending','in_progress','done','blocked')),
  collect_status  text not null default 'pending' check (collect_status  in ('pending','in_progress','done','blocked')),
  amount_total    numeric check (amount_total is null or amount_total >= 0),
  amount_paid     numeric not null default 0 check (amount_paid >= 0),
  notes           text,
  created_by      text default public.tsd_me(),
  updated_at      timestamptz not null default now(),
  updated_by      text
);
create index if not exists tsd_jobs_company_idx on public.tsd_jobs (company, created_at desc);
alter table public.tsd_jobs enable row level security;
create policy "members read jobs" on public.tsd_jobs for select to authenticated
  using ((select public.tsd_can_see(company, 'delivery')));
create policy "delivery owner opens jobs" on public.tsd_jobs for insert to authenticated
  with check ((select public.tsd_owns(company, 'delivery')));

-- each step belongs to an area: goods → 'goods', techs → 'technicians', install → 'installs', collect → 'collection'
create or replace function public.tsd_set_job_step(p_job uuid, p_step text, p_status text, p_paid numeric default null)
returns public.tsd_jobs language plpgsql security definer set search_path = '' as $$
declare j public.tsd_jobs;
        v_area text := case p_step when 'goods' then 'goods' when 'techs' then 'technicians'
                                   when 'install' then 'installs' when 'collect' then 'collection' end;
begin
  if v_area is null then raise exception 'bad step'; end if;
  if p_status not in ('pending','in_progress','done','blocked') then raise exception 'bad status'; end if;
  select * into j from public.tsd_jobs where id = p_job for update;
  if not found then raise exception 'no such job'; end if;
  if not public.tsd_owns(j.company, v_area) then raise exception 'only the owner of this step can change it' using errcode = '42501'; end if;
  if p_paid is not null and (p_step <> 'collect' or p_paid < 0) then raise exception 'paid amount only on collection'; end if;
  update public.tsd_jobs set
    goods_status   = case when p_step = 'goods'   then p_status else goods_status end,
    techs_status   = case when p_step = 'techs'   then p_status else techs_status end,
    install_status = case when p_step = 'install' then p_status else install_status end,
    collect_status = case when p_step = 'collect' then p_status else collect_status end,
    amount_paid    = coalesce(p_paid, amount_paid),
    updated_at = now(), updated_by = public.tsd_me()
  where id = p_job returning * into j;
  return j;
end $$;
revoke execute on function public.tsd_set_job_step(uuid, text, text, numeric) from public, anon;
grant execute on function public.tsd_set_job_step(uuid, text, text, numeric) to authenticated;

-- ---------- tasks ----------
create table if not exists public.tsd_tasks (
  id             uuid primary key default gen_random_uuid(),
  company        text not null check (company in ('tuya-suez','aix')),
  created_at     timestamptz not null default now(),
  area_key       text not null,
  title          text not null check (length(trim(title)) between 2 and 200),
  assignee_email text not null check (assignee_email = lower(assignee_email)),
  due_date       date,
  status         text not null default 'open' check (status in ('open','done')),
  created_by     text default public.tsd_me(),
  done_at        timestamptz,
  foreign key (company, area_key) references public.tsd_areas(company, key)
);
create index if not exists tsd_tasks_assignee_idx on public.tsd_tasks (company, assignee_email, status);
alter table public.tsd_tasks enable row level security;
create policy "members read tasks" on public.tsd_tasks for select to authenticated
  using ((select public.tsd_can_see(company, area_key)) or ((select public.tsd_member(company)) and assignee_email = (select public.tsd_me())));
create policy "area owner adds tasks" on public.tsd_tasks for insert to authenticated
  with check ((select public.tsd_owns(company, area_key)));
create policy "area owner or assignee updates tasks" on public.tsd_tasks for update to authenticated
  using ((select public.tsd_owns(company, area_key)) or ((select public.tsd_member(company)) and assignee_email = (select public.tsd_me())))
  with check ((select public.tsd_owns(company, area_key)) or ((select public.tsd_member(company)) and assignee_email = (select public.tsd_me())));

-- ---------- approvals ----------
create table if not exists public.tsd_approvals (
  id            uuid primary key default gen_random_uuid(),
  company       text not null check (company in ('tuya-suez','aix')),
  created_at    timestamptz not null default now(),
  area_key      text not null,
  title         text not null check (length(trim(title)) between 2 and 200),
  details       text,
  amount        numeric,
  ref_table     text check (ref_table in ('leads','quotations','installations','tsd_jobs')),
  ref_id        uuid,
  status        text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_by  text default public.tsd_me(),
  decided_by    text,
  decided_at    timestamptz,
  decision_note text,
  foreign key (company, area_key) references public.tsd_areas(company, key)
);
create index if not exists tsd_approvals_status_idx on public.tsd_approvals (company, status, created_at desc);
alter table public.tsd_approvals enable row level security;
create policy "members read approvals" on public.tsd_approvals for select to authenticated
  using ((select public.tsd_can_see(company, area_key)));
create policy "members request approvals" on public.tsd_approvals for insert to authenticated
  with check ((select public.tsd_can_see(company, area_key)) and status = 'pending' and decided_by is null);

create or replace function public.tsd_decide(p_id uuid, p_approve boolean, p_note text default null)
returns public.tsd_approvals language plpgsql security definer set search_path = '' as $$
declare r public.tsd_approvals;
begin
  select * into r from public.tsd_approvals where id = p_id for update;
  if not found then raise exception 'no such approval'; end if;
  if not public.tsd_owns(r.company, r.area_key) then raise exception 'only the area owner approves' using errcode = '42501'; end if;
  if r.status <> 'pending' then raise exception 'already decided'; end if;
  update public.tsd_approvals set status = case when p_approve then 'approved' else 'rejected' end,
    decided_by = public.tsd_me(), decided_at = now(), decision_note = nullif(trim(p_note), '')
  where id = p_id returning * into r;
  return r;
end $$;
revoke execute on function public.tsd_decide(uuid, boolean, text) from public, anon;
grant execute on function public.tsd_decide(uuid, boolean, text) to authenticated;

-- ---------- comments ----------
create table if not exists public.tsd_comments (
  id           uuid primary key default gen_random_uuid(),
  company      text not null check (company in ('tuya-suez','aix')),
  created_at   timestamptz not null default now(),
  area_key     text not null,
  target_type  text not null check (target_type in ('area','job','task','approval','lead')),
  target_id    text not null,
  body         text not null check (length(trim(body)) between 1 and 2000),
  author_email text not null default public.tsd_me()
);
create index if not exists tsd_comments_target_idx on public.tsd_comments (company, target_type, target_id, created_at);
alter table public.tsd_comments enable row level security;
create policy "members read comments" on public.tsd_comments for select to authenticated
  using ((select public.tsd_can_see(company, area_key)));
create policy "members write own comments" on public.tsd_comments for insert to authenticated
  with check ((select public.tsd_can_see(company, area_key)) and author_email = (select public.tsd_me()));
-- no update/delete: comments stay as written

-- ---------- what this account may do (the page asks this first) ----------
create or replace function public.tsd_my_access(p_company text)
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object('role', m.role, 'see_areas', m.see_areas, 'display_name', m.display_name)
  from public.tsd_memberships m where m.company = p_company and m.email = public.tsd_me();
$$;
revoke execute on function public.tsd_my_access(text) from public, anon;
grant execute on function public.tsd_my_access(text) to authenticated;

-- ---------- owner approves / denies a sign-up ----------
create or replace function public.tsd_grant_access(p_company text, p_user text, p_role text, p_see text[] default '{}', p_own text[] default '{}')
returns void language plpgsql security definer set search_path = '' as $$
declare v text := lower(trim(p_user)); r public.tsd_access_requests; k text;
begin
  if not public.tsd_is_owner(p_company) then raise exception 'only an owner grants access' using errcode = '42501'; end if;
  if p_role not in ('admin','staff') then raise exception 'bad role'; end if;
  select * into r from public.tsd_access_requests where email = v;
  if not found then raise exception 'no sign-up for this email'; end if;
  insert into public.tsd_memberships (company, email, role, see_areas, display_name, created_by)
  values (p_company, v, p_role, case when p_role = 'staff' then coalesce(p_see, '{}') else '{}' end, r.full_name, public.tsd_me())
  on conflict (company, email) do update set role = excluded.role, see_areas = excluded.see_areas;
  foreach k in array coalesce(p_own, '{}') loop
    perform public.tsd_set_area_owner(p_company, k, v);
  end loop;
  update public.tsd_access_requests set status = 'approved', decided_by = public.tsd_me(), decided_at = now() where email = v;
end $$;
revoke execute on function public.tsd_grant_access(text, text, text, text[], text[]) from public, anon;
grant execute on function public.tsd_grant_access(text, text, text, text[], text[]) to authenticated;

create or replace function public.tsd_deny_request(p_user text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.tsd_is_any_owner() then raise exception 'only an owner decides' using errcode = '42501'; end if;
  update public.tsd_access_requests set status = 'revoked', decided_by = public.tsd_me(), decided_at = now()
  where email = lower(trim(p_user)) and status = 'pending';
end $$;
revoke execute on function public.tsd_deny_request(text) from public, anon;
grant execute on function public.tsd_deny_request(text) to authenticated;

-- ---------- live CRM data, read-only ----------
-- Each block is returned only if the caller can see that area. Phones are masked.
create or replace function public.tsd_crm(p_company text)
returns json language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.tsd_member(p_company) then raise exception 'not allowed' using errcode = '42501'; end if;
  return json_build_object(
    'leads', case when public.tsd_can_see(p_company, 'sales') then (
      select coalesce(json_agg(x order by x.created_at desc), '[]'::json) from (
        select l.id, l.created_at, l.name, left(l.phone, 3) || '•••••' || right(l.phone, 4) as phone, l.area, l.source,
               l.status, l.assigned_to, l.next_follow_up,
               f.note as last_note, f.created_at as last_at
        from public.leads l
        left join lateral (select fu.note, fu.created_at from public.follow_ups fu where fu.lead_id = l.id order by fu.created_at desc limit 1) f on true
        where l.company = p_company and l.status <> 'lost' and l.created_at > now() - interval '180 days'
        limit 500) x) end,
    'quotes', case when public.tsd_can_see(p_company, 'pricing') then (
      select coalesce(json_agg(x order by x.quote_date desc), '[]'::json) from (
        select q.id, q.quote_number, q.client_name, q.quote_date, q.total, q.status, q.created_by, q.delete_requested_at
        from public.quotations q
        where q.company = p_company and q.quote_date > current_date - 120
        limit 300) x) end,
    'stock', case when public.tsd_can_see(p_company, 'goods') then (
      select coalesce(json_agg(x order by x.name), '[]'::json) from (
        select i.id, i.name, i.unit, i.quantity, i.min_qty from public.inventory_items i where i.company = p_company) x) end,
    'installs', case when public.tsd_can_see(p_company, 'installs') then (
      select coalesce(json_agg(x order by x.scheduled_date), '[]'::json) from (
        select n.id, n.customer_name, n.area, n.scheduled_date, n.technician, n.status
        from public.installations n where n.company = p_company and n.status in ('pending','in_progress')) x) end
  );
end $$;
revoke execute on function public.tsd_crm(text) from public, anon;
grant execute on function public.tsd_crm(text) to authenticated;

-- ---------- first owner and areas ----------
-- Abdallah is the owner. Ahmed and Omar (admins) sign up from the page and Abdallah approves them
-- from «طلبات الدخول», then hands them areas. No one else's email is stored here.
insert into public.tsd_memberships (company, email, role, display_name, created_by) values
  ('tuya-suez', 'abdallahsad35@gmail.com', 'owner', 'عبدالله', 'migration-111')
on conflict (company, email) do nothing;

insert into public.tsd_areas (company, key, name, sort_order, owner_email)
select c.company, a.key, a.name, a.sort_order, 'abdallahsad35@gmail.com'
from (values ('tuya-suez')) as c(company)
cross join (values
  ('responsibilities', 'توزيع المسؤوليات', 0),
  ('sales',            'المبيعات وفريق البنات', 10),
  ('pricing',          'الأسعار وعروض السعر', 20),
  ('delivery',         'التسليم (فتح بطاقة شغلانة)', 30),
  ('goods',            'المخزن والبضاعة', 40),
  ('technicians',      'الفنيين', 50),
  ('installs',         'التركيب والتسليم للعميل', 60),
  ('collection',       'الكاش والتحصيل', 70),
  ('marketing',        'التسويق والإعلانات', 80)
) as a(key, name, sort_order)
on conflict (company, key) do nothing;

commit;
