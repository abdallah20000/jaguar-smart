-- 111 — لوحة الشركا at /tuya-suez/dashboard/ (one system, parametrised by company)
-- NOT RUN YET. Abdallah approves first, then it is run in the Supabase SQL editor of the
-- same project the Tuya Suez CRM uses (snrsfpprlynixotjipmo). Safe to re-run: every object is
-- created with "if not exists" / "or replace", and every policy is dropped (if it exists) before it is created.
--
-- Every dashboard table has a `company` column. Today only 'tuya-suez' is used; the same tables and
-- functions can later serve another company page with its own rows. Nothing existing is changed or dropped.
--
--   tsd_access_requests  one row per sign-up made FROM THIS DASHBOARD (signup metadata app = 'tuya-dashboard'),
--                        per company. Sign-ups of any other app in the project are ignored. pending/approved/revoked.
--   tsd_memberships      who may use which company, with which role, and which areas a staff member sees.
--                        A new auth user has NO row here, so every policy below returns nothing for them:
--                        they only see «حسابك مستني موافقة».
--                        Only an owner (role 'owner' in that company) can add/update memberships.
--   tsd_areas            each area and its owner. Only a company owner (مالك) moves an area.
--   tsd_area_history     who moved an area to whom (written by the functions only).
--   tsd_jobs             «بطاقة تسليم» per job: بضاعة ← فنيين ← تركيب ← تحصيل. A job opens with every step
--                        pending and nothing paid; each step is changed only by that step's owner (tsd_set_job_step).
--   tsd_tasks            tasks under an area, with an assignee. The assignee only marks it done (tsd_complete_task).
--   tsd_approvals        things waiting for the area owner's approval. Nobody but a company owner approves
--                        his own request.
--   tsd_comments         comments by any member who can see the thing.
--   tsd_crm()            READ-ONLY live view of the CRM tables (leads + last follow-up, quotations, inventory,
--                        installations). SECURITY INVOKER: it reads with the caller's own rights, so the CRM's
--                        own role policies and company isolation apply. A block is returned only if the caller
--                        can see that dashboard area AND holds the matching CRM role in that company.
--                        The page sends "x-company: <company>" so a multi-company owner (106) is in that company.
--
-- Roles: owner (مالك: everything + manages access and who owns which area), admin (أدمن: sees everything,
-- edits/approves only in areas he owns), staff (موظف: sees only the areas in see_areas or that he owns).
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

-- ---------- access requests (sign-ups from this dashboard land here) ----------
create table if not exists public.tsd_access_requests (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  company    text not null default 'tuya-suez' check (company in ('tuya-suez','aix')),
  email      text not null,
  full_name  text,
  created_at timestamptz not null default now(),
  status     text not null default 'pending' check (status in ('pending','approved','revoked')),
  decided_by text,
  decided_at timestamptz
);
alter table public.tsd_access_requests add column if not exists company text not null default 'tuya-suez'
  check (company in ('tuya-suez','aix'));
create index if not exists tsd_access_requests_company_idx on public.tsd_access_requests (company, status, created_at);
alter table public.tsd_access_requests enable row level security;

-- Runs on every insert into auth.users (all apps in the project), so it must never block a sign-up:
-- it ignores anything not signed up from this dashboard, ignores email-less users, and swallows any error.
create or replace function public.tsd_on_signup()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_company text;
begin
  begin
    if new.email is null or btrim(new.email) = '' then return new; end if;
    if coalesce(new.raw_user_meta_data ->> 'app', '') <> 'tuya-dashboard' then return new; end if;
    v_company := coalesce(nullif(new.raw_user_meta_data ->> 'company', ''), 'tuya-suez');
    if v_company not in ('tuya-suez','aix') then v_company := 'tuya-suez'; end if;
    insert into public.tsd_access_requests (user_id, company, email, full_name)
    values (new.id, v_company, lower(btrim(new.email)),
            left(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 120))
    on conflict (user_id) do nothing;
  exception when others then
    raise warning 'tsd_on_signup skipped: %', sqlerrm;   -- never block auth
  end;
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

-- members read their own company's member list; only an owner of that company adds or changes it,
-- and never his own row (so he cannot demote himself and lock the company out).
-- Removing a member goes only through tsd_revoke_member(), which also hands his areas back.
drop policy if exists "members read members" on public.tsd_memberships;
create policy "members read members" on public.tsd_memberships for select to authenticated
  using ((select public.tsd_member(company)));
drop policy if exists "owner adds members" on public.tsd_memberships;
create policy "owner adds members" on public.tsd_memberships for insert to authenticated
  with check ((select public.tsd_is_owner(company)));
drop policy if exists "owner updates members" on public.tsd_memberships;
create policy "owner updates members" on public.tsd_memberships for update to authenticated
  using ((select public.tsd_is_owner(company)) and email <> (select public.tsd_me()))
  with check ((select public.tsd_is_owner(company)) and email <> (select public.tsd_me()));
drop policy if exists "owner removes members" on public.tsd_memberships;

-- requests: the person sees his own; the owner of that company sees and decides his company's requests
drop policy if exists "see own request" on public.tsd_access_requests;
create policy "see own request" on public.tsd_access_requests for select to authenticated
  using (user_id = (select auth.uid()) or (select public.tsd_is_owner(company)));
drop policy if exists "owner decides requests" on public.tsd_access_requests;
create policy "owner decides requests" on public.tsd_access_requests for update to authenticated
  using ((select public.tsd_is_owner(company))) with check ((select public.tsd_is_owner(company)));

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

drop policy if exists "members read visible areas" on public.tsd_areas;
create policy "members read visible areas" on public.tsd_areas for select to authenticated
  using ((select public.tsd_can_see(company, key)));
drop policy if exists "owner adds areas" on public.tsd_areas;
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
drop policy if exists "members read area history" on public.tsd_area_history;
create policy "members read area history" on public.tsd_area_history for select to authenticated
  using ((select public.tsd_can_see(company, area_key)));

-- only a company owner (مالك) moves an area, and only to a member of that company.
-- Area owners and the owner of 'responsibilities' cannot (area ownership decides edit/approve rights).
create or replace function public.tsd_set_area_owner(p_company text, p_area text, p_owner text)
returns public.tsd_areas language plpgsql security definer set search_path = '' as $$
declare a public.tsd_areas; v_owner text := lower(trim(p_owner));
begin
  if not public.tsd_is_owner(p_company) then
    raise exception 'only a company owner can hand an area over' using errcode = '42501';
  end if;
  select * into a from public.tsd_areas where company = p_company and key = p_area for update;
  if not found then raise exception 'no such area'; end if;
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
  update public.tsd_access_requests set status = 'revoked', decided_by = public.tsd_me(), decided_at = now()
    where company = p_company and email = v;
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
drop policy if exists "members read jobs" on public.tsd_jobs;
create policy "members read jobs" on public.tsd_jobs for select to authenticated
  using ((select public.tsd_can_see(company, 'delivery')));
-- the delivery owner opens a job; it always starts with every step pending and nothing paid.
-- No update/delete policy: steps change only through tsd_set_job_step(), each by its own step owner.
drop policy if exists "delivery owner opens jobs" on public.tsd_jobs;
create policy "delivery owner opens jobs" on public.tsd_jobs for insert to authenticated
  with check ((select public.tsd_owns(company, 'delivery'))
    and goods_status = 'pending' and techs_status = 'pending' and install_status = 'pending' and collect_status = 'pending'
    and amount_paid = 0 and created_by = (select public.tsd_me()) and updated_by is null);

-- each step belongs to an area: goods → 'goods', techs → 'technicians', install → 'installs', collect → 'collection'
create or replace function public.tsd_set_job_step(p_job uuid, p_step text, p_status text, p_paid numeric default null)
returns public.tsd_jobs language plpgsql security definer set search_path = '' as $$
declare j public.tsd_jobs;
        v_area text := case p_step when 'goods' then 'goods' when 'techs' then 'technicians'
                                   when 'install' then 'installs' when 'collect' then 'collection' end;
begin
  if v_area is null then raise exception 'bad step'; end if;
  if p_status is null or p_status not in ('pending','in_progress','done','blocked') then raise exception 'bad status'; end if;
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
drop policy if exists "members read tasks" on public.tsd_tasks;
create policy "members read tasks" on public.tsd_tasks for select to authenticated
  using ((select public.tsd_can_see(company, area_key)) or ((select public.tsd_member(company)) and assignee_email = (select public.tsd_me())));
-- the area owner adds a task for a member of the same company
drop policy if exists "area owner adds tasks" on public.tsd_tasks;
create policy "area owner adds tasks" on public.tsd_tasks for insert to authenticated
  with check ((select public.tsd_owns(company, area_key))
    and created_by = (select public.tsd_me())
    and exists (select 1 from public.tsd_memberships m where m.company = tsd_tasks.company and m.email = tsd_tasks.assignee_email));
-- only the area owner edits a task (and it stays in an area he owns); the assignee uses tsd_complete_task()
drop policy if exists "area owner or assignee updates tasks" on public.tsd_tasks;
drop policy if exists "area owner updates tasks" on public.tsd_tasks;
create policy "area owner updates tasks" on public.tsd_tasks for update to authenticated
  using ((select public.tsd_owns(company, area_key)))
  with check ((select public.tsd_owns(company, area_key)));

-- the assignee (or the area owner) marks a task done; nothing else on the task changes
create or replace function public.tsd_complete_task(p_id uuid)
returns public.tsd_tasks language plpgsql security definer set search_path = '' as $$
declare t public.tsd_tasks;
begin
  select * into t from public.tsd_tasks where id = p_id for update;
  if not found then raise exception 'no such task'; end if;
  if not public.tsd_member(t.company)
     or not (t.assignee_email = public.tsd_me() or public.tsd_owns(t.company, t.area_key)) then
    raise exception 'only the assignee or the area owner completes a task' using errcode = '42501';
  end if;
  update public.tsd_tasks set status = 'done', done_at = coalesce(done_at, now())
  where id = p_id returning * into t;
  return t;
end $$;
revoke execute on function public.tsd_complete_task(uuid) from public, anon;
grant execute on function public.tsd_complete_task(uuid) to authenticated;

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
drop policy if exists "members read approvals" on public.tsd_approvals;
create policy "members read approvals" on public.tsd_approvals for select to authenticated
  using ((select public.tsd_can_see(company, area_key)));
-- a request is always filed under the caller's own name and starts undecided
drop policy if exists "members request approvals" on public.tsd_approvals;
create policy "members request approvals" on public.tsd_approvals for insert to authenticated
  with check ((select public.tsd_can_see(company, area_key)) and status = 'pending'
    and requested_by = (select public.tsd_me())
    and decided_by is null and decided_at is null and decision_note is null);

-- only the area owner decides, and never on his own request (a company owner may)
create or replace function public.tsd_decide(p_id uuid, p_approve boolean, p_note text default null)
returns public.tsd_approvals language plpgsql security definer set search_path = '' as $$
declare r public.tsd_approvals;
begin
  select * into r from public.tsd_approvals where id = p_id for update;
  if not found then raise exception 'no such approval'; end if;
  if not public.tsd_owns(r.company, r.area_key) then raise exception 'only the area owner approves' using errcode = '42501'; end if;
  if r.requested_by = public.tsd_me() and not public.tsd_is_owner(r.company) then
    raise exception 'you cannot decide your own request' using errcode = '42501';
  end if;
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
drop policy if exists "members read comments" on public.tsd_comments;
create policy "members read comments" on public.tsd_comments for select to authenticated
  using ((select public.tsd_can_see(company, area_key)));
drop policy if exists "members write own comments" on public.tsd_comments;
create policy "members write own comments" on public.tsd_comments for insert to authenticated
  with check ((select public.tsd_can_see(company, area_key)) and author_email = (select public.tsd_me()));
-- no update/delete: comments stay as written

-- defence in depth: the API's anon role gets nothing on the dashboard tables (RLS already blocks it)
revoke all on public.tsd_access_requests, public.tsd_memberships, public.tsd_areas, public.tsd_area_history,
              public.tsd_jobs, public.tsd_tasks, public.tsd_approvals, public.tsd_comments from anon;

-- ---------- what this account may do (the page asks this first) ----------
create or replace function public.tsd_my_access(p_company text)
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object('role', m.role, 'see_areas', m.see_areas, 'display_name', m.display_name)
  from public.tsd_memberships m where m.company = p_company and m.email = public.tsd_me();
$$;
revoke execute on function public.tsd_my_access(text) from public, anon;
grant execute on function public.tsd_my_access(text) to authenticated;

-- ---------- owner approves / denies a sign-up (his own company's requests only) ----------
create or replace function public.tsd_grant_access(p_company text, p_user text, p_role text, p_see text[] default '{}', p_own text[] default '{}')
returns void language plpgsql security definer set search_path = '' as $$
declare v text := lower(trim(p_user)); r public.tsd_access_requests; k text;
begin
  if not public.tsd_is_owner(p_company) then raise exception 'only an owner grants access' using errcode = '42501'; end if;
  if p_role is null or p_role not in ('admin','staff') then raise exception 'bad role'; end if;
  if v = public.tsd_me() then raise exception 'cannot change your own access'; end if;
  select * into r from public.tsd_access_requests where email = v and company = p_company;
  if not found then raise exception 'no sign-up for this email'; end if;
  if exists (select 1 from unnest(coalesce(p_see, '{}'::text[])) as s(see_key)
             where not exists (select 1 from public.tsd_areas a where a.company = p_company and a.key = s.see_key)) then
    raise exception 'unknown area in see list';
  end if;
  insert into public.tsd_memberships (company, email, role, see_areas, display_name, created_by)
  values (p_company, v, p_role, case when p_role = 'staff' then coalesce(p_see, '{}') else '{}' end, r.full_name, public.tsd_me())
  on conflict (company, email) do update set role = excluded.role, see_areas = excluded.see_areas;
  foreach k in array coalesce(p_own, '{}') loop
    perform public.tsd_set_area_owner(p_company, k, v);
  end loop;
  update public.tsd_access_requests set status = 'approved', decided_by = public.tsd_me(), decided_at = now()
    where email = v and company = p_company;
end $$;
revoke execute on function public.tsd_grant_access(text, text, text, text[], text[]) from public, anon;
grant execute on function public.tsd_grant_access(text, text, text, text[], text[]) to authenticated;

-- the earlier draft had tsd_deny_request(text) (any owner, any company); it is replaced by the company-scoped one
drop function if exists public.tsd_deny_request(text);
create or replace function public.tsd_deny_request(p_company text, p_user text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.tsd_is_owner(p_company) then raise exception 'only an owner decides' using errcode = '42501'; end if;
  update public.tsd_access_requests set status = 'revoked', decided_by = public.tsd_me(), decided_at = now()
  where company = p_company and email = lower(trim(p_user)) and status = 'pending';
end $$;
revoke execute on function public.tsd_deny_request(text, text) from public, anon;
grant execute on function public.tsd_deny_request(text, text) to authenticated;

-- not needed any more (requests are scoped to tsd_is_owner(company)); it was only created by this migration
drop function if exists public.tsd_is_any_owner();

-- ---------- live CRM data, read-only ----------
-- SECURITY INVOKER: every CRM table is read with the caller's own rights, so the CRM's own policies
-- (has_role per table + restrictive company isolation) still apply. On top of that, each block is returned
-- only if the caller can see that dashboard area, holds the matching CRM role, and is working in p_company.
-- Phones show only the last 3 digits; follow-up notes are shortened and hidden from staff; people are
-- shown by the name part of their email, not the full address.
create or replace function public.tsd_crm(p_company text)
returns json language plpgsql stable security invoker set search_path = '' as $$
declare v_in boolean; v_full boolean;
begin
  if not public.tsd_member(p_company) then raise exception 'not allowed' using errcode = '42501'; end if;
  v_in := coalesce(public.my_company() = p_company, false);
  v_full := public.tsd_role(p_company) in ('owner','admin');
  return json_build_object(
    'leads', case when v_in and public.tsd_can_see(p_company, 'sales') and public.has_role(array['admin','crm']) then (
      select coalesce(json_agg(x order by x.created_at desc), '[]'::json) from (
        select l.id, l.created_at, l.name, '•••••' || right(l.phone, 3) as phone, l.area, l.source,
               l.status, split_part(l.assigned_to, '@', 1) as assigned_to, l.next_follow_up,
               case when v_full then left(f.note, 140) end as last_note, f.created_at as last_at
        from public.leads l
        left join lateral (select fu.note, fu.created_at from public.follow_ups fu where fu.lead_id = l.id order by fu.created_at desc limit 1) f on true
        where l.company = p_company and l.status <> 'lost' and l.created_at > now() - interval '180 days'
        limit 500) x) end,
    'quotes', case when v_in and public.tsd_can_see(p_company, 'pricing') and public.has_role(array['admin','crm']) then (
      select coalesce(json_agg(x order by x.quote_date desc), '[]'::json) from (
        select q.id, q.quote_number, q.client_name, q.quote_date, q.total, q.status,
               split_part(q.created_by, '@', 1) as created_by, q.delete_requested_at
        from public.quotations q
        where q.company = p_company and q.quote_date > current_date - 120
        limit 300) x) end,
    'stock', case when v_in and public.tsd_can_see(p_company, 'goods') and public.has_role(array['admin','inventory','installs']) then (
      select coalesce(json_agg(x order by x.name), '[]'::json) from (
        select i.id, i.name, i.unit, i.quantity, i.min_qty from public.inventory_items i where i.company = p_company) x) end,
    'installs', case when v_in and public.tsd_can_see(p_company, 'installs') and public.has_role(array['admin','installs']) then (
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
