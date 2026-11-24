-- 112 — Tuya Suez: 30% discount cap on CRM quotations, with approval by the owner of the 'pricing' area.
-- NOT RUN YET. Needs 001, 002, 004, 106 and 111 (tsd_approvals, tsd_areas 'tuya-suez'/'pricing') to be live first.
-- Run it in the Supabase SQL editor of the CRM project (snrsfpprlynixotjipmo). Safe to re-run: every object
-- is "if not exists" / "or replace"; only this migration's own triggers and helper functions are dropped and recreated.
-- Nothing existing is altered or dropped. No row of quotations, quotation_items or products is changed.
--
-- The rule (owner's approved price list): "any price below the after-30% column goes as a request to
-- Ahmed Mostafa, and he approves it".
--   effective discount = 1 - (net of the catalog lines ÷ Σ qty × catalog price of those lines)
--   * catalog price  = products.end_user_price; for a dealer quote (client_type 'dealer')
--                      coalesce(products.dealer_price, products.end_user_price)
--   * catalog line   = a line whose product (same company) has a catalog price > 0
--   * manual line    = any other line (no product, or a product without a catalog price)
--   * net            = Σ catalog line totals (qty × unit_price × (1 - line %)) plus any manual line with a
--                      NEGATIVE total (a hidden discount), then × (1 - quote discount %). Installation is left out.
--   So line 30% + quote 30% (= 51%) and a hand-lowered unit_price are both caught.
--
--   A quotation NEEDS APPROVAL when its effective discount is above 30%, OR it has any manual line (a line
--   renamed away from its product's name counts as manual), OR any single catalog line ends below 70% of
--   its catalog price after the line % and the quote %.
--   * A CRM (non-admin) user of Tuya Suez cannot move a quotation from draft to sent/accepted while it needs
--     approval, unless an APPROVED request made through request_quote_discount_approval() exists for that
--     quotation and covers it as it is now: % not bigger, discount amount (EGP) not bigger, the manual /
--     below-floor lines, the quote discount and the client type (price list) exactly the same (any change
--     to them needs a new approval), and approved within the last 14 days.
--   * The check runs on the NEW row: a send that also changes client_type is measured on the new price list.
--     Admins are not limited; server jobs (no CRM role) are not touched.
--   * When a CRM user moves a quotation out of draft, its subtotal / install_amount / discount_amount / total
--     are recomputed from the saved lines (same formula as the CRM page), and installation cannot be negative.
--   * A CRM user can only set the quote discount to 0, 10, 20 or 30% (checked when it is set or changed,
--     so old saved quotations keep their numbers).
--   * Lines of a non-draft Tuya Suez quotation cannot be changed by a CRM user (the RLS policies and
--     replace_quotation_items already say so; this trigger also takes a lock on the quotation, so a line
--     edit and a send cannot race each other).

begin;

-- ---------- which request covers what (filled only by request_quote_discount_approval) ----------
-- The approval itself lives in tsd_approvals (shown on the dashboard, decided by tsd_decide). A row typed
-- by hand into tsd_approvals has no row here, so it never unlocks a quotation.
create table if not exists public.quote_discount_requests (
  approval_id   uuid primary key references public.tsd_approvals(id) on delete cascade,
  quotation_id  uuid not null references public.quotations(id) on delete cascade,
  company       text not null,
  effective_pct numeric not null,
  catalog_total numeric not null,
  catalog_net   numeric not null,
  header_pct    numeric not null,
  manual_lines  int not null default 0,
  manual_sig    text,
  requested_by  text not null,
  created_at    timestamptz not null default now()
);
alter table public.quote_discount_requests add column if not exists manual_lines int not null default 0;
alter table public.quote_discount_requests add column if not exists manual_sig text;
create index if not exists quote_discount_requests_quote_idx on public.quote_discount_requests (quotation_id, created_at desc);
alter table public.quote_discount_requests enable row level security;   -- no policies: read only through the functions below
revoke all on public.quote_discount_requests from public, anon, authenticated;

-- ---------- the numbers of a saved quotation, computed on the server ----------
-- p_client_type is passed in (the guard passes NEW.client_type), never read from the stored row.
-- manual_sig = md5 of the client type, the quote % and the manual / below-floor lines (name, qty, price,
-- line %, catalog unit), so any change to them shows. It is returned whenever the quote needs approval.
-- earlier drafts of this file (never run) used other names/columns; drop them so a re-run is clean
drop function if exists public.quote_effective_discount(uuid, numeric);
drop function if exists public.quote_discount_covered(uuid, numeric, numeric, numeric);
drop function if exists public.quote_discount_calc(uuid, numeric);
drop function if exists public.quote_discount_calc(uuid, numeric, text);
create function public.quote_discount_calc(p_quote uuid, p_header_pct numeric, p_client_type text)
returns table (catalog_total numeric, catalog_net numeric, effective_pct numeric,
               manual_lines int, manual_total numeric, floor_lines int, manual_sig text, needs_approval boolean)
language sql stable security definer set search_path = '' as $$
  with q as (
    select qq.id, qq.company, coalesce(p_client_type, '') as client_type from public.quotations qq where qq.id = p_quote
  ), x as (
    -- a line counts as catalog only if its product (same company) has a catalog price > 0 AND the line
    -- still carries that product's name; a renamed line is treated as manual
    select i.name, i.qty, i.unit_price, i.discount_pct,
           case when p.id is not null and lower(trim(i.name)) = lower(trim(p.name))
                then nullif(greatest(case when q.client_type = 'dealer' then coalesce(p.dealer_price, p.end_user_price)
                                          else p.end_user_price end, 0), 0) end as cat_unit
    from q
    join public.quotation_items i on i.quotation_id = q.id
    left join public.products p on p.id = i.product_id and p.company = q.company
  ), l as (
    select x.*, x.cat_unit is not null as cat,
           x.qty * coalesce(x.cat_unit, 0) as cat_price,
           x.qty * x.unit_price * (1 - least(greatest(x.discount_pct, 0), 100) / 100.0) as line_total,
           -- a catalog line whose own final unit price is below the after-30% price
           x.cat_unit is not null
             and x.unit_price * (1 - least(greatest(x.discount_pct, 0), 100) / 100.0)
                 * (1 - least(greatest(coalesce(p_header_pct, 0), 0), 100) / 100.0) < 0.7 * x.cat_unit - 0.005 as below
    from x
  ), s as (
    select coalesce(sum(cat_price) filter (where cat), 0) as base,
           (coalesce(sum(line_total) filter (where cat), 0)
            + coalesce(sum(line_total) filter (where not cat and line_total < 0), 0))
           * (1 - least(greatest(coalesce(p_header_pct, 0), 0), 100) / 100.0) as net,
           count(*) filter (where not cat)::int as m_n,
           coalesce(sum(line_total) filter (where not cat), 0) as m_total,
           count(*) filter (where below)::int as f_n,
           -- fingerprint of every line that needs a person to look at it (manual or below the floor) + quote %
           md5(jsonb_build_array(coalesce(p_client_type, ''), coalesce(p_header_pct, 0),
               coalesce(jsonb_agg(jsonb_build_array(lower(trim(name)), qty, unit_price, discount_pct, cat_unit)
                                  order by lower(trim(name)), qty, unit_price, discount_pct, cat_unit)
                        filter (where not cat or below), '[]'::jsonb))::text) as m_sig
    from l
  )
  select round(s.base, 2), round(s.net, 2),
         case when s.base > 0 then round(100 * (1 - s.net / s.base), 4) else 0 end,
         s.m_n, round(s.m_total, 2), s.f_n,
         case when (s.m_n > 0) or (s.f_n > 0) or (s.base > 0 and round(100 * (1 - s.net / s.base), 4) > 30)
              then s.m_sig end,
         (s.m_n > 0) or (s.f_n > 0) or (s.base > 0 and round(100 * (1 - s.net / s.base), 4) > 30)
  from s;
$$;
revoke execute on function public.quote_discount_calc(uuid, numeric, text) from public, anon, authenticated;

-- does a request in status p_status cover the quotation as it is now? An approval counts for 14 days.
create or replace function public.quote_discount_covers(p_quote uuid, p_status text, p_pct numeric,
                                                        p_base numeric, p_net numeric, p_sig text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.quote_discount_requests r
    join public.tsd_approvals a on a.id = r.approval_id
    where r.quotation_id = p_quote and a.status = p_status and a.area_key = 'pricing'
      and a.ref_table = 'quotations' and a.ref_id = p_quote and a.company = r.company
      and (p_status <> 'approved' or a.decided_at > now() - interval '14 days')
      and r.effective_pct >= p_pct
      and (r.catalog_total - r.catalog_net) + 1 >= (p_base - p_net)
      and r.manual_sig is not distinct from p_sig);
$$;
revoke execute on function public.quote_discount_covers(uuid, text, numeric, numeric, numeric, text) from public, anon, authenticated;

-- highest discount % approved (and not expired) for this quotation (null = none) — for display only
create or replace function public.quote_approved_pct(p_quote uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select max(r.effective_pct)
  from public.quote_discount_requests r
  join public.tsd_approvals a on a.id = r.approval_id
  where r.quotation_id = p_quote and a.status = 'approved' and a.area_key = 'pricing'
    and a.ref_table = 'quotations' and a.ref_id = p_quote and a.company = r.company
    and a.decided_at > now() - interval '14 days';
$$;
revoke execute on function public.quote_approved_pct(uuid) from public, anon, authenticated;

-- ---------- guard on quotations ----------
create or replace function public.quote_discount_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare c record; v_sub numeric;
begin
  if new.company is distinct from 'tuya-suez' or public.has_role(array['admin'])
     or not public.has_role(array['crm']) then
    return new;
  end if;
  if coalesce(new.install_pct, 0) < 0 or coalesce(new.install_amount, 0) < 0 then
    raise exception 'install_not_allowed: installation cannot be negative' using errcode = 'P0001';
  end if;
  if (tg_op = 'INSERT' or new.discount_pct is distinct from old.discount_pct)
     and coalesce(new.discount_pct, 0) not in (0, 10, 20, 30) then
    raise exception 'discount_not_allowed: quote discount must be 0, 10, 20 or 30' using errcode = 'P0001';
  end if;
  if new.status in ('sent', 'accepted') and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    -- measured on the NEW row (client type and quote %), not on what is stored before this update
    select * into c from public.quote_discount_calc(new.id, new.discount_pct, new.client_type);
    if c.needs_approval and not public.quote_discount_covers(new.id, 'approved', c.effective_pct,
                                                             c.catalog_total, c.catalog_net, c.manual_sig) then
      raise exception 'discount_needs_approval: effective discount %, manual lines %', round(c.effective_pct, 2), c.manual_lines
        using errcode = 'P0001', hint = 'request_quote_discount_approval';
    end if;
    -- the stored money columns of a quotation that leaves draft are the server's own numbers
    -- (same formula as calcQuote in crm.html), not whatever the browser sent
    select coalesce(sum(i.qty * i.unit_price * (1 - least(greatest(i.discount_pct, 0), 100) / 100.0)), 0) into v_sub
    from public.quotation_items i where i.quotation_id = new.id;
    new.subtotal := v_sub;
    new.install_amount := round(v_sub * coalesce(new.install_pct, 0) / 100);
    new.discount_amount := round((v_sub + new.install_amount) * coalesce(new.discount_pct, 0) / 100);
    new.total := v_sub + new.install_amount - new.discount_amount;
  end if;
  return new;
end $$;
revoke execute on function public.quote_discount_guard() from public, anon, authenticated;

drop trigger if exists quotations_discount_guard on public.quotations;
create trigger quotations_discount_guard before insert or update on public.quotations
  for each row execute function public.quote_discount_guard();

-- ---------- guard on quotation_items ----------
create or replace function public.quote_items_draft_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[] := '{}'; v_id uuid; v_status text; v_company text;
begin
  if public.has_role(array['admin']) or not public.has_role(array['crm']) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if tg_op in ('UPDATE', 'DELETE') then v_ids := v_ids || old.quotation_id; end if;
  if tg_op in ('INSERT', 'UPDATE') then v_ids := v_ids || new.quotation_id; end if;
  foreach v_id in array v_ids loop
    continue when v_id is null;
    select q.status, q.company into v_status, v_company from public.quotations q where q.id = v_id for share;
    if found and v_company = 'tuya-suez' and v_status <> 'draft' then
      raise exception 'quotation is locked' using errcode = 'P0001';
    end if;
  end loop;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
revoke execute on function public.quote_items_draft_guard() from public, anon, authenticated;

drop trigger if exists quotation_items_draft_guard on public.quotation_items;
create trigger quotation_items_draft_guard before insert or update or delete on public.quotation_items
  for each row execute function public.quote_items_draft_guard();

-- ---------- what the CRM shows ----------
create or replace function public.quote_discount_state(p_quote uuid)
returns json language plpgsql stable security definer set search_path = '' as $$
declare q public.quotations; c record; l_status text; l_pct numeric; l_note text; l_at timestamptz;
begin
  if not public.has_role(array['admin','crm']) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into q from public.quotations where id = p_quote;
  if not found or q.company is distinct from public.my_company() then
    raise exception 'quotation not found' using errcode = 'P0002';
  end if;
  select * into c from public.quote_discount_calc(q.id, q.discount_pct, q.client_type);
  select a.status, r.effective_pct, a.decision_note, r.created_at into l_status, l_pct, l_note, l_at
  from public.quote_discount_requests r join public.tsd_approvals a on a.id = r.approval_id
  where r.quotation_id = q.id order by r.created_at desc limit 1;
  return json_build_object(
    'limit_pct', 30, 'applies', q.company = 'tuya-suez',
    'effective_pct', c.effective_pct, 'catalog_total', c.catalog_total, 'catalog_net', c.catalog_net,
    'manual_lines', c.manual_lines, 'floor_lines', c.floor_lines, 'needs_approval', c.needs_approval,
    'approved_pct', public.quote_approved_pct(q.id),
    'covered', not c.needs_approval
               or public.quote_discount_covers(q.id, 'approved', c.effective_pct, c.catalog_total, c.catalog_net, c.manual_sig),
    'pending', c.needs_approval
               and public.quote_discount_covers(q.id, 'pending', c.effective_pct, c.catalog_total, c.catalog_net, c.manual_sig),
    'last_status', l_status, 'last_pct', l_pct, 'last_note', l_note, 'last_at', l_at);
end $$;
revoke execute on function public.quote_discount_state(uuid) from public, anon;
grant execute on function public.quote_discount_state(uuid) to authenticated;

-- ---------- «اطلب موافقة»: one pending request per quotation ----------
-- The caller must be allowed to edit the quotation under the CRM's own rules (admin/crm, same company,
-- a draft unless admin). The numbers are recomputed here from the saved lines and the catalog.
-- Pressing it again returns the same pending request. If the draft was changed while a request was still
-- pending (bigger discount, or other manual lines), that request is closed (so a stale screen cannot
-- approve something nobody looked at) and a new one is opened with the new numbers.
create or replace function public.request_quote_discount_approval(p_quote uuid)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare q public.quotations; c record; v_pend uuid; v_id uuid; v_me text := public.tsd_me(); v_why text;
begin
  if not public.has_role(array['admin','crm']) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into q from public.quotations where id = p_quote for update;
  if not found or q.company is distinct from public.my_company() then
    raise exception 'quotation not found' using errcode = 'P0002';
  end if;
  if q.company <> 'tuya-suez' then raise exception 'not used for this company' using errcode = 'P0001'; end if;
  if q.status <> 'draft' and not public.has_role(array['admin']) then
    raise exception 'quotation is locked' using errcode = 'P0001';
  end if;

  select * into c from public.quote_discount_calc(q.id, q.discount_pct, q.client_type);
  if not c.needs_approval then
    return json_build_object('state', 'not_needed', 'effective_pct', c.effective_pct);
  end if;
  if public.quote_discount_covers(q.id, 'approved', c.effective_pct, c.catalog_total, c.catalog_net, c.manual_sig) then
    return json_build_object('state', 'approved', 'effective_pct', c.effective_pct);
  end if;
  if public.quote_discount_covers(q.id, 'pending', c.effective_pct, c.catalog_total, c.catalog_net, c.manual_sig) then
    return json_build_object('state', 'pending', 'effective_pct', c.effective_pct);
  end if;

  -- close any older pending request of this quotation: it no longer matches what would be sent
  for v_pend in
    select a.id from public.quote_discount_requests r join public.tsd_approvals a on a.id = r.approval_id
    where r.quotation_id = q.id and a.status = 'pending'
    for update of a
  loop
    update public.tsd_approvals
       set status = 'rejected', decided_by = 'system', decided_at = now(),
           decision_note = 'العرض اتعدل — اتبعت طلب جديد'
     where id = v_pend and status = 'pending';
  end loop;

  v_why := concat_ws(' + ',
    case when c.effective_pct > 30 then format('خصم %s%%', round(c.effective_pct, 2)) end,
    case when c.manual_lines > 0 then format('%s بند يدوي', c.manual_lines) end,
    case when c.floor_lines > 0 then format('%s بند تحت سعر الـ30%%', c.floor_lines) end);
  insert into public.tsd_approvals (company, area_key, title, details, amount, ref_table, ref_id, status, requested_by)
  values (q.company, 'pricing',
          left(format('%s — عرض سعر %s — %s', v_why, q.quote_number, left(coalesce(q.client_name, ''), 80)), 200),
          format('الخصم الفعلي %s%% والحد 30%%. سعر الكتالوج %s ج، بعد الخصم %s ج (من غير التركيب). خصم العرض %s%%. بنود يدوية: %s بإجمالي %s ج. نوع السعر: %s. طالبه: %s',
                 round(c.effective_pct, 2), c.catalog_total, c.catalog_net, coalesce(q.discount_pct, 0),
                 c.manual_lines, c.manual_total,
                 case q.client_type when 'dealer' then 'ديلر' else 'عميل' end, split_part(v_me, '@', 1)),
          round(c.catalog_total - c.catalog_net, 2), 'quotations', q.id, 'pending', v_me)
  returning id into v_id;
  insert into public.quote_discount_requests (approval_id, quotation_id, company, effective_pct, catalog_total, catalog_net,
                                              header_pct, manual_lines, manual_sig, requested_by)
  values (v_id, q.id, q.company, c.effective_pct, c.catalog_total, c.catalog_net,
          coalesce(q.discount_pct, 0), c.manual_lines, c.manual_sig, v_me);
  return json_build_object('state', 'pending', 'approval_id', v_id, 'effective_pct', c.effective_pct);
end $$;
revoke execute on function public.request_quote_discount_approval(uuid) from public, anon;
grant execute on function public.request_quote_discount_approval(uuid) to authenticated;

commit;
