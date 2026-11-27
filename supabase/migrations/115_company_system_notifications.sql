-- =====================================================================================
-- 115 — «نظام الشركة» — إشعارات + Web Push + «النشاط» (مين عمل إيه وامتى)
-- لم يُنفّذ — عبدالله يضغط Run   |   NOT RUN YET — Abdallah presses Run himself in the Supabase
-- SQL editor of project snrsfpprlynixotjipmo. Requires migration 114 to be run first.
--
-- ماذا ينشئ / What it creates (everything new, all prefixed sys_):
--   جداول / tables:
--     sys_push_subs      اشتراكات Web Push (بريد، endpoint فريد، p256dh، auth)
--     sys_notifications  إشعارات داخل النظام (شركة، المستلم، النوع، عنوان، نص، ref، created_at، read_at)
--     sys_config         key/value — فاضي. عبدالله يدخّل push_url و push_secret بإيده (انظر آخر الملف). لا أسرار هنا.
--   triggers (على جداول 114 من غير تعديل أي تعريف في 114):
--     sys_moves        after insert  -> إشعار وارد/صادر + إشعار «نزل عن الحد الأدنى» مرة واحدة عند العبور
--     sys_counts       after insert  -> إشعار «جرد محتاج موافقة» (114 مفيهاش خطوة إرسال للموافقة، فالإشعار عند فتح مسودة الجرد)
--     sys_permissions  after insert/update(level)/delete -> إشعار تغيير صلاحية
--     sys_admins       after insert/delete -> إشعار تغيير مدير
--   المستلمون / recipients (اللي عمل الحركة مايتبعتلوش / the actor never gets his own notification):
--     حركات المخزون + نقص الحد = أي حد عنده صلاحية inventory على الشركة + الأدمنز
--     الجرد = اللي عندهم approve على inventory + الأدمنز
--     الصلاحية/الأدمن = صاحب الصلاحية نفسه + الأدمنز
--   دوال للعميل / client RPCs (authenticated only; anon و public ممنوعين):
--     sys_push_subscribe(p_endpoint, p_p256dh, p_auth)  returns void
--     sys_push_unsubscribe(p_endpoint)                  returns void
--     sys_notifications_list(p_limit)                   returns table (id, company, kind, title, body, ref, created_at, read_at)
--     sys_notifications_read(p_ids uuid[])              returns int  (null = الكل)
--     sys_activity_list(p_limit)                        returns table (at, actor, company, module, action, summary)
--   دوال داخلية / internal (لا تُمنح لأحد): sys_company_label, sys_recipients, sys_notify, sys_push_dispatch, sys_trg_*
--   الإرسال الفعلي / actual push: بعد حفظ الإشعار، لو extension pg_net موجودة (net.http_post) ولو sys_config فيه
--     push_url و push_secret، يتبعت POST لـ push_url بهيدر x-sys-push-secret وbody فيه الإشعار + اشتراكات المستلم.
--     لو pg_net أو الإعدادات مش موجودة: الإشعار يتحفظ جوه النظام فقط ومفيش أي خطأ (وأي فشل في الإرسال يتبلع).
--   الأمان / security: RLS مفعّل على الجداول الجديدة بدون policies وبدون grants لـ anon/authenticated.
--
-- لا يغيّر أي شيء موجود / Nothing existing is changed: 114's functions and tables are untouched; only triggers
--   are ATTACHED to sys_moves / sys_counts / sys_permissions / sys_admins (drop trigger if exists + create).
--   Idempotent, one transaction: safe to run twice.
--
-- ---------------------------------------------------------------------------------------
-- UNDO / تراجع (by hand only; drops ONLY 115 objects — it destroys notifications and push subscriptions):
--   drop trigger if exists sys_notify_move  on public.sys_moves;
--   drop trigger if exists sys_notify_count on public.sys_counts;
--   drop trigger if exists sys_notify_perm  on public.sys_permissions;
--   drop trigger if exists sys_notify_perm_upd on public.sys_permissions;
--   drop trigger if exists sys_notify_admin on public.sys_admins;
--   drop function if exists public.sys_activity_list(int);
--   drop function if exists public.sys_notifications_read(uuid[]);
--   drop function if exists public.sys_notifications_list(int);
--   drop function if exists public.sys_push_unsubscribe(text);
--   drop function if exists public.sys_push_subscribe(text, text, text);
--   drop function if exists public.sys_trg_admin();
--   drop function if exists public.sys_trg_perm();
--   drop function if exists public.sys_trg_count();
--   drop function if exists public.sys_trg_move();
--   drop function if exists public.sys_notify(text, text[], text, text, text, text, jsonb);
--   drop function if exists public.sys_push_dispatch(uuid);
--   drop function if exists public.sys_recipients(text, text, text);
--   drop function if exists public.sys_company_label(text);
--   drop table if exists public.sys_config, public.sys_notifications, public.sys_push_subs;
-- =====================================================================================

begin;

-- ---------- tables ----------
create table if not exists public.sys_push_subs (
  id         bigint generated always as identity primary key,
  email      text not null check (email = lower(email)),
  endpoint   text not null unique check (endpoint like 'https://%' and length(endpoint) <= 2048),
  p256dh     text not null check (length(p256dh) between 1 and 512),
  auth       text not null check (length(auth) between 1 and 512),
  created_at timestamptz not null default now()
);
create index if not exists sys_push_subs_email_idx on public.sys_push_subs (email);

create table if not exists public.sys_notifications (
  id         uuid primary key default gen_random_uuid(),
  company    text check (company is null or company in ('tuya-suez','aix','jaguar')),
  email      text not null check (email = lower(email)),   -- the recipient
  kind       text not null,
  title      text not null,
  body       text,
  ref        jsonb,
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index if not exists sys_notifications_email_idx on public.sys_notifications (email, created_at desc);

create table if not exists public.sys_config (
  key   text primary key,
  value text not null
);

alter table public.sys_push_subs     enable row level security;
alter table public.sys_notifications enable row level security;
alter table public.sys_config        enable row level security;
revoke all on public.sys_push_subs, public.sys_notifications, public.sys_config from anon, authenticated;
-- sys_config starts EMPTY on purpose (no secret in this file). See the SQL at the bottom.

-- ---------- internal helpers (not callable by clients) ----------
create or replace function public.sys_company_label(p_company text)
returns text language sql immutable set search_path = '' as $$
  select case p_company when 'tuya-suez' then 'Tuya Suez' when 'aix' then 'AIX' when 'jaguar' then 'Jaguar' else coalesce(p_company, '') end;
$$;
revoke execute on function public.sys_company_label(text) from public, anon, authenticated;

-- everyone who has module p_module at >= p_level on p_company, plus all admins
create or replace function public.sys_recipients(p_company text, p_module text, p_level text)
returns text[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct x.e), '{}') from (
    select a.email as e from public.sys_admins a
    union
    select p.email from public.sys_permissions p
     where p.company = p_company and p.module = p_module
       and public.sys_rank(p.level) >= public.sys_rank(p_level)
  ) x where x.e is not null and x.e <> '';
$$;
revoke execute on function public.sys_recipients(text, text, text) from public, anon, authenticated;

-- optional real push through pg_net: silently does nothing when pg_net / config / subscriptions are missing
create or replace function public.sys_push_dispatch(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_n      record;
  v_url    text;
  v_secret text;
  v_subs   jsonb;
begin
  if to_regproc('net.http_post') is null then return; end if;
  select c.value into v_url    from public.sys_config c where c.key = 'push_url';
  select c.value into v_secret from public.sys_config c where c.key = 'push_secret';
  if coalesce(btrim(v_url), '') = '' or coalesce(btrim(v_secret), '') = '' then return; end if;
  select * into v_n from public.sys_notifications n where n.id = p_id;
  if not found then return; end if;
  select coalesce(jsonb_agg(jsonb_build_object('endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth)), '[]'::jsonb)
    into v_subs from public.sys_push_subs s where s.email = v_n.email;
  if v_subs = '[]'::jsonb then return; end if;
  execute 'select net.http_post(url := $1, body := $2, headers := $3)'
    using btrim(v_url),
          jsonb_build_object(
            'notification', jsonb_build_object('id', v_n.id, 'company', v_n.company, 'kind', v_n.kind,
                                               'title', v_n.title, 'body', v_n.body, 'ref', v_n.ref, 'url', '/system/'),
            'subscriptions', v_subs),
          jsonb_build_object('Content-Type', 'application/json', 'x-sys-push-secret', btrim(v_secret));
exception when others then
  return;   -- a push problem must never break the business transaction
end;
$$;
revoke execute on function public.sys_push_dispatch(uuid) from public, anon, authenticated;

-- one notification row per distinct recipient (the actor is skipped), then try the push
create or replace function public.sys_notify(p_company text, p_recipients text[], p_actor text, p_kind text,
                                             p_title text, p_body text, p_ref jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  for r in
    insert into public.sys_notifications (company, email, kind, title, body, ref)
    select p_company, e.addr, p_kind, p_title, p_body, p_ref
      from (select distinct lower(btrim(u)) as addr from unnest(coalesce(p_recipients, '{}')) as u) e
     where e.addr <> '' and e.addr is distinct from lower(btrim(coalesce(p_actor, '')))
    returning id
  loop
    perform public.sys_push_dispatch(r.id);
  end loop;
end;
$$;
revoke execute on function public.sys_notify(text, text[], text, text, text, text, jsonb) from public, anon, authenticated;

-- ---------- triggers ----------
-- stock moves: in / out notify; any in/out/adjust that takes the item's total from above min_qty to <= min_qty notifies once
create or replace function public.sys_trg_move()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_item   record;
  v_wh     text;
  v_rec    text[];
  v_total  numeric;
  v_delta  numeric;
  v_label  text := public.sys_company_label(new.company);
begin
  if new.ref = 'legacy-import' then return new; end if;   -- bulk import: no notification storm
  if new.kind not in ('in','out','adjust') then return new; end if;
  select i.name, i.unit, i.min_qty into v_item from public.sys_items i where i.id = new.item_id;
  select w.name into v_wh from public.sys_warehouses w where w.id = new.warehouse_id;
  v_rec := public.sys_recipients(new.company, 'inventory', 'view');

  if new.kind in ('in','out') then
    perform public.sys_notify(new.company, v_rec, new.by_email, 'stock.' || new.kind,
      case new.kind when 'in' then 'وارد مخزن — ' else 'صادر مخزن — ' end || v_label,
      coalesce(new.by_email, '؟') || (case new.kind when 'in' then ' سجّل وارد ' else ' سجّل صادر ' end)
        || trim_scale(new.qty)::text || ' ' || coalesce(v_item.unit, '')
        || ' من «' || coalesce(v_item.name, '') || '» — ' || coalesce(v_wh, '')
        || ' (الرصيد ' || trim_scale(new.qty_after)::text || ')',
      jsonb_build_object('move', new.id, 'item', new.item_id, 'warehouse', new.warehouse_id, 'qty', new.qty));
  end if;

  if v_item.min_qty is not null then
    select coalesce(sum(s.qty), 0) into v_total from public.sys_stock s where s.item_id = new.item_id;
    v_delta := case new.kind when 'in' then new.qty when 'out' then -new.qty else new.qty end;   -- adjust stores the signed delta
    if v_total <= v_item.min_qty and (v_total - v_delta) > v_item.min_qty then
      perform public.sys_notify(new.company, v_rec, null, 'stock.low',
        'نقص مخزون — ' || v_label,
        '«' || coalesce(v_item.name, '') || '» نزل لـ ' || trim_scale(v_total)::text
          || ' ' || coalesce(v_item.unit, '') || ' (الحد الأدنى '
          || trim_scale(v_item.min_qty)::text || ')',
        jsonb_build_object('item', new.item_id, 'total', v_total, 'min_qty', v_item.min_qty));
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.sys_trg_move() from public, anon, authenticated;

create or replace function public.sys_trg_count()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_wh text;
begin
  select w.name into v_wh from public.sys_warehouses w where w.id = new.warehouse_id;
  perform public.sys_notify(new.company, public.sys_recipients(new.company, 'inventory', 'approve'), new.created_by,
    'count.pending', 'جرد محتاج موافقة — ' || public.sys_company_label(new.company),
    coalesce(new.created_by, '؟') || ' فتح جرد لمخزن «' || coalesce(v_wh, '') || '» ومحتاج موافقة على الترحيل',
    jsonb_build_object('count', new.id, 'warehouse', new.warehouse_id));
  return new;
end;
$$;
revoke execute on function public.sys_trg_count() from public, anon, authenticated;

create or replace function public.sys_trg_perm()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_email text;
  v_co    text;
  v_mod   text;
  v_lvl   text;
  v_txt   text;
begin
  if tg_op = 'DELETE' then
    v_email := old.email; v_co := old.company; v_mod := old.module; v_lvl := null;
  else
    v_email := new.email; v_co := new.company; v_mod := new.module; v_lvl := new.level;
  end if;
  v_txt := case when v_lvl is null then 'اتشالت صلاحية ' || v_mod
                else 'صلاحية ' || v_mod || ' بقت ' || v_lvl end;
  perform public.sys_notify(v_co, array[v_email] || public.sys_recipients(v_co, '-', 'view'), public.sys_my_email(),
    'permission', 'تغيير صلاحية — ' || public.sys_company_label(v_co),
    v_email || ': ' || v_txt || ' (بواسطة ' || coalesce(nullif(public.sys_my_email(), ''), '؟') || ')',
    jsonb_build_object('email', v_email, 'module', v_mod, 'level', v_lvl));
  return null;
end;
$$;
revoke execute on function public.sys_trg_perm() from public, anon, authenticated;

create or replace function public.sys_trg_admin()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_email text := case when tg_op = 'DELETE' then old.email else new.email end;
  v_on    boolean := tg_op <> 'DELETE';
begin
  perform public.sys_notify(null, array[v_email] || public.sys_recipients(null, '-', 'view'), public.sys_my_email(),
    'admin', 'تغيير مدير',
    v_email || (case when v_on then ' بقى مدير' else ' اتشال من المديرين' end)
      || ' (بواسطة ' || coalesce(nullif(public.sys_my_email(), ''), '؟') || ')',
    jsonb_build_object('email', v_email, 'is_admin', v_on));
  return null;
end;
$$;
revoke execute on function public.sys_trg_admin() from public, anon, authenticated;

drop trigger if exists sys_notify_move on public.sys_moves;
create trigger sys_notify_move after insert on public.sys_moves
  for each row execute function public.sys_trg_move();

drop trigger if exists sys_notify_count on public.sys_counts;
create trigger sys_notify_count after insert on public.sys_counts
  for each row execute function public.sys_trg_count();

drop trigger if exists sys_notify_perm on public.sys_permissions;
create trigger sys_notify_perm after insert or delete on public.sys_permissions
  for each row execute function public.sys_trg_perm();
drop trigger if exists sys_notify_perm_upd on public.sys_permissions;
create trigger sys_notify_perm_upd after update on public.sys_permissions
  for each row when (old.level is distinct from new.level) execute function public.sys_trg_perm();

drop trigger if exists sys_notify_admin on public.sys_admins;
create trigger sys_notify_admin after insert or delete on public.sys_admins
  for each row execute function public.sys_trg_admin();

-- ---------- client RPCs ----------
create or replace function public.sys_push_subscribe(p_endpoint text, p_p256dh text, p_auth text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me text := public.sys_my_email();
begin
  if v_me = '' then raise exception 'not signed in'; end if;
  if p_endpoint is null or p_endpoint not like 'https://%' or length(p_endpoint) > 2048 then raise exception 'bad endpoint'; end if;
  if coalesce(p_p256dh, '') = '' or length(p_p256dh) > 512 or coalesce(p_auth, '') = '' or length(p_auth) > 512 then
    raise exception 'bad keys';
  end if;
  insert into public.sys_push_subs (email, endpoint, p256dh, auth) values (v_me, p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set email = excluded.email, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
end;
$$;
revoke execute on function public.sys_push_subscribe(text, text, text) from public, anon;
grant execute on function public.sys_push_subscribe(text, text, text) to authenticated;

create or replace function public.sys_push_unsubscribe(p_endpoint text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me text := public.sys_my_email();
begin
  if v_me = '' then raise exception 'not signed in'; end if;
  delete from public.sys_push_subs where endpoint = p_endpoint and email = v_me;
end;
$$;
revoke execute on function public.sys_push_unsubscribe(text) from public, anon;
grant execute on function public.sys_push_unsubscribe(text) to authenticated;

create or replace function public.sys_notifications_list(p_limit int default 50)
returns table (id uuid, company text, kind text, title text, body text, ref jsonb, created_at timestamptz, read_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_me text := public.sys_my_email();
begin
  if v_me = '' then raise exception 'not signed in'; end if;
  return query
    select n.id, n.company, n.kind, n.title, n.body, n.ref, n.created_at, n.read_at
      from public.sys_notifications n where n.email = v_me
     order by n.created_at desc, n.id
     limit greatest(1, least(coalesce(p_limit, 50), 500));
end;
$$;
revoke execute on function public.sys_notifications_list(int) from public, anon;
grant execute on function public.sys_notifications_list(int) to authenticated;

create or replace function public.sys_notifications_read(p_ids uuid[] default null)
returns int language plpgsql security definer set search_path = '' as $$
declare
  v_me text := public.sys_my_email();
  v_n  int;
begin
  if v_me = '' then raise exception 'not signed in'; end if;
  update public.sys_notifications n set read_at = now()
   where n.email = v_me and n.read_at is null and (p_ids is null or n.id = any (p_ids));
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.sys_notifications_read(uuid[]) from public, anon;
grant execute on function public.sys_notifications_read(uuid[]) to authenticated;

-- «مين عمل إيه وامتى» from sys_audit. actor = the email 114 stores. Admin sees everything; anyone else sees only
-- inventory rows of companies where he has view+, plus admin/permission lines that are about himself.
create or replace function public.sys_activity_list(p_limit int default 100)
returns table (at timestamptz, actor text, company text, module text, action text, summary text)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_me    text := public.sys_my_email();
  v_admin boolean;
begin
  if v_me = '' then raise exception 'not signed in'; end if;
  v_admin := public.sys_is_admin();
  return query
    with base as (
      select a.at, a.actor, a.company, a.action, a.target, a.details,
             case when a.action in ('admin.set','permission.set') then 'users' else 'inventory' end as module
        from public.sys_audit a
       order by a.at desc, a.id desc
    ), vis as (
      select b.* from base b
       where v_admin
          or (b.module = 'inventory' and b.company is not null and public.sys_can(b.company, 'inventory', 'view'))
          or (b.action in ('admin.set','permission.set') and b.target = v_me)
       order by b.at desc
       limit greatest(1, least(coalesce(p_limit, 100), 1000))
    )
    select v.at, v.actor, v.company, v.module, v.action,
           case v.action
             when 'admin.set' then v.target || case when (v.details ->> 'on')::boolean then ' بقى مدير' else ' اتشال من المديرين' end
             when 'permission.set' then v.target || ': ' || coalesce(v.details ->> 'module', '')
                  || case when v.details ->> 'level' is null then ' — اتشالت الصلاحية' else ' — ' || (v.details ->> 'level') end
             when 'stock.in'  then 'وارد ' || (v.details ->> 'qty') || ' من «' || coalesce(it.name, '؟') || '» (الرصيد ' || (v.details ->> 'before') || ' ← ' || (v.details ->> 'after') || ')'
             when 'stock.out' then 'صادر ' || (v.details ->> 'qty') || ' من «' || coalesce(it.name, '؟') || '» (الرصيد ' || (v.details ->> 'before') || ' ← ' || (v.details ->> 'after') || ')'
             when 'stock.transfer' then 'تحويل ' || (v.details ->> 'qty') || ' من «' || coalesce(it.name, '؟') || '»'
             when 'item.save' then case when (v.details ->> 'created')::boolean then 'صنف جديد «' else 'تعديل صنف «' end || coalesce(v.details ->> 'name', '') || '»'
             when 'warehouse.save' then case when (v.details ->> 'created')::boolean then 'مخزن جديد «' else 'تعديل مخزن «' end || coalesce(v.details ->> 'name', '') || '»'
             when 'count.start' then 'فتح جرد'
             when 'count.post' then 'رحّل جرد (' || coalesce(v.details ->> 'adjusted', '0') || ' تسوية من ' || coalesce(v.details ->> 'lines', '0') || ' سطر)'
             when 'legacy.import' then 'استيراد المخزون القديم (' || coalesce(v.details ->> 'imported', '0') || ' صنف)'
             else v.action
           end
      from vis v
      left join public.sys_items it on it.id::text = v.target and v.action like 'stock.%'
     order by v.at desc;
end;
$$;
revoke execute on function public.sys_activity_list(int) from public, anon;
grant execute on function public.sys_activity_list(int) to authenticated;

commit;

-- ---------------------------------------------------------------------------------------
-- بعد الـ Run (يدوي، عبدالله بس) / AFTER running — manual, by Abdallah only. NOT part of the transaction above.
-- 1) فعّل الـ extension من Dashboard ← Database ← Extensions ← pg_net (أو: create extension if not exists pg_net;)
-- 2) ادخل القيمتين (نفس السر اللي في Cloudflare SYS_PUSH_SECRET). ما تحطّش السر في أي ملف في الريبو:
--      insert into public.sys_config (key, value) values
--        ('push_url',    'https://jaguarsmart.com/api/sys-push'),
--        ('push_secret', '<نفس قيمة SYS_PUSH_SECRET>')
--      on conflict (key) do update set value = excluded.value;
-- من غير الخطوتين دول: الإشعارات بتتحفظ جوه النظام بس (مفيش Push) ومفيش أي خطأ.
