-- SHAHI functions: lead intake (website form + n8n webhook), kitchen view, reports.

-- Egyptian mobile -> +20XXXXXXXXXX (null when invalid)
create or replace function public.shahi_phone(p text)
returns text language sql immutable set search_path = '' as $$
  with d as (select regexp_replace(coalesce(p, ''), '\D', '', 'g') as n)
  select case
    when n ~ '^01[0125][0-9]{8}$'    then '+2' || n
    when n ~ '^201[0125][0-9]{8}$'   then '+' || n
    when n ~ '^00201[0125][0-9]{8}$' then '+' || substr(n, 3)
    when n ~ '^1[0125][0-9]{8}$'     then '+20' || n
    when length(n) between 8 and 15  then '+' || n          -- foreign numbers (expats)
    else null end
  from d;
$$;

-- shared intake: finds/creates the customer by phone and opens a "new" lead.
-- Not callable by clients directly; the website and the webhook go through the wrappers below.
create or replace function public.shahi__intake(p jsonb, p_source text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := public.shahi_phone(p ->> 'phone');
  v_name text := left(btrim(coalesce(p ->> 'name', '')), 120);
  v_cust uuid; v_lead uuid; v_pkg uuid; v_guests int; v_date date; v_time time;
begin
  if v_phone is null then raise exception 'invalid phone'; end if;
  if v_name = '' then v_name := 'عميل ' || right(v_phone, 4); end if;
  if p_source not in ('website','whatsapp','ad','facebook','instagram','tiktok','phone','other') then p_source := 'other'; end if;
  begin v_guests := nullif(p ->> 'guests', '')::int; exception when others then v_guests := null; end;
  if v_guests is not null and (v_guests < 1 or v_guests > 5000) then v_guests := null; end if;
  begin v_date := nullif(p ->> 'event_date', '')::date; exception when others then v_date := null; end;
  begin v_time := nullif(p ->> 'event_time', '')::time; exception when others then v_time := null; end;
  begin v_pkg := nullif(p ->> 'package_id', '')::uuid; exception when others then v_pkg := null; end;
  if v_pkg is not null and not exists (select 1 from public.shahi_packages where id = v_pkg) then v_pkg := null; end if;

  insert into public.shahi_customers (name, phone, area, address)
  values (v_name, v_phone, nullif(left(btrim(p ->> 'area'), 80), ''), nullif(left(btrim(p ->> 'address'), 300), ''))
  on conflict (phone) do update set
    area = coalesce(excluded.area, public.shahi_customers.area),
    address = coalesce(excluded.address, public.shahi_customers.address)
  returning id into v_cust;

  insert into public.shahi_leads (customer_id, name, phone, area, address, event_type, event_date, event_time, guests,
                                  package_id, request, allergies, source)
  values (v_cust, v_name, v_phone,
          nullif(left(btrim(p ->> 'area'), 80), ''), nullif(left(btrim(p ->> 'address'), 300), ''),
          nullif(left(btrim(p ->> 'event_type'), 80), ''), v_date, v_time, v_guests, v_pkg,
          nullif(left(btrim(coalesce(p ->> 'request', '')), 2000), ''),
          nullif(left(btrim(coalesce(p ->> 'allergies', '')), 500), ''),
          p_source)
  returning id into v_lead;

  if nullif(btrim(coalesce(p ->> 'notes', '')), '') is not null then
    insert into public.shahi_lead_notes (lead_id, author_name, body)
    values (v_lead, p_source, left(btrim(p ->> 'notes'), 2000));
  end if;
  return v_lead;
end;
$$;
revoke execute on function public.shahi__intake(jsonb, text) from public, anon, authenticated;

-- website booking form (anonymous visitors); refuses floods
create or replace function public.shahi_submit_booking(p jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare v_phone text := public.shahi_phone(p ->> 'phone');
begin
  if v_phone is null then raise exception 'invalid phone'; end if;
  if length(btrim(coalesce(p ->> 'name', ''))) < 2 then raise exception 'name required'; end if;
  if exists (select 1 from public.shahi_leads where phone = v_phone and created_at > now() - interval '10 minutes') then
    return 'duplicate';
  end if;
  if (select count(*) from public.shahi_leads where source = 'website' and created_at > now() - interval '1 hour') >= 60 then
    raise exception 'busy';
  end if;
  perform public.shahi__intake(p, 'website');
  return 'ok';
end;
$$;
revoke execute on function public.shahi_submit_booking(jsonb) from public;
grant execute on function public.shahi_submit_booking(jsonb) to anon, authenticated;

-- n8n / WhatsApp bot intake: only the edge function (service role) may call it
create or replace function public.shahi_ingest_lead(p jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
begin
  return public.shahi__intake(
    jsonb_build_object('name', p ->> 'name', 'phone', p ->> 'phone', 'area', p ->> 'area',
                       'request', p ->> 'request', 'notes', p ->> 'notes'),
    coalesce(nullif(lower(p ->> 'source'), ''), 'whatsapp'));
end;
$$;
revoke execute on function public.shahi_ingest_lead(jsonb) from public, anon, authenticated;
grant execute on function public.shahi_ingest_lead(jsonb) to service_role;

-- kitchen: what to cook, for how many, when, and allergies — nothing about the customer or money
create or replace function public.shahi_kitchen(p_from date, p_to date)
returns table (booking_id uuid, event_at timestamptz, guests int, package_name text, menu jsonb,
               menu_notes text, allergies text, status text)
language sql stable security definer set search_path = '' as $$
  select b.id, b.event_at, b.guests, p.name_ar,
         coalesce((select jsonb_agg(jsonb_build_object('name', m.name_ar, 'note', pi.note) order by pi.sort, m.sort)
                   from public.shahi_package_items pi join public.shahi_menu_items m on m.id = pi.menu_item_id
                   where pi.package_id = b.package_id), '[]'::jsonb),
         b.menu_notes, b.allergies, b.status
  from public.shahi_bookings b left join public.shahi_packages p on p.id = b.package_id
  where public.shahi_has_role(array['admin','ops','chef'])
    and b.status <> 'cancelled'
    and b.event_at >= p_from::timestamptz and b.event_at < (p_to + 1)::timestamptz
  order by b.event_at;
$$;
revoke execute on function public.shahi_kitchen(date, date) from public, anon;
grant execute on function public.shahi_kitchen(date, date) to authenticated;

-- reports for admins
create or replace function public.shahi_report(p_from date, p_to date)
returns jsonb language sql stable security definer set search_path = '' as $$
  with l as (select * from public.shahi_leads where created_at >= p_from::timestamptz and created_at < (p_to + 1)::timestamptz),
       b as (select * from public.shahi_bookings where status <> 'cancelled' and event_at >= p_from::timestamptz and event_at < (p_to + 1)::timestamptz)
  select case when not public.shahi_has_role(array['admin']) then null else jsonb_build_object(
    'leads', (select count(*) from l),
    'booked', (select count(*) from l where status in ('booked','done')),
    'cancelled', (select count(*) from l where status = 'cancelled'),
    'by_status', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb) from (select status, count(*) n from l group by status) s),
    'by_source', (select coalesce(jsonb_object_agg(source, n), '{}'::jsonb) from (select source, count(*) n from l group by source) s),
    'by_area', (select coalesce(jsonb_agg(jsonb_build_object('area', area, 'n', n) order by n desc), '[]'::jsonb)
                from (select coalesce(area, '—') area, count(*) n from l group by 1) s),
    'bookings', (select count(*) from b),
    'booked_value', (select coalesce(sum(total_price), 0) from b),
    'collected', (select coalesce(sum(pay.amount), 0) from public.shahi_payments pay
                  where pay.paid_at between p_from and p_to),
    'by_month', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'value', v, 'count', c) order by m), '[]'::jsonb)
                 from (select to_char(event_at, 'YYYY-MM') m, coalesce(sum(total_price), 0) v, count(*) c from b group by 1) s),
    'by_package', (select coalesce(jsonb_agg(jsonb_build_object('package', coalesce(p.name_ar, '—'), 'n', n) order by n desc), '[]'::jsonb)
                   from (select package_id, count(*) n from b group by package_id) s
                   left join public.shahi_packages p on p.id = s.package_id)
  ) end;
$$;
revoke execute on function public.shahi_report(date, date) from public, anon;
grant execute on function public.shahi_report(date, date) to authenticated;
