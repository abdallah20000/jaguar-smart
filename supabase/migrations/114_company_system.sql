-- =====================================================================================
-- 114 — «نظام الشركة» (Company System) — level 1: users/permissions + inventory (multi-warehouse)
-- لم يُنفّذ — عبدالله يضغط Run   |   NOT RUN YET — Abdallah presses Run himself in the Supabase
-- SQL editor of project snrsfpprlynixotjipmo (the same project as the Tuya Suez CRM).
--
-- ماذا ينشئ / What it creates (everything new, all prefixed sys_):
--   جداول / tables:
--     sys_admins        المديرون (بريد صغير الحروف) — يُزرع فقط abdallahsad35@gmail.com
--     sys_permissions   صلاحية لكل (شركة، بريد، موديول) بمستوى view < edit < approve
--     sys_audit         سجل: كل تغيير مدير/صلاحية + كل حركة مخزون + كل ترحيل جرد
--     sys_warehouses    المخازن لكل شركة
--     sys_items         الأصناف لكل شركة (legacy_id = عمود إضافي لاستيراد المخزون القديم مرة واحدة)
--     sys_stock         الكمية لكل (صنف، مخزن) — تُكتب فقط من الدوال
--     sys_moves         حركات المخزون (وارد/صادر/تسوية/تحويل)
--     sys_counts + sys_count_lines   الجرد ومسودّاته
--   دوال / functions (all security definer, search_path = '', revoke from public/anon,
--     grant to authenticated; internal helpers are not granted to anyone):
--     sys_me, sys_is_admin, sys_can            (the page may call these)
--     sys_people, sys_set_admin, sys_set_permission, sys_audit_list          (admin only)
--     sys_warehouses_list, sys_warehouse_save, sys_items_list, sys_item_save,
--     sys_move, sys_transfer, sys_moves_list, sys_low_stock,
--     sys_count_start, sys_count_set, sys_count_get, sys_count_post, sys_counts_list,
--     sys_import_legacy (admin; NOT called by this migration)
--     internal: sys_my_email, sys_rank, sys_log
--   الأمان / security: RLS مفعّل على كل جدول بدون أي policy، ولا صلاحية مباشرة لـ anon/authenticated.
--     العميل يقرأ ويكتب فقط عبر دوال sys_* . Clients touch data ONLY through the sys_* RPCs.
--
-- لا يغيّر أي شيء موجود / Nothing existing is changed: no ALTER, no DROP, no policy or row of any
--   existing table is touched. Only "create ... if not exists", "create or replace function" for
--   NEW sys_ names, and seeds with "on conflict do nothing". Safe to run twice (one transaction).
--   Reads (never writes) team_members and tsd_memberships (if it exists) and, only inside the
--   optional sys_import_legacy, public.inventory_items. FK to public.products(id) when product_id is set.
--
-- Does not depend on 111/112: sys_people checks tsd_memberships with to_regclass at run time.
-- Companies allowed: 'tuya-suez', 'aix', 'jaguar'. Modules: users, inventory, sales, purchasing,
--   accounts, projects, hr, reports. Levels: view < edit < approve.
-- Ayman's email: مش موجود — he is added later from the admin screen (sys_set_admin).
-- AIX's real CRM data lives in another Supabase project (xenrnhgxwhujyvtpwmsk): 'aix' starts empty here.
--
-- ---------------------------------------------------------------------------------------
-- UNDO / تراجع (run by hand only if needed; drops ONLY sys_ objects — it destroys their data):
--   drop function if exists public.sys_import_legacy(text);
--   drop function if exists public.sys_counts_list(text);
--   drop function if exists public.sys_count_post(uuid);
--   drop function if exists public.sys_count_get(uuid);
--   drop function if exists public.sys_count_set(uuid, uuid, numeric);
--   drop function if exists public.sys_count_start(text, uuid, text);
--   drop function if exists public.sys_low_stock(text);
--   drop function if exists public.sys_moves_list(text, uuid, int);
--   drop function if exists public.sys_transfer(text, uuid, uuid, uuid, numeric, text);
--   drop function if exists public.sys_move(text, uuid, uuid, text, numeric, text, text);
--   drop function if exists public.sys_item_save(text, uuid, text, text, text, text, numeric);
--   drop function if exists public.sys_items_list(text, uuid);
--   drop function if exists public.sys_warehouse_save(text, uuid, text, text, boolean);
--   drop function if exists public.sys_warehouses_list(text);
--   drop function if exists public.sys_audit_list(int);
--   drop function if exists public.sys_set_permission(text, text, text, text);
--   drop function if exists public.sys_set_admin(text, boolean);
--   drop function if exists public.sys_people();
--   drop function if exists public.sys_me();
--   drop function if exists public.sys_can(text, text, text);
--   drop function if exists public.sys_is_admin();
--   drop function if exists public.sys_log(text, text, text, jsonb);
--   drop function if exists public.sys_rank(text);
--   drop function if exists public.sys_my_email();
--   drop table if exists public.sys_count_lines, public.sys_counts, public.sys_moves,
--     public.sys_stock, public.sys_items, public.sys_warehouses, public.sys_audit,
--     public.sys_permissions, public.sys_admins;
-- =====================================================================================

begin;

-- ---------- tables ----------
create table if not exists public.sys_admins (
  email    text primary key check (email = lower(email)),
  added_by text,
  added_at timestamptz not null default now()
);

create table if not exists public.sys_permissions (
  company    text not null check (company in ('tuya-suez','aix','jaguar')),
  email      text not null check (email = lower(email)),
  module     text not null check (module in ('users','inventory','sales','purchasing','accounts','projects','hr','reports')),
  level      text not null check (level in ('view','edit','approve')),
  granted_by text,
  granted_at timestamptz not null default now(),
  primary key (company, email, module)
);
create index if not exists sys_permissions_email_idx on public.sys_permissions (email);

create table if not exists public.sys_audit (
  id      bigint generated always as identity primary key,
  at      timestamptz not null default now(),
  actor   text,
  action  text not null,
  company text,
  target  text,
  details jsonb
);
create index if not exists sys_audit_at_idx on public.sys_audit (at desc);

create table if not exists public.sys_warehouses (
  id         uuid primary key default gen_random_uuid(),
  company    text not null check (company in ('tuya-suez','aix','jaguar')),
  name       text not null check (btrim(name) <> ''),
  location   text,
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  unique (company, name)
);

create table if not exists public.sys_items (
  id         uuid primary key default gen_random_uuid(),
  company    text not null check (company in ('tuya-suez','aix','jaguar')),
  code       text,
  name       text not null check (btrim(name) <> ''),
  category   text,
  unit       text not null default 'قطعة',
  min_qty    numeric check (min_qty is null or min_qty >= 0),
  product_id uuid references public.products(id) on delete set null,
  legacy_id  uuid,   -- id of the row copied from public.inventory_items by sys_import_legacy (makes the import run once)
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists sys_items_company_code_key on public.sys_items (company, code) where code is not null;
create unique index if not exists sys_items_legacy_key on public.sys_items (legacy_id) where legacy_id is not null;
create index if not exists sys_items_company_idx on public.sys_items (company);

create table if not exists public.sys_stock (
  item_id      uuid not null references public.sys_items(id),
  warehouse_id uuid not null references public.sys_warehouses(id),
  qty          numeric not null default 0 check (qty >= 0),
  primary key (item_id, warehouse_id)
);
create index if not exists sys_stock_wh_idx on public.sys_stock (warehouse_id);

create table if not exists public.sys_moves (
  id           uuid primary key default gen_random_uuid(),
  at           timestamptz not null default now(),
  company      text not null check (company in ('tuya-suez','aix','jaguar')),
  item_id      uuid not null references public.sys_items(id),
  warehouse_id uuid not null references public.sys_warehouses(id),
  kind         text not null check (kind in ('in','out','adjust','transfer_out','transfer_in')),
  qty          numeric not null,   -- > 0, except 'adjust' which stores the signed delta (<> 0)
  qty_before   numeric not null,
  qty_after    numeric not null,
  ref          text,
  note         text,
  by_email     text,
  check ((kind = 'adjust' and qty <> 0) or (kind <> 'adjust' and qty > 0))
);
create index if not exists sys_moves_company_at_idx on public.sys_moves (company, at desc);
create index if not exists sys_moves_item_idx on public.sys_moves (item_id, at desc);

create table if not exists public.sys_counts (
  id           uuid primary key default gen_random_uuid(),
  company      text not null check (company in ('tuya-suez','aix','jaguar')),
  warehouse_id uuid not null references public.sys_warehouses(id),
  status       text not null default 'draft' check (status in ('draft','posted','cancelled')),
  note         text,
  created_by   text,
  created_at   timestamptz not null default now(),
  posted_by    text,
  posted_at    timestamptz
);
create index if not exists sys_counts_company_idx on public.sys_counts (company, created_at desc);

create table if not exists public.sys_count_lines (
  count_id uuid not null references public.sys_counts(id) on delete cascade,
  item_id  uuid not null references public.sys_items(id),
  expected numeric not null,
  counted  numeric check (counted is null or counted >= 0),
  primary key (count_id, item_id)
);

-- RLS on, no policies, no direct grants: only the security-definer functions below touch these tables.
alter table public.sys_admins      enable row level security;
alter table public.sys_permissions enable row level security;
alter table public.sys_audit       enable row level security;
alter table public.sys_warehouses  enable row level security;
alter table public.sys_items       enable row level security;
alter table public.sys_stock       enable row level security;
alter table public.sys_moves       enable row level security;
alter table public.sys_counts      enable row level security;
alter table public.sys_count_lines enable row level security;
revoke all on public.sys_admins, public.sys_permissions, public.sys_audit, public.sys_warehouses,
  public.sys_items, public.sys_stock, public.sys_moves, public.sys_counts, public.sys_count_lines
  from anon, authenticated;

-- seed: the owner is the only admin. Ayman: مش موجود (email unknown) — added later from the admin screen.
insert into public.sys_admins (email, added_by) values ('abdallahsad35@gmail.com', 'migration 114')
on conflict do nothing;

-- ---------- internal helpers (not callable by clients) ----------
create or replace function public.sys_my_email()
returns text language sql stable security definer set search_path = '' as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''));
$$;
revoke execute on function public.sys_my_email() from public, anon, authenticated;

create or replace function public.sys_rank(p_level text)
returns int language sql immutable set search_path = '' as $$
  select case p_level when 'view' then 1 when 'edit' then 2 when 'approve' then 3 else 0 end;
$$;
revoke execute on function public.sys_rank(text) from public, anon, authenticated;

create or replace function public.sys_log(p_action text, p_company text, p_target text, p_details jsonb)
returns void language sql security definer set search_path = '' as $$
  insert into public.sys_audit (actor, action, company, target, details)
  values (public.sys_my_email(), p_action, p_company, p_target, p_details);
$$;
revoke execute on function public.sys_log(text, text, text, jsonb) from public, anon, authenticated;

-- ---------- identity (the page may call these) ----------
create or replace function public.sys_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.sys_admins a where a.email = public.sys_my_email());
$$;
revoke execute on function public.sys_is_admin() from public, anon;
grant execute on function public.sys_is_admin() to authenticated;

create or replace function public.sys_can(p_company text, p_module text, p_level text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_me   text := public.sys_my_email();
  v_need int  := public.sys_rank(p_level);
begin
  if v_me = '' or v_need = 0 then return false; end if;
  if p_company is null or p_company not in ('tuya-suez','aix','jaguar') then return false; end if;
  if p_module is null or p_module not in ('users','inventory','sales','purchasing','accounts','projects','hr','reports') then return false; end if;
  if exists (select 1 from public.sys_admins a where a.email = v_me) then return true; end if;
  return exists (
    select 1 from public.sys_permissions p
    where p.company = p_company and p.email = v_me and p.module = p_module
      and public.sys_rank(p.level) >= v_need
  );
end;
$$;
revoke execute on function public.sys_can(text, text, text) from public, anon;
grant execute on function public.sys_can(text, text, text) to authenticated;

create or replace function public.sys_me()
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  v_me      text := public.sys_my_email();
  v_admin   boolean;
  v_modules text[] := array['users','inventory','sales','purchasing','accounts','projects','hr','reports'];
  v_comps   text[];
  v_perms   jsonb;
begin
  if v_me = '' then raise exception 'not signed in'; end if;
  v_admin := public.sys_is_admin();
  if v_admin then
    v_comps := array['tuya-suez','aix'];
    select coalesce(jsonb_object_agg(c, (select jsonb_object_agg(m, 'approve') from unnest(v_modules) as m)), '{}'::jsonb)
      into v_perms from unnest(v_comps) as c;
  else
    select coalesce(array_agg(distinct p.company order by p.company), '{}') into v_comps
      from public.sys_permissions p where p.email = v_me;
    select coalesce(jsonb_object_agg(c.company, c.m), '{}'::jsonb) into v_perms
      from (select p.company, jsonb_object_agg(p.module, p.level) as m
              from public.sys_permissions p where p.email = v_me group by p.company) c;
  end if;
  return json_build_object('email', v_me, 'is_admin', v_admin, 'companies', to_json(v_comps), 'perms', v_perms);
end;
$$;
revoke execute on function public.sys_me() from public, anon;
grant execute on function public.sys_me() to authenticated;

-- ---------- admin (admin only, every change logged) ----------
create or replace function public.sys_people()
returns table (email text, is_admin boolean, perms jsonb)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_emails text[];
  v_tsd    text[];
begin
  if not public.sys_is_admin() then raise exception 'not allowed'; end if;
  select coalesce(array_agg(x.e), '{}') into v_emails from (
    select lower(btrim(t.email)) as e from public.team_members t
    union select p.email from public.sys_permissions p
    union select a.email from public.sys_admins a
  ) x where x.e is not null and x.e <> '';
  if to_regclass('public.tsd_memberships') is not null then
    execute 'select coalesce(array_agg(distinct lower(btrim(m.email))), ''{}'') from public.tsd_memberships m where m.email is not null'
      into v_tsd;
    v_emails := v_emails || coalesce(v_tsd, '{}');
  end if;
  return query
    select e.addr,
           exists (select 1 from public.sys_admins a where a.email = e.addr),
           coalesce((select jsonb_object_agg(c.company, c.m)
                       from (select p.company, jsonb_object_agg(p.module, p.level) as m
                               from public.sys_permissions p where p.email = e.addr group by p.company) c),
                    '{}'::jsonb)
      from (select distinct u as addr from unnest(v_emails) as u where u <> '') e
     order by e.addr;
end;
$$;
revoke execute on function public.sys_people() from public, anon;
grant execute on function public.sys_people() to authenticated;

create or replace function public.sys_set_admin(p_email text, p_on boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_me    text := public.sys_my_email();
begin
  if not public.sys_is_admin() then raise exception 'not allowed'; end if;
  if v_email = '' or position('@' in v_email) < 2 or length(v_email) > 254 then raise exception 'bad email'; end if;
  if p_on is null then raise exception 'bad flag'; end if;
  perform 1 from public.sys_admins a for update;   -- serialise admin changes so the last admin cannot be removed concurrently
  if p_on then
    insert into public.sys_admins (email, added_by) values (v_email, v_me) on conflict do nothing;
  else
    if v_email = v_me then raise exception 'cannot remove yourself'; end if;
    if (select count(*) from public.sys_admins) <= 1
       and exists (select 1 from public.sys_admins a where a.email = v_email) then
      raise exception 'cannot remove the last admin';
    end if;
    delete from public.sys_admins where email = v_email;
  end if;
  perform public.sys_log('admin.set', null, v_email, jsonb_build_object('on', p_on));
end;
$$;
revoke execute on function public.sys_set_admin(text, boolean) from public, anon;
grant execute on function public.sys_set_admin(text, boolean) to authenticated;

create or replace function public.sys_set_permission(p_company text, p_email text, p_module text, p_level text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not public.sys_is_admin() then raise exception 'not allowed'; end if;
  if p_company is null or p_company not in ('tuya-suez','aix','jaguar') then raise exception 'bad company'; end if;
  if p_module is null or p_module not in ('users','inventory','sales','purchasing','accounts','projects','hr','reports') then raise exception 'bad module'; end if;
  if v_email = '' or position('@' in v_email) < 2 or length(v_email) > 254 then raise exception 'bad email'; end if;
  if p_level is not null and p_level not in ('view','edit','approve') then raise exception 'bad level'; end if;
  if p_level is null then
    delete from public.sys_permissions where company = p_company and email = v_email and module = p_module;
  else
    insert into public.sys_permissions (company, email, module, level, granted_by)
    values (p_company, v_email, p_module, p_level, public.sys_my_email())
    on conflict (company, email, module)
    do update set level = excluded.level, granted_by = excluded.granted_by, granted_at = now();
  end if;
  perform public.sys_log('permission.set', p_company, v_email, jsonb_build_object('module', p_module, 'level', p_level));
end;
$$;
revoke execute on function public.sys_set_permission(text, text, text, text) from public, anon;
grant execute on function public.sys_set_permission(text, text, text, text) to authenticated;

create or replace function public.sys_audit_list(p_limit int default 100)
returns setof public.sys_audit language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sys_is_admin() then raise exception 'not allowed'; end if;
  return query select * from public.sys_audit a
    order by a.at desc, a.id desc limit greatest(1, least(coalesce(p_limit, 100), 1000));
end;
$$;
revoke execute on function public.sys_audit_list(int) from public, anon;
grant execute on function public.sys_audit_list(int) to authenticated;

-- ---------- inventory: warehouses and items ----------
create or replace function public.sys_warehouses_list(p_company text)
returns table (id uuid, name text, location text, active boolean, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not public.sys_can(p_company, 'inventory', 'view') then raise exception 'not allowed'; end if;
  return query select w.id, w.name, w.location, w.active, w.created_at
    from public.sys_warehouses w where w.company = p_company order by w.name;
end;
$$;
revoke execute on function public.sys_warehouses_list(text) from public, anon;
grant execute on function public.sys_warehouses_list(text) to authenticated;

create or replace function public.sys_warehouse_save(p_company text, p_id uuid, p_name text, p_location text, p_active boolean default true)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id   uuid;
  v_name text := btrim(coalesce(p_name, ''));
begin
  if not public.sys_can(p_company, 'inventory', 'edit') then raise exception 'not allowed'; end if;
  if v_name = '' then raise exception 'name required'; end if;
  if p_id is null then
    insert into public.sys_warehouses (company, name, location, active)
    values (p_company, v_name, nullif(btrim(coalesce(p_location, '')), ''), coalesce(p_active, true))
    returning id into v_id;
  else
    update public.sys_warehouses
       set name = v_name, location = nullif(btrim(coalesce(p_location, '')), ''), active = coalesce(p_active, true)
     where id = p_id and company = p_company
    returning id into v_id;
    if v_id is null then raise exception 'warehouse not found in this company'; end if;
  end if;
  perform public.sys_log('warehouse.save', p_company, v_id::text,
    jsonb_build_object('name', v_name, 'location', p_location, 'active', coalesce(p_active, true), 'created', p_id is null));
  return v_id;
end;
$$;
revoke execute on function public.sys_warehouse_save(text, uuid, text, text, boolean) from public, anon;
grant execute on function public.sys_warehouse_save(text, uuid, text, text, boolean) to authenticated;

create or replace function public.sys_items_list(p_company text, p_warehouse uuid default null)
returns table (id uuid, code text, name text, category text, unit text, min_qty numeric,
               total_qty numeric, wh_qty numeric, low boolean)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not public.sys_can(p_company, 'inventory', 'view') then raise exception 'not allowed'; end if;
  if p_warehouse is not null and not exists
     (select 1 from public.sys_warehouses w where w.id = p_warehouse and w.company = p_company) then
    raise exception 'warehouse not found in this company';
  end if;
  return query
    select i.id, i.code, i.name, i.category, i.unit, i.min_qty,
           tt.t,
           case when p_warehouse is null then null::numeric
                else coalesce((select s.qty from public.sys_stock s where s.item_id = i.id and s.warehouse_id = p_warehouse), 0) end,
           (i.min_qty is not null and tt.t <= i.min_qty)
      from public.sys_items i
      cross join lateral (select coalesce(sum(s.qty), 0) as t from public.sys_stock s where s.item_id = i.id) tt
     where i.company = p_company and i.active
     order by i.name;
end;
$$;
revoke execute on function public.sys_items_list(text, uuid) from public, anon;
grant execute on function public.sys_items_list(text, uuid) to authenticated;

create or replace function public.sys_item_save(p_company text, p_id uuid, p_code text, p_name text, p_category text, p_unit text, p_min_qty numeric)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id   uuid;
  v_name text := btrim(coalesce(p_name, ''));
  v_code text := nullif(btrim(coalesce(p_code, '')), '');
  v_unit text := coalesce(nullif(btrim(coalesce(p_unit, '')), ''), 'قطعة');
begin
  if not public.sys_can(p_company, 'inventory', 'edit') then raise exception 'not allowed'; end if;
  if v_name = '' then raise exception 'name required'; end if;
  if p_min_qty is not null and p_min_qty < 0 then raise exception 'min_qty must be >= 0'; end if;
  if p_id is null then
    insert into public.sys_items (company, code, name, category, unit, min_qty)
    values (p_company, v_code, v_name, nullif(btrim(coalesce(p_category, '')), ''), v_unit, p_min_qty)
    returning id into v_id;
  else
    update public.sys_items
       set code = v_code, name = v_name, category = nullif(btrim(coalesce(p_category, '')), ''),
           unit = v_unit, min_qty = p_min_qty, updated_at = now()
     where id = p_id and company = p_company
    returning id into v_id;
    if v_id is null then raise exception 'item not found in this company'; end if;
  end if;
  perform public.sys_log('item.save', p_company, v_id::text,
    jsonb_build_object('code', v_code, 'name', v_name, 'unit', v_unit, 'min_qty', p_min_qty, 'created', p_id is null));
  return v_id;
end;
$$;
revoke execute on function public.sys_item_save(text, uuid, text, text, text, text, numeric) from public, anon;
grant execute on function public.sys_item_save(text, uuid, text, text, text, text, numeric) to authenticated;

-- ---------- inventory: moves and transfers (row locks: stock can never go negative) ----------
create or replace function public.sys_move(p_company text, p_item uuid, p_warehouse uuid, p_kind text, p_qty numeric,
                                           p_ref text default null, p_note text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_before numeric;
  v_after  numeric;
  v_me     text := public.sys_my_email();
begin
  if not public.sys_can(p_company, 'inventory', 'edit') then raise exception 'not allowed'; end if;
  if p_kind is null or p_kind not in ('in','out') then raise exception 'kind must be in or out'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'qty must be > 0'; end if;
  if not exists (select 1 from public.sys_items i where i.id = p_item and i.company = p_company and i.active) then
    raise exception 'item not found in this company';
  end if;
  if not exists (select 1 from public.sys_warehouses w where w.id = p_warehouse and w.company = p_company and w.active) then
    raise exception 'warehouse not found in this company';
  end if;
  insert into public.sys_stock (item_id, warehouse_id, qty) values (p_item, p_warehouse, 0) on conflict do nothing;
  select s.qty into v_before from public.sys_stock s
   where s.item_id = p_item and s.warehouse_id = p_warehouse for update;
  v_after := case when p_kind = 'in' then v_before + p_qty else v_before - p_qty end;
  if v_after < 0 then raise exception 'insufficient stock: have %, need %', v_before, p_qty; end if;
  update public.sys_stock set qty = v_after where item_id = p_item and warehouse_id = p_warehouse;
  insert into public.sys_moves (company, item_id, warehouse_id, kind, qty, qty_before, qty_after, ref, note, by_email)
  values (p_company, p_item, p_warehouse, p_kind, p_qty, v_before, v_after, p_ref, p_note, v_me);
  perform public.sys_log('stock.' || p_kind, p_company, p_item::text,
    jsonb_build_object('warehouse', p_warehouse, 'qty', p_qty, 'before', v_before, 'after', v_after, 'ref', p_ref));
  return json_build_object('qty_before', v_before, 'qty_after', v_after);
end;
$$;
revoke execute on function public.sys_move(text, uuid, uuid, text, numeric, text, text) from public, anon;
grant execute on function public.sys_move(text, uuid, uuid, text, numeric, text, text) to authenticated;

create or replace function public.sys_transfer(p_company text, p_item uuid, p_from uuid, p_to uuid, p_qty numeric, p_note text default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_from_before numeric;
  v_to_before   numeric;
  v_me          text := public.sys_my_email();
begin
  if not public.sys_can(p_company, 'inventory', 'edit') then raise exception 'not allowed'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'qty must be > 0'; end if;
  if p_from is null or p_to is null or p_from = p_to then raise exception 'from and to must differ'; end if;
  if not exists (select 1 from public.sys_items i where i.id = p_item and i.company = p_company and i.active) then
    raise exception 'item not found in this company';
  end if;
  if (select count(*) from public.sys_warehouses w
       where w.id in (p_from, p_to) and w.company = p_company and w.active) <> 2 then
    raise exception 'warehouse not found in this company';
  end if;
  insert into public.sys_stock (item_id, warehouse_id, qty) values (p_item, p_from, 0) on conflict do nothing;
  insert into public.sys_stock (item_id, warehouse_id, qty) values (p_item, p_to, 0) on conflict do nothing;
  perform 1 from public.sys_stock s   -- lock both rows in a fixed order (no deadlock between opposite transfers)
   where s.item_id = p_item and s.warehouse_id in (p_from, p_to) order by s.warehouse_id for update;
  select s.qty into v_from_before from public.sys_stock s where s.item_id = p_item and s.warehouse_id = p_from;
  select s.qty into v_to_before   from public.sys_stock s where s.item_id = p_item and s.warehouse_id = p_to;
  if v_from_before < p_qty then raise exception 'insufficient stock: have %, need %', v_from_before, p_qty; end if;
  update public.sys_stock set qty = v_from_before - p_qty where item_id = p_item and warehouse_id = p_from;
  update public.sys_stock set qty = v_to_before + p_qty   where item_id = p_item and warehouse_id = p_to;
  insert into public.sys_moves (company, item_id, warehouse_id, kind, qty, qty_before, qty_after, ref, note, by_email)
  values (p_company, p_item, p_from, 'transfer_out', p_qty, v_from_before, v_from_before - p_qty, p_to::text, p_note, v_me),
         (p_company, p_item, p_to,   'transfer_in',  p_qty, v_to_before,   v_to_before + p_qty,   p_from::text, p_note, v_me);
  perform public.sys_log('stock.transfer', p_company, p_item::text,
    jsonb_build_object('from', p_from, 'to', p_to, 'qty', p_qty));
  return json_build_object('from_after', v_from_before - p_qty, 'to_after', v_to_before + p_qty);
end;
$$;
revoke execute on function public.sys_transfer(text, uuid, uuid, uuid, numeric, text) from public, anon;
grant execute on function public.sys_transfer(text, uuid, uuid, uuid, numeric, text) to authenticated;

create or replace function public.sys_moves_list(p_company text, p_item uuid default null, p_limit int default 200)
returns table (id uuid, at timestamptz, item_id uuid, item_code text, item_name text, warehouse_id uuid,
               warehouse_name text, kind text, qty numeric, qty_before numeric, qty_after numeric,
               ref text, note text, by_email text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not public.sys_can(p_company, 'inventory', 'view') then raise exception 'not allowed'; end if;
  return query
    select m.id, m.at, m.item_id, i.code, i.name, m.warehouse_id, w.name, m.kind, m.qty,
           m.qty_before, m.qty_after, m.ref, m.note, m.by_email
      from public.sys_moves m
      join public.sys_items i on i.id = m.item_id
      join public.sys_warehouses w on w.id = m.warehouse_id
     where m.company = p_company and (p_item is null or m.item_id = p_item)
     order by m.at desc, m.id
     limit greatest(1, least(coalesce(p_limit, 200), 1000));
end;
$$;
revoke execute on function public.sys_moves_list(text, uuid, int) from public, anon;
grant execute on function public.sys_moves_list(text, uuid, int) to authenticated;

create or replace function public.sys_low_stock(p_company text)
returns table (id uuid, code text, name text, category text, unit text, min_qty numeric, total_qty numeric)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not public.sys_can(p_company, 'inventory', 'view') then raise exception 'not allowed'; end if;
  return query
    select i.id, i.code, i.name, i.category, i.unit, i.min_qty, tt.t
      from public.sys_items i
      cross join lateral (select coalesce(sum(s.qty), 0) as t from public.sys_stock s where s.item_id = i.id) tt
     where i.company = p_company and i.active and i.min_qty is not null and tt.t <= i.min_qty
     order by i.name;
end;
$$;
revoke execute on function public.sys_low_stock(text) from public, anon;
grant execute on function public.sys_low_stock(text) to authenticated;

-- ---------- inventory: stock counts (الجرد) ----------
create or replace function public.sys_count_start(p_company text, p_warehouse uuid, p_note text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if not public.sys_can(p_company, 'inventory', 'edit') then raise exception 'not allowed'; end if;
  if not exists (select 1 from public.sys_warehouses w where w.id = p_warehouse and w.company = p_company and w.active) then
    raise exception 'warehouse not found in this company';
  end if;
  insert into public.sys_counts (company, warehouse_id, note, created_by)
  values (p_company, p_warehouse, p_note, public.sys_my_email())
  returning id into v_id;
  insert into public.sys_count_lines (count_id, item_id, expected)
  select v_id, i.id, coalesce(s.qty, 0)
    from public.sys_items i
    left join public.sys_stock s on s.item_id = i.id and s.warehouse_id = p_warehouse
   where i.company = p_company and i.active;
  perform public.sys_log('count.start', p_company, v_id::text, jsonb_build_object('warehouse', p_warehouse));
  return v_id;
end;
$$;
revoke execute on function public.sys_count_start(text, uuid, text) from public, anon;
grant execute on function public.sys_count_start(text, uuid, text) to authenticated;

create or replace function public.sys_count_set(p_count uuid, p_item uuid, p_counted numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_company text;
  v_status  text;
begin
  select c.company into v_company from public.sys_counts c where c.id = p_count;
  if v_company is null or not public.sys_can(v_company, 'inventory', 'edit') then raise exception 'not allowed'; end if;
  if p_counted is not null and p_counted < 0 then raise exception 'counted must be >= 0'; end if;
  select c.status into v_status from public.sys_counts c where c.id = p_count for update;
  if v_status <> 'draft' then raise exception 'count is not a draft'; end if;
  update public.sys_count_lines set counted = p_counted where count_id = p_count and item_id = p_item;
  if not found then raise exception 'item is not part of this count'; end if;
end;
$$;
revoke execute on function public.sys_count_set(uuid, uuid, numeric) from public, anon;
grant execute on function public.sys_count_set(uuid, uuid, numeric) to authenticated;

create or replace function public.sys_count_get(p_count uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare
  v_company text;
  v_out     json;
begin
  select c.company into v_company from public.sys_counts c where c.id = p_count;
  if v_company is null or not public.sys_can(v_company, 'inventory', 'view') then raise exception 'not allowed'; end if;
  select json_build_object(
           'id', c.id, 'company', c.company, 'warehouse_id', c.warehouse_id, 'warehouse_name', w.name,
           'status', c.status, 'note', c.note, 'created_by', c.created_by, 'created_at', c.created_at,
           'posted_by', c.posted_by, 'posted_at', c.posted_at,
           'lines', coalesce((
              select json_agg(json_build_object(
                       'item_id', l.item_id, 'code', i.code, 'name', i.name, 'unit', i.unit,
                       'expected', l.expected, 'counted', l.counted,
                       'diff', case when l.counted is null then null else l.counted - l.expected end)
                     order by i.name)
                from public.sys_count_lines l join public.sys_items i on i.id = l.item_id
               where l.count_id = c.id), '[]'::json))
    into v_out
    from public.sys_counts c join public.sys_warehouses w on w.id = c.warehouse_id
   where c.id = p_count;
  return v_out;
end;
$$;
revoke execute on function public.sys_count_get(uuid) from public, anon;
grant execute on function public.sys_count_get(uuid) to authenticated;

-- Posting sets each counted line's stock to the counted figure (adjust move = counted - quantity at posting time).
-- Lines left empty (counted = null) are not touched.
create or replace function public.sys_count_post(p_count uuid)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_company  text;
  v_c        public.sys_counts;
  r          record;
  v_before   numeric;
  v_delta    numeric;
  v_lines    int := 0;
  v_adjusted int := 0;
  v_me       text := public.sys_my_email();
begin
  select c.company into v_company from public.sys_counts c where c.id = p_count;
  if v_company is null or not public.sys_can(v_company, 'inventory', 'approve') then raise exception 'not allowed'; end if;
  select * into v_c from public.sys_counts c where c.id = p_count for update;
  if v_c.status <> 'draft' then raise exception 'count is not a draft'; end if;
  for r in
    select l.item_id, l.counted from public.sys_count_lines l
     where l.count_id = p_count and l.counted is not null order by l.item_id
  loop
    v_lines := v_lines + 1;
    insert into public.sys_stock (item_id, warehouse_id, qty) values (r.item_id, v_c.warehouse_id, 0) on conflict do nothing;
    select s.qty into v_before from public.sys_stock s
     where s.item_id = r.item_id and s.warehouse_id = v_c.warehouse_id for update;
    v_delta := r.counted - v_before;
    if v_delta <> 0 then
      update public.sys_stock set qty = r.counted where item_id = r.item_id and warehouse_id = v_c.warehouse_id;
      insert into public.sys_moves (company, item_id, warehouse_id, kind, qty, qty_before, qty_after, ref, note, by_email)
      values (v_c.company, r.item_id, v_c.warehouse_id, 'adjust', v_delta, v_before, r.counted, 'count:' || p_count::text, v_c.note, v_me);
      v_adjusted := v_adjusted + 1;
    end if;
  end loop;
  update public.sys_counts set status = 'posted', posted_by = v_me, posted_at = now() where id = p_count;
  perform public.sys_log('count.post', v_c.company, p_count::text,
    jsonb_build_object('warehouse', v_c.warehouse_id, 'lines', v_lines, 'adjusted', v_adjusted));
  return json_build_object('status', 'posted', 'lines', v_lines, 'adjusted', v_adjusted);
end;
$$;
revoke execute on function public.sys_count_post(uuid) from public, anon;
grant execute on function public.sys_count_post(uuid) to authenticated;

create or replace function public.sys_counts_list(p_company text)
returns table (id uuid, warehouse_id uuid, warehouse_name text, status text, note text, created_by text,
               created_at timestamptz, posted_by text, posted_at timestamptz, lines_total int, lines_counted int)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if not public.sys_can(p_company, 'inventory', 'view') then raise exception 'not allowed'; end if;
  return query
    select c.id, c.warehouse_id, w.name, c.status, c.note, c.created_by, c.created_at, c.posted_by, c.posted_at,
           (select count(*)::int from public.sys_count_lines l where l.count_id = c.id),
           (select count(*)::int from public.sys_count_lines l where l.count_id = c.id and l.counted is not null)
      from public.sys_counts c join public.sys_warehouses w on w.id = c.warehouse_id
     where c.company = p_company
     order by c.created_at desc
     limit 200;
end;
$$;
revoke execute on function public.sys_counts_list(text) from public, anon;
grant execute on function public.sys_counts_list(text) to authenticated;

-- ---------- optional: copy the old inventory of one company (NOT called by this migration) ----------
-- Copies public.inventory_items (that company) once: each old item becomes a sys_item (legacy_id marks it,
-- so running it again skips what was already copied), its quantity goes to the warehouse «المخزن الرئيسي»
-- with an 'in' move (ref 'legacy-import'). Reads public.inventory_items only; never changes it.
create or replace function public.sys_import_legacy(p_company text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_wh       uuid;
  v_item     uuid;
  r          record;
  v_imported int := 0;
  v_skipped  int := 0;
  v_me       text := public.sys_my_email();
begin
  if not public.sys_is_admin() then raise exception 'not allowed'; end if;
  if p_company is null or p_company not in ('tuya-suez','aix','jaguar') then raise exception 'bad company'; end if;
  insert into public.sys_warehouses (company, name) values (p_company, 'المخزن الرئيسي') on conflict do nothing;
  select w.id into v_wh from public.sys_warehouses w where w.company = p_company and w.name = 'المخزن الرئيسي';
  select count(*) into v_skipped from public.inventory_items ii
   where ii.company = p_company and exists (select 1 from public.sys_items s where s.legacy_id = ii.id);
  for r in
    select ii.id, ii.name, ii.category, ii.unit, ii.min_qty, ii.quantity, ii.product_id
      from public.inventory_items ii
     where ii.company = p_company
       and not exists (select 1 from public.sys_items s where s.legacy_id = ii.id)
     order by ii.name
  loop
    insert into public.sys_items (company, name, category, unit, min_qty, product_id, legacy_id)
    values (p_company, r.name, r.category, coalesce(nullif(btrim(r.unit), ''), 'قطعة'), r.min_qty, r.product_id, r.id)
    returning id into v_item;
    if coalesce(r.quantity, 0) > 0 then
      insert into public.sys_stock (item_id, warehouse_id, qty) values (v_item, v_wh, r.quantity)
      on conflict (item_id, warehouse_id) do update set qty = excluded.qty;
      insert into public.sys_moves (company, item_id, warehouse_id, kind, qty, qty_before, qty_after, ref, note, by_email)
      values (p_company, v_item, v_wh, 'in', r.quantity, 0, r.quantity, 'legacy-import', 'copied from inventory_items', v_me);
    end if;
    v_imported := v_imported + 1;
  end loop;
  perform public.sys_log('legacy.import', p_company, v_wh::text,
    jsonb_build_object('imported', v_imported, 'already_imported', v_skipped));
  return json_build_object('imported', v_imported, 'already_imported', v_skipped, 'warehouse_id', v_wh);
end;
$$;
revoke execute on function public.sys_import_legacy(text) from public, anon;
grant execute on function public.sys_import_legacy(text) to authenticated;

commit;
