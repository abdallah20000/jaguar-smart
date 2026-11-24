-- 113 — Tuya Suez #4: «مسؤول المبيعات» (sales manager), «مراجع» (reviewer), site visits (المعاينات) and an
-- activity log (who changed what, when).
-- NOT RUN YET. Needs 001, 002, 004, 106, 111 and 112 to be live first. Run it in the Supabase SQL editor of the
-- CRM project (snrsfpprlynixotjipmo). Safe to re-run: tables/columns are "if not exists", functions are
-- "or replace", every trigger and policy of this file is dropped (if it exists) before it is created.
-- Nothing existing is dropped or altered destructively: two columns are ADDED to tsd_memberships, one area
-- row ('visits') is ADDED, and tsd_my_access() is replaced by a version that returns two more fields.
-- No row of leads, quotations, products or memberships is changed by this file.
--
-- Roles are data, not emails:
--   tsd_memberships.sales_manager  (boolean)  «مسؤول المبيعات»: in the CRM he reassigns a client from one girl to
--                                             another and approves/rejects a quote deletion. Pricing approvals and
--                                             site-visit states belong to whoever OWNS the 'pricing' / 'visits'
--                                             areas (same rule as 111: the area owner decides).
--   tsd_memberships.review_areas   (text[])   «مراجع»: in these areas the member sees everything and may comment,
--                                             but the database refuses any change he makes: CRM leads and
--                                             follow-ups ('sales'), quotations and their lines ('pricing'), site
--                                             visits ('visits'), and approvals of those areas (request or decide).
--   Access, join requests, roles and products/prices are not touched: they stay with the company owner
--   (111: tsd_is_owner) and the CRM admin role (001: products), exactly as today.
--
-- «بعد ما أحمد يسجّل» (one-time setup, by Abdallah; nothing here names Ahmed):
--   1. /app → give Ahmed's email the CRM role 'crm' in Tuya Suez (app_set_access). NOT 'admin': admin edits prices.
--   2. Dashboard → «طلبات الدخول» → approve Ahmed as أدمن (or select tsd_grant_access(...)).
--   3. Dashboard → «المسؤوليات» → «عيّن مسؤول المبيعات» on Ahmed, which runs
--        select public.tsd_set_sales_manager('tuya-suez', '<ahmed email>', true, true);
--      It marks him sales_manager, hands him the areas sales + pricing + visits, and makes the caller (the owner)
--      «مراجع» in those three areas. Until step 3, nothing changes for anyone.

begin;

-- =========================================================================================
-- 1. Membership flags
-- =========================================================================================
alter table public.tsd_memberships add column if not exists sales_manager boolean not null default false;
alter table public.tsd_memberships add column if not exists review_areas text[] not null default '{}';

-- the area that holds site visits
insert into public.tsd_areas (company, key, name, sort_order, owner_email)
select m.company, 'visits', 'المعاينات', 15, m.email
from public.tsd_memberships m
where m.company = 'tuya-suez' and m.role = 'owner'
order by m.created_at
limit 1
on conflict (company, key) do nothing;

-- is the caller «مراجع» in this area of this company?
create or replace function public.tsd_reviewing(p_company text, p_area text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(exists (
    select 1 from public.tsd_memberships m
    where m.company = p_company and m.email = public.tsd_me() and p_area = any(m.review_areas)), false);
$$;
revoke execute on function public.tsd_reviewing(text, text) from public, anon;
grant execute on function public.tsd_reviewing(text, text) to authenticated;

-- is the caller «مسؤول المبيعات» of this company?
create or replace function public.tsd_sales_manager(p_company text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(exists (
    select 1 from public.tsd_memberships m
    where m.company = p_company and m.email = public.tsd_me() and m.sales_manager), false);
$$;
revoke execute on function public.tsd_sales_manager(text) from public, anon;
grant execute on function public.tsd_sales_manager(text) to authenticated;

-- may the caller act (edit / decide) in this area? = owns it (111) and is not reviewing it
create or replace function public.tsd_can_act(p_company text, p_area text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.tsd_owns(p_company, p_area) and not public.tsd_reviewing(p_company, p_area);
$$;
revoke execute on function public.tsd_can_act(text, text) from public, anon;
grant execute on function public.tsd_can_act(text, text) to authenticated;

-- =========================================================================================
-- 2. Activity log (Odoo-style chatter): written only by the functions and triggers below
-- =========================================================================================
create table if not exists public.tsd_activity (
  id          uuid primary key default gen_random_uuid(),
  company     text not null check (company in ('tuya-suez','aix')),
  created_at  timestamptz not null default now(),
  area_key    text not null,
  target_type text not null check (target_type in ('visit','approval','lead','quote','member')),
  target_id   text not null check (length(target_id) <= 200),
  kind        text not null check (kind in ('created','status','decision','comment','reassign','delete_request','deleted','delete_rejected','role')),
  body        text check (body is null or length(body) <= 2000),
  from_value  text check (from_value is null or length(from_value) <= 200),
  to_value    text check (to_value is null or length(to_value) <= 200),
  actor       text not null,
  foreign key (company, area_key) references public.tsd_areas(company, key)
);
create index if not exists tsd_activity_target_idx on public.tsd_activity (company, target_type, target_id, created_at);
create index if not exists tsd_activity_recent_idx on public.tsd_activity (company, created_at desc);
alter table public.tsd_activity enable row level security;
revoke all on public.tsd_activity from anon;
revoke insert, update, delete, truncate on public.tsd_activity from authenticated;

-- internal: write one log line; skipped (never fails the caller) when the company has no such area
create or replace function public.tsd_log(p_company text, p_area text, p_type text, p_id text, p_kind text,
                                          p_body text default null, p_from text default null, p_to text default null,
                                          p_actor text default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.tsd_areas a where a.company = p_company and a.key = p_area) then return; end if;
  insert into public.tsd_activity (company, area_key, target_type, target_id, kind, body, from_value, to_value, actor)
  values (p_company, p_area, p_type, left(p_id, 200), p_kind, left(p_body, 2000), left(p_from, 200), left(p_to, 200),
          coalesce(nullif(p_actor, ''), nullif(public.tsd_me(), ''), 'system'));
end $$;
revoke execute on function public.tsd_log(text, text, text, text, text, text, text, text, text) from public, anon, authenticated;

-- =========================================================================================
-- 3. Site visits (المعاينات)
-- =========================================================================================
create table if not exists public.tsd_site_visits (
  id            uuid primary key default gen_random_uuid(),
  company       text not null check (company in ('tuya-suez','aix')),
  created_at    timestamptz not null default now(),
  lead_id       uuid references public.leads(id) on delete set null,
  client_name   text not null check (length(btrim(client_name)) between 1 and 120),
  client_phone  text check (client_phone is null or length(client_phone) <= 40),
  maps_url      text check (maps_url is null or (length(maps_url) <= 500 and maps_url ~* '^https://([a-z0-9-]+\.)*(google\.[a-z.]+/maps|maps\.google\.[a-z.]+/|maps\.app\.goo\.gl/|goo\.gl/maps/)')),
  lat           numeric check (lat is null or lat between -90 and 90),
  lng           numeric check (lng is null or lng between -180 and 180),
  address       text check (address is null or length(address) <= 300),
  needs         text[] not null default '{}' check (needs <@ array['lights','curtains','cameras','locks','screens','other']::text[]),
  needs_text    text check (needs_text is null or length(needs_text) <= 500),
  visit_date    date not null,
  visit_time    time,
  notes         text check (notes is null or length(notes) <= 1000),
  photos        text[] not null default '{}' check (coalesce(array_length(photos, 1), 0) <= 3),
  status        text not null default 'new' check (status in ('new','scheduled','done','cancelled')),
  scheduled_for timestamptz,
  result        text check (result is null or result in ('quote','sold','thinking','not_interested','other')),
  status_note   text check (status_note is null or length(status_note) <= 1000),
  created_by    text not null,
  updated_at    timestamptz not null default now(),
  updated_by    text
);
create index if not exists tsd_site_visits_company_idx on public.tsd_site_visits (company, status, created_at desc);
create index if not exists tsd_site_visits_lead_idx on public.tsd_site_visits (lead_id, created_at desc);
alter table public.tsd_site_visits enable row level security;
revoke all on public.tsd_site_visits from anon;
revoke insert, update, delete, truncate on public.tsd_site_visits from authenticated;   -- only the functions below write

-- who reads a visit: anyone who can see the 'visits' area on the dashboard (owner, admins, staff given it),
-- and the CRM user who handed it over (her own visits, in her own company)
drop policy if exists "visits read" on public.tsd_site_visits;
create policy "visits read" on public.tsd_site_visits for select to authenticated
  using ((select public.tsd_can_see(company, 'visits'))
         or (created_by = (select public.tsd_me()) and company = (select public.my_company())
             and (select public.has_role(array['admin','crm']))));

-- the log: whoever can see the area, plus the girl who handed over that visit
drop policy if exists "activity read" on public.tsd_activity;
create policy "activity read" on public.tsd_activity for select to authenticated
  using ((select public.tsd_can_see(company, area_key))
         or (target_type = 'visit' and exists (select 1 from public.tsd_site_visits v
                                               where v.id::text = tsd_activity.target_id and v.company = tsd_activity.company
                                                 and v.created_by = (select public.tsd_me()))));

-- ---------- photos: private bucket, <company>/<auth uid>/<uuid>.<ext>, max 3 per visit ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('visit-photos', 'visit-photos', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "visit photos upload" on storage.objects;
create policy "visit photos upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'visit-photos'
              and (storage.foldername(name))[1] = (select public.my_company())
              and (storage.foldername(name))[2] = (select auth.uid())::text
              and name ~ '^[a-z-]+/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
              and (select public.has_role(array['admin','crm']))
              and not public.tsd_reviewing((storage.foldername(name))[1], 'visits'));
drop policy if exists "visit photos read" on storage.objects;
create policy "visit photos read" on storage.objects for select to authenticated
  using (bucket_id = 'visit-photos'
         and (public.tsd_can_see((storage.foldername(name))[1], 'visits')
              or (storage.foldername(name))[2] = (select auth.uid())::text));
-- no update / delete policies: photos stay as uploaded

-- ---------- «سلّم معاينة لأحمد» (CRM client card) ----------
-- Name and phone are copied from the lead on the server. The lead's status becomes 'site_visit' and a line is
-- added to its follow-up log. One open (new/scheduled) visit per client.
create or replace function public.tsd_handover_visit(
  p_lead uuid, p_maps_url text, p_lat numeric, p_lng numeric, p_address text,
  p_needs text[], p_needs_text text, p_date date, p_time time, p_notes text, p_photos text[] default '{}')
returns public.tsd_site_visits language plpgsql volatile security definer set search_path = '' as $$
declare l public.leads; v public.tsd_site_visits; v_me text := public.tsd_me(); v_url text := nullif(btrim(p_maps_url), '');
        v_photos text[] := coalesce(p_photos, '{}'); f text; v_today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if v_me = '' or not public.has_role(array['admin','crm']) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into l from public.leads where id = p_lead for update;
  if not found or l.company is distinct from public.my_company() then
    raise exception 'lead not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.tsd_areas a where a.company = l.company and a.key = 'visits') then
    raise exception 'visits are not used for this company' using errcode = 'P0001';
  end if;
  if public.tsd_reviewing(l.company, 'visits') then
    raise exception 'reviewer_read_only: visits' using errcode = '42501';
  end if;
  if exists (select 1 from public.tsd_site_visits s where s.lead_id = l.id and s.status in ('new','scheduled')) then
    raise exception 'visit_open: this client already has an open visit' using errcode = 'P0001';
  end if;
  if v_url is null and p_lat is null and nullif(btrim(p_address), '') is null then
    raise exception 'location_required' using errcode = 'P0001';
  end if;
  if (p_lat is null) <> (p_lng is null) then raise exception 'bad_location' using errcode = 'P0001'; end if;
  if coalesce(array_length(p_needs, 1), 0) = 0 and nullif(btrim(p_needs_text), '') is null then
    raise exception 'needs_required' using errcode = 'P0001';
  end if;
  if p_date is null or p_date < v_today or p_date > v_today + 180 then
    raise exception 'bad_date' using errcode = 'P0001';
  end if;
  if coalesce(array_length(v_photos, 1), 0) > 3 then raise exception 'too_many_photos' using errcode = 'P0001'; end if;
  foreach f in array v_photos loop
    if f is null or f !~ ('^' || l.company || '/' || auth.uid()::text || '/[0-9a-f-]{36}\.(jpg|png|webp)$')
       or not exists (select 1 from storage.objects o where o.bucket_id = 'visit-photos' and o.name = f) then
      raise exception 'invalid_photo' using errcode = 'P0001';
    end if;
  end loop;

  insert into public.tsd_site_visits (company, lead_id, client_name, client_phone, maps_url, lat, lng, address,
                                      needs, needs_text, visit_date, visit_time, notes, photos, created_by)
  values (l.company, l.id, left(btrim(l.name), 120), left(l.phone, 40), v_url,
          case when p_lat is not null then round(p_lat, 6) end, case when p_lng is not null then round(p_lng, 6) end,
          left(nullif(btrim(p_address), ''), 300), coalesce(p_needs, '{}'), left(nullif(btrim(p_needs_text), ''), 500),
          p_date, p_time, left(nullif(btrim(p_notes), ''), 1000), v_photos, v_me)
  returning * into v;

  update public.leads set status = 'site_visit' where id = l.id and status is distinct from 'site_visit';
  insert into public.follow_ups (lead_id, note, done_by, company)
  values (l.id, left(format('سلّمت معاينة لمسؤول المبيعات — ميعاد %s%s', p_date, coalesce(' ' || to_char(p_time, 'HH24:MI'), '')), 500),
          v_me, l.company);
  perform public.tsd_log(l.company, 'visits', 'visit', v.id::text, 'created',
                         format('معاينة جديدة لـ %s يوم %s', v.client_name, p_date), null, 'new', v_me);
  return v;
end $$;
revoke execute on function public.tsd_handover_visit(uuid, text, numeric, numeric, text, text[], text, date, time, text, text[]) from public, anon;
grant execute on function public.tsd_handover_visit(uuid, text, numeric, numeric, text, text[], text, date, time, text, text[]) to authenticated;

-- ---------- the visits owner moves a visit: new → scheduled → done / cancelled ----------
create or replace function public.tsd_set_visit_status(p_id uuid, p_status text, p_note text default null,
                                                       p_result text default null, p_when timestamptz default null)
returns public.tsd_site_visits language plpgsql volatile security definer set search_path = '' as $$
declare v public.tsd_site_visits; v_old text; v_note text := left(nullif(btrim(p_note), ''), 1000);
begin
  select * into v from public.tsd_site_visits where id = p_id for update;
  if not found or not public.tsd_member(v.company) then raise exception 'no such visit' using errcode = 'P0002'; end if;
  if not public.tsd_can_act(v.company, 'visits') then
    raise exception 'only the owner of «المعاينات» changes a visit' using errcode = '42501';
  end if;
  if p_status is null or p_status not in ('scheduled','done','cancelled') then raise exception 'bad status'; end if;
  if v.status in ('done','cancelled') then raise exception 'visit_closed' using errcode = 'P0001'; end if;
  if p_status = 'done' and v.status <> 'scheduled' then raise exception 'schedule it first' using errcode = 'P0001'; end if;
  if p_status = 'done' and (p_result is null or p_result not in ('quote','sold','thinking','not_interested','other')) then
    raise exception 'result_required' using errcode = 'P0001';
  end if;
  if p_status = 'cancelled' and v_note is null then raise exception 'reason_required' using errcode = 'P0001'; end if;
  if p_status = 'scheduled' and p_when is null then raise exception 'time_required' using errcode = 'P0001'; end if;
  v_old := v.status;
  update public.tsd_site_visits set
    status = p_status,
    scheduled_for = case when p_status = 'scheduled' then p_when else scheduled_for end,
    result = case when p_status = 'done' then p_result else result end,
    status_note = coalesce(v_note, status_note),
    updated_at = now(), updated_by = public.tsd_me()
  where id = p_id returning * into v;
  perform public.tsd_log(v.company, 'visits', 'visit', v.id::text, 'status',
                         concat_ws(' — ', case when p_status = 'scheduled' then 'الميعاد ' || to_char(p_when at time zone 'Africa/Cairo', 'YYYY-MM-DD HH24:MI') end,
                                   case when p_status = 'done' then 'النتيجة ' || p_result end, v_note),
                         v_old, p_status);
  return v;
end $$;
revoke execute on function public.tsd_set_visit_status(uuid, text, text, text, timestamptz) from public, anon;
grant execute on function public.tsd_set_visit_status(uuid, text, text, text, timestamptz) to authenticated;

-- ---------- a comment in the log of a visit or an approval (reviewers may comment) ----------
create or replace function public.tsd_add_note(p_target_type text, p_target_id uuid, p_body text)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare v_company text; v_area text; v_own boolean := false; v_body text := btrim(coalesce(p_body, ''));
begin
  if public.tsd_me() = '' then raise exception 'not allowed' using errcode = '42501'; end if;
  if length(v_body) < 1 or length(v_body) > 2000 then raise exception 'bad comment'; end if;
  if p_target_type = 'visit' then
    select s.company, 'visits', s.created_by = public.tsd_me() and s.company = public.my_company()
      into v_company, v_area, v_own from public.tsd_site_visits s where s.id = p_target_id;
  elsif p_target_type = 'approval' then
    select a.company, a.area_key into v_company, v_area from public.tsd_approvals a where a.id = p_target_id;
  else
    raise exception 'bad target';
  end if;
  if v_company is null then raise exception 'not found' using errcode = 'P0002'; end if;
  if not (public.tsd_can_see(v_company, v_area) or coalesce(v_own, false)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  perform public.tsd_log(v_company, v_area, p_target_type, p_target_id::text, 'comment', v_body);
end $$;
revoke execute on function public.tsd_add_note(text, uuid, text) from public, anon;
grant execute on function public.tsd_add_note(text, uuid, text) to authenticated;

-- =========================================================================================
-- 4. «مراجع»: the database refuses his changes (CRM tables, visits, approvals)
-- =========================================================================================
-- tg_argv[0] = the area this table belongs to. Server jobs (no signed-in user) pass. A change made by a
-- foreign-key cascade (trigger depth > 1, e.g. a product the owner deletes sets quotation_items.product_id
-- to null) passes, because the owner keeps products and prices.
create or replace function public.tsd_review_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_company text;
begin
  if tg_op = 'DELETE' then v_company := old.company; else v_company := new.company; end if;
  if pg_trigger_depth() = 1 and public.tsd_me() <> '' and public.tsd_reviewing(v_company, tg_argv[0]) then
    raise exception 'reviewer_read_only: «%» is review-only for you', tg_argv[0] using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
revoke execute on function public.tsd_review_guard() from public, anon, authenticated;

drop trigger if exists tsd_review_guard on public.leads;
create trigger tsd_review_guard before insert or update or delete on public.leads
  for each row execute function public.tsd_review_guard('sales');
drop trigger if exists tsd_review_guard on public.follow_ups;
create trigger tsd_review_guard before insert or update or delete on public.follow_ups
  for each row execute function public.tsd_review_guard('sales');
drop trigger if exists tsd_review_guard on public.quotations;
create trigger tsd_review_guard before insert or update or delete on public.quotations
  for each row execute function public.tsd_review_guard('pricing');
drop trigger if exists tsd_review_guard on public.quotation_items;
create trigger tsd_review_guard before insert or update or delete on public.quotation_items
  for each row execute function public.tsd_review_guard('pricing');

-- approvals: a reviewer of the area neither requests nor decides; every request and decision is logged
create or replace function public.tsd_approvals_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if public.tsd_me() <> '' and public.tsd_reviewing(new.company, new.area_key) then
    raise exception 'reviewer_read_only: «%» is review-only for you', new.area_key using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and (new.company is distinct from old.company or new.area_key is distinct from old.area_key) then
    raise exception 'approval area cannot change' using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function public.tsd_approvals_guard() from public, anon, authenticated;
drop trigger if exists tsd_approvals_guard on public.tsd_approvals;
create trigger tsd_approvals_guard before insert or update on public.tsd_approvals
  for each row execute function public.tsd_approvals_guard();

create or replace function public.tsd_approvals_log()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    perform public.tsd_log(new.company, new.area_key, 'approval', new.id::text, 'created', new.title, null, new.status, new.requested_by);
  elsif new.status is distinct from old.status then
    perform public.tsd_log(new.company, new.area_key, 'approval', new.id::text, 'decision',
                           concat_ws(' — ', new.title, new.decision_note), old.status, new.status, new.decided_by);
  end if;
  return null;
end $$;
revoke execute on function public.tsd_approvals_log() from public, anon, authenticated;
drop trigger if exists tsd_approvals_log on public.tsd_approvals;
create trigger tsd_approvals_log after insert or update on public.tsd_approvals
  for each row execute function public.tsd_approvals_log();

-- =========================================================================================
-- 5. CRM powers of «مسؤول المبيعات»
-- =========================================================================================
-- Reassigning a client: in a company that uses the dashboard, a CRM user who is not admin may fill an EMPTY
-- «مسؤول عنه», but only the sales manager moves a client from one person to another. Every move is logged.
create or replace function public.tsd_lead_assign_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.assigned_to is distinct from old.assigned_to
     and nullif(btrim(old.assigned_to), '') is not null
     and public.tsd_me() <> ''
     and exists (select 1 from public.tsd_areas a where a.company = new.company and a.key = 'sales')
     and not public.has_role(array['admin'])
     and not (public.tsd_sales_manager(new.company) and not public.tsd_reviewing(new.company, 'sales')) then
    raise exception 'reassign_needs_manager: only the sales manager moves a client' using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function public.tsd_lead_assign_guard() from public, anon, authenticated;
drop trigger if exists tsd_lead_assign_guard on public.leads;
create trigger tsd_lead_assign_guard before update on public.leads
  for each row execute function public.tsd_lead_assign_guard();

-- log: client moved between people; quote deletion asked
create or replace function public.tsd_crm_log()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'leads' and new.assigned_to is distinct from old.assigned_to then
    perform public.tsd_log(new.company, 'sales', 'lead', new.id::text, 'reassign', new.name, old.assigned_to, new.assigned_to);
  elsif tg_table_name = 'quotations' and new.delete_requested_at is not null and old.delete_requested_at is null then
    perform public.tsd_log(new.company, 'pricing', 'quote', new.id::text, 'delete_request',
                           format('%s — %s', new.quote_number, new.client_name), null, null, new.delete_requested_by);
  end if;
  return null;
end $$;
revoke execute on function public.tsd_crm_log() from public, anon, authenticated;
drop trigger if exists tsd_crm_log on public.leads;
create trigger tsd_crm_log after update on public.leads for each row execute function public.tsd_crm_log();
drop trigger if exists tsd_crm_log on public.quotations;
create trigger tsd_crm_log after update on public.quotations for each row execute function public.tsd_crm_log();

-- Quote deletion: a CRM user asks (request_quote_deletion, 001); the sales manager approves (the quotation is
-- deleted, with a log line keeping its number, client and total) or rejects (the request is cleared).
create or replace function public.tsd_decide_quote_deletion(p_quote uuid, p_approve boolean, p_note text default null)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare q public.quotations;
begin
  if not public.has_role(array['admin','crm']) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into q from public.quotations where id = p_quote for update;
  if not found or q.company is distinct from public.my_company() then
    raise exception 'quotation not found' using errcode = 'P0002';
  end if;
  if not public.tsd_sales_manager(q.company) or public.tsd_reviewing(q.company, 'pricing') then
    raise exception 'only the sales manager decides a deletion' using errcode = '42501';
  end if;
  if q.delete_requested_at is null then raise exception 'no deletion request' using errcode = 'P0001'; end if;
  if p_approve then
    perform public.tsd_log(q.company, 'pricing', 'quote', q.id::text, 'deleted',
                           left(format('%s — %s — %s ج — طلبه %s%s', q.quote_number, q.client_name, q.total,
                                       split_part(coalesce(q.delete_requested_by, ''), '@', 1),
                                       coalesce(' — ' || nullif(btrim(p_note), ''), '')), 2000));
    delete from public.quotations where id = q.id;
  else
    update public.quotations set delete_requested_by = null, delete_requested_at = null where id = q.id;
    perform public.tsd_log(q.company, 'pricing', 'quote', q.id::text, 'delete_rejected',
                           left(concat_ws(' — ', q.quote_number, q.client_name, nullif(btrim(p_note), '')), 2000));
  end if;
end $$;
revoke execute on function public.tsd_decide_quote_deletion(uuid, boolean, text) from public, anon;
grant execute on function public.tsd_decide_quote_deletion(uuid, boolean, text) to authenticated;

-- what the CRM page shows for this account (company = the CRM's own my_company())
create or replace function public.tsd_crm_powers()
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object(
    'company', c.co,
    'visits_on', exists (select 1 from public.tsd_areas a where a.company = c.co and a.key = 'visits'),
    'manager', public.tsd_sales_manager(c.co),
    'review', coalesce((select m.review_areas from public.tsd_memberships m where m.company = c.co and m.email = public.tsd_me()), '{}'::text[]),
    'visits_owner', (select coalesce(mm.display_name, split_part(a.owner_email, '@', 1))
                     from public.tsd_areas a
                     left join public.tsd_memberships mm on mm.company = a.company and mm.email = a.owner_email
                     where a.company = c.co and a.key = 'visits'))
  from (select public.my_company() as co) c
  where public.has_role(array['admin','crm']);
$$;
revoke execute on function public.tsd_crm_powers() from public, anon;
grant execute on function public.tsd_crm_powers() to authenticated;

-- =========================================================================================
-- 6. Roles: only the company owner sets them (option A: he alone also approves join requests, as in 111)
-- =========================================================================================
-- Make a member «مسؤول المبيعات» (p_on = true): flag + hand him the areas sales, pricing, visits; and, when
-- p_owner_reviews, make the calling owner «مراجع» in those three areas. p_on = false removes the flag only
-- (areas stay where they are; move them from «المسؤوليات»).
create or replace function public.tsd_set_sales_manager(p_company text, p_email text, p_on boolean default true,
                                                        p_owner_reviews boolean default true)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare v text := lower(btrim(coalesce(p_email, ''))); k text; v_me text := public.tsd_me();
begin
  if not public.tsd_is_owner(p_company) then raise exception 'only an owner sets roles' using errcode = '42501'; end if;
  if v = v_me then raise exception 'cannot change your own role'; end if;
  if not exists (select 1 from public.tsd_memberships m where m.company = p_company and m.email = v and m.role in ('admin','staff')) then
    raise exception 'must be an approved admin/staff member of this company';
  end if;
  perform set_config('tsd.role_change', 'on', true);
  update public.tsd_memberships set sales_manager = coalesce(p_on, false) where company = p_company and email = v;
  perform set_config('tsd.role_change', '', true);
  perform public.tsd_log(p_company, 'responsibilities', 'member', v, 'role',
                         case when p_on then 'بقى مسؤول المبيعات' else 'اتشال من مسؤول المبيعات' end);
  if p_on then
    foreach k in array array['sales','pricing','visits'] loop
      if exists (select 1 from public.tsd_areas a where a.company = p_company and a.key = k) then
        perform public.tsd_set_area_owner(p_company, k, v);
      end if;
    end loop;
    if coalesce(p_owner_reviews, true) then
      perform public.tsd_set_review_areas(p_company, v_me, array['sales','pricing','visits']);
    end if;
  end if;
end $$;

-- Set which areas a member (the owner himself included) only reviews. Logged.
create or replace function public.tsd_set_review_areas(p_company text, p_email text, p_areas text[])
returns void language plpgsql volatile security definer set search_path = '' as $$
declare v text := lower(btrim(coalesce(p_email, ''))); v_old text[]; v_new text[];
begin
  if not public.tsd_is_owner(p_company) then raise exception 'only an owner sets roles' using errcode = '42501'; end if;
  select coalesce(array_agg(distinct x order by x), '{}') into v_new from unnest(coalesce(p_areas, '{}'::text[])) as t(x) where x is not null;
  if exists (select 1 from unnest(v_new) as s(k) where not exists (
               select 1 from public.tsd_areas a where a.company = p_company and a.key = s.k)) then
    raise exception 'unknown area';
  end if;
  select m.review_areas into v_old from public.tsd_memberships m where m.company = p_company and m.email = v for update;
  if not found then raise exception 'not a member'; end if;
  perform set_config('tsd.role_change', 'on', true);
  update public.tsd_memberships set review_areas = v_new where company = p_company and email = v;
  perform set_config('tsd.role_change', '', true);
  perform public.tsd_log(p_company, 'responsibilities', 'member', v, 'role', 'مراجع في: ' || coalesce(nullif(array_to_string(v_new, '، '), ''), 'ولا حتة'),
                         array_to_string(v_old, ','), array_to_string(v_new, ','));
end $$;
revoke execute on function public.tsd_set_review_areas(text, text, text[]) from public, anon;
grant execute on function public.tsd_set_review_areas(text, text, text[]) to authenticated;
revoke execute on function public.tsd_set_sales_manager(text, text, boolean, boolean) from public, anon;
grant execute on function public.tsd_set_sales_manager(text, text, boolean, boolean) to authenticated;

-- flags are set only through the two functions above (so every change is logged), never by a direct table write
create or replace function public.tsd_member_flags_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- the two functions above set this transaction-local flag around their own update; nothing else can
  if coalesce(current_setting('tsd.role_change', true), '') <> 'on' and public.tsd_me() <> ''
     and (new.sales_manager is distinct from (case when tg_op = 'UPDATE' then old.sales_manager else false end)
          or new.review_areas is distinct from (case when tg_op = 'UPDATE' then old.review_areas else '{}'::text[] end)) then
    raise exception 'use tsd_set_sales_manager / tsd_set_review_areas' using errcode = '42501';
  end if;
  return new;
end $$;
revoke execute on function public.tsd_member_flags_guard() from public, anon, authenticated;
drop trigger if exists tsd_member_flags_guard on public.tsd_memberships;
create trigger tsd_member_flags_guard before insert or update on public.tsd_memberships
  for each row execute function public.tsd_member_flags_guard();

-- the dashboard asks this first: same as 111 plus the two flags
create or replace function public.tsd_my_access(p_company text)
returns json language sql stable security definer set search_path = '' as $$
  select json_build_object('role', m.role, 'see_areas', m.see_areas, 'display_name', m.display_name,
                           'sales_manager', m.sales_manager, 'review_areas', m.review_areas)
  from public.tsd_memberships m where m.company = p_company and m.email = public.tsd_me();
$$;
revoke execute on function public.tsd_my_access(text) from public, anon;
grant execute on function public.tsd_my_access(text) to authenticated;

commit;
