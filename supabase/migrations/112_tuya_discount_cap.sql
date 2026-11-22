-- 112 — Tuya Suez: 30% discount cap on CRM quotations, with approval by the owner of the 'pricing' area.
-- NOT RUN YET. Needs 001, 002, 004, 106 and 111 (tsd_approvals, tsd_areas 'pricing') to be live first.
-- Run it in the Supabase SQL editor of the CRM project (snrsfpprlynixotjipmo). Safe to re-run: every object
-- is "if not exists" / "or replace", and only this migration's own triggers are dropped before being created.
-- Nothing existing is altered or dropped. No row of quotations, quotation_items or products is changed.
--
-- The rule (owner's approved price list): "any price below the after-30% column goes as a request to
-- Ahmed Mostafa, and he approves it".
--   effective discount = 1 - (net of the catalog lines ÷ Σ qty × products.end_user_price of those lines)
--   * catalog line   = a line whose product (same company) has end_user_price > 0
--   * net            = Σ catalog line totals (qty × unit_price × (1 - line %)) plus any manual line with a
--                      NEGATIVE total (a hidden discount), then × (1 - quote discount %). Installation is left out.
--   So line 30% + quote 30% (= 51%) and a hand-lowered unit_price are both caught.
--
--   * A CRM (non-admin) user of Tuya Suez cannot move a quotation from draft to sent/accepted while its
--     effective discount is above 30%, unless an APPROVED request made through request_quote_discount_approval()
--     exists for that quotation and covers at least that discount (both the % and the amount in EGP). Editing a draft to a bigger discount
--     after approval needs a new approval. Admins are not limited; server jobs (no CRM role) are not touched.
--   * When a CRM user moves a quotation out of draft, its subtotal / install_amount / discount_amount / total
--     are recomputed from the saved lines (same formula as the CRM page), and installation cannot be negative.
--   * A CRM user can only set the quote discount to 0, 10, 20 or 30% (checked when it is set or changed,
--     so old saved quotations keep their numbers).
--   * Lines of a non-draft Tuya Suez quotation cannot be changed by a CRM user (the RLS policies and
--     replace_quotation_items already say so; this trigger also takes a lock on the quotation, so a line
--     edit and a send cannot race each other).

begin;

-- ---------- which request covers which discount (filled only by request_quote_discount_approval) ----------
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
  requested_by  text not null,
  created_at    timestamptz not null default now()
);
create index if not exists quote_discount_requests_quote_idx on public.quote_discount_requests (quotation_id, created_at desc);
alter table public.quote_discount_requests enable row level security;   -- no policies: read only through the functions below
revoke all on public.quote_discount_requests from anon, authenticated;

-- ---------- the effective discount of a saved quotation, computed on the server ----------
create or replace function public.quote_effective_discount(p_quote uuid, p_header_pct numeric)
returns table (catalog_total numeric, catalog_net numeric, effective_pct numeric)
language sql stable security definer set search_path = '' as $$
  with q as (
    select qq.id, qq.company from public.quotations qq where qq.id = p_quote
  ), l as (
    select (p.id is not null) as is_cat,
           i.qty * coalesce(p.end_user_price, 0) as cat_price,
           i.qty * i.unit_price * (1 - least(greatest(i.discount_pct, 0), 100) / 100.0) as line_total
    from q
    join public.quotation_items i on i.quotation_id = q.id
    left join public.products p on p.id = i.product_id and p.company = q.company and p.end_user_price > 0
  ), s as (
    select coalesce(sum(cat_price) filter (where is_cat), 0) as base,
           (coalesce(sum(line_total) filter (where is_cat), 0)
            + coalesce(sum(line_total) filter (where not is_cat and line_total < 0), 0))
           * (1 - least(greatest(coalesce(p_header_pct, 0), 0), 100) / 100.0) as net
    from l
  )
  select round(s.base, 2), round(s.net, 2),
         case when s.base > 0 then round(100 * (1 - s.net / s.base), 4) else 0 end
  from s;
$$;
revoke execute on function public.quote_effective_discount(uuid, numeric) from public, anon, authenticated;

-- highest discount % approved for this quotation (null = none) — for display
create or replace function public.quote_approved_pct(p_quote uuid)
returns numeric language sql stable security definer set search_path = '' as $$
  select max(r.effective_pct)
  from public.quote_discount_requests r
  join public.tsd_approvals a on a.id = r.approval_id
  where r.quotation_id = p_quote and a.status = 'approved' and a.area_key = 'pricing'
    and a.ref_table = 'quotations' and a.ref_id = p_quote and a.company = r.company;
$$;
revoke execute on function public.quote_approved_pct(uuid) from public, anon, authenticated;

-- an approved request covers the quotation as it is now only if BOTH the % and the discount amount
-- (catalog price − net) are not bigger than what was approved (1 EGP tolerance for rounding)
create or replace function public.quote_discount_covered(p_quote uuid, p_pct numeric, p_base numeric, p_net numeric)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.quote_discount_requests r
    join public.tsd_approvals a on a.id = r.approval_id
    where r.quotation_id = p_quote and a.status = 'approved' and a.area_key = 'pricing'
      and a.ref_table = 'quotations' and a.ref_id = p_quote and a.company = r.company
      and r.effective_pct >= p_pct
      and (r.catalog_total - r.catalog_net) + 1 >= (p_base - p_net));
$$;
revoke execute on function public.quote_discount_covered(uuid, numeric, numeric, numeric) from public, anon, authenticated;

-- ---------- guard on quotations ----------
create or replace function public.quote_discount_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_base numeric; v_net numeric; v_pct numeric; v_sub numeric;
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
    select d.catalog_total, d.catalog_net, d.effective_pct into v_base, v_net, v_pct
    from public.quote_effective_discount(new.id, new.discount_pct) d;
    if v_pct > 30 and not public.quote_discount_covered(new.id, v_pct, v_base, v_net) then
      raise exception 'discount_needs_approval: effective discount % is above 30', round(v_pct, 2)
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
declare q public.quotations; v_base numeric; v_net numeric; v_pct numeric;
        l_status text; l_pct numeric; l_note text; l_at timestamptz;
begin
  if not public.has_role(array['admin','crm']) then raise exception 'not allowed' using errcode = '42501'; end if;
  select * into q from public.quotations where id = p_quote;
  if not found or q.company is distinct from public.my_company() then
    raise exception 'quotation not found' using errcode = 'P0002';
  end if;
  select d.catalog_total, d.catalog_net, d.effective_pct into v_base, v_net, v_pct
  from public.quote_effective_discount(q.id, q.discount_pct) d;
  select a.status, r.effective_pct, a.decision_note, r.created_at into l_status, l_pct, l_note, l_at
  from public.quote_discount_requests r join public.tsd_approvals a on a.id = r.approval_id
  where r.quotation_id = q.id order by r.created_at desc limit 1;
  return json_build_object(
    'limit_pct', 30, 'applies', q.company = 'tuya-suez',
    'effective_pct', v_pct, 'catalog_total', v_base, 'catalog_net', v_net,
    'approved_pct', public.quote_approved_pct(q.id),
    'covered', v_pct <= 30 or public.quote_discount_covered(q.id, v_pct, v_base, v_net),
    'last_status', l_status, 'last_pct', l_pct, 'last_note', l_note, 'last_at', l_at);
end $$;
revoke execute on function public.quote_discount_state(uuid) from public, anon;
grant execute on function public.quote_discount_state(uuid) to authenticated;

-- ---------- «اطلب موافقة»: one pending request per quotation ----------
-- The caller must be allowed to edit the quotation under the CRM's own rules (admin/crm, same company,
-- a draft unless admin). The discount is recomputed here from the saved lines and the catalog.
-- Pressing it again returns the same pending request. If the draft was changed to a bigger discount while
-- a request was still pending, that request is closed (so a stale screen cannot approve a number nobody
-- looked at) and a new one is opened with the new number.
create or replace function public.request_quote_discount_approval(p_quote uuid)
returns json language plpgsql volatile security definer set search_path = '' as $$
declare q public.quotations; v_base numeric; v_net numeric; v_pct numeric;
        v_pend uuid; v_pend_pct numeric; v_pend_amt numeric; v_id uuid; v_me text := public.tsd_me();
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

  select d.catalog_total, d.catalog_net, d.effective_pct into v_base, v_net, v_pct
  from public.quote_effective_discount(q.id, q.discount_pct) d;
  if v_pct <= 30 then
    return json_build_object('state', 'not_needed', 'effective_pct', v_pct);
  end if;
  if public.quote_discount_covered(q.id, v_pct, v_base, v_net) then
    return json_build_object('state', 'approved', 'effective_pct', v_pct, 'approved_pct', public.quote_approved_pct(q.id));
  end if;

  select a.id, r.effective_pct, r.catalog_total - r.catalog_net into v_pend, v_pend_pct, v_pend_amt
  from public.quote_discount_requests r join public.tsd_approvals a on a.id = r.approval_id
  where r.quotation_id = q.id and a.status = 'pending'
  order by r.created_at desc limit 1
  for update of a;
  if v_pend is not null and v_pend_pct >= v_pct and v_pend_amt + 1 >= v_base - v_net then
    return json_build_object('state', 'pending', 'approval_id', v_pend, 'effective_pct', v_pct, 'requested_pct', v_pend_pct);
  end if;
  if v_pend is not null then
    update public.tsd_approvals
       set status = 'rejected', decided_by = 'system', decided_at = now(),
           decision_note = format('العرض اتعدل لخصم %s%% — اتبعت طلب جديد', round(v_pct, 2))
     where id = v_pend and status = 'pending';
  end if;

  insert into public.tsd_approvals (company, area_key, title, details, amount, ref_table, ref_id, status, requested_by)
  values (q.company, 'pricing',
          left(format('خصم %s%% على عرض سعر %s — %s', round(v_pct, 2), q.quote_number, left(coalesce(q.client_name, ''), 80)), 200),
          format('الخصم الفعلي %s%% والحد 30%%. سعر الكتالوج %s ج، بعد الخصم %s ج (من غير التركيب). خصم العرض %s%%. نوع السعر: %s. طالبه: %s',
                 round(v_pct, 2), v_base, v_net, coalesce(q.discount_pct, 0),
                 case q.client_type when 'dealer' then 'ديلر' else 'عميل' end, split_part(v_me, '@', 1)),
          round(v_base - v_net, 2), 'quotations', q.id, 'pending', v_me)
  returning id into v_id;
  insert into public.quote_discount_requests (approval_id, quotation_id, company, effective_pct, catalog_total, catalog_net, header_pct, requested_by)
  values (v_id, q.id, q.company, v_pct, v_base, v_net, coalesce(q.discount_pct, 0), v_me);
  return json_build_object('state', 'pending', 'approval_id', v_id, 'effective_pct', v_pct, 'requested_pct', v_pct);
end $$;
revoke execute on function public.request_quote_discount_approval(uuid) from public, anon;
grant execute on function public.request_quote_discount_approval(uuid) to authenticated;

commit;
