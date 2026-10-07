-- Leads from the jaguarsmart.com "Get a quote" form go straight into the Jaguar CRM.
-- Visitors are not signed in, so they call this function instead of writing to the table;
-- it only ever creates a 'new' Jaguar lead with source 'website', and refuses floods.
create or replace function public.submit_web_lead(
  p_name text, p_phone text, p_client_role text default null, p_location text default null,
  p_stage text default null, p_property text default null, p_area_m2 text default null, p_details text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_name text := left(btrim(coalesce(p_name, '')), 120);
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
  v_notes text;
begin
  if length(v_name) < 2 then raise exception 'name required'; end if;
  if length(regexp_replace(v_phone, '\D', '', 'g')) not between 10 and 15 then raise exception 'invalid phone'; end if;

  -- same number twice within 30 minutes: keep the first request
  if exists (select 1 from public.leads where company = 'jaguar' and phone = v_phone
             and created_at > now() - interval '30 minutes') then
    return 'duplicate';
  end if;
  if (select count(*) from public.leads where company = 'jaguar' and source = 'website'
      and created_at > now() - interval '1 hour') >= 60 then
    raise exception 'busy';
  end if;

  v_notes := concat_ws(E'\n',
    'طلب عرض سعر من الموقع',
    'العميل: '   || nullif(left(btrim(p_client_role), 80), ''),
    'المرحلة: '  || nullif(left(btrim(p_stage), 80), ''),
    'نوع المكان: ' || nullif(left(btrim(p_property), 80), ''),
    'المساحة: '  || nullif(left(btrim(p_area_m2), 40), '') || ' م²',
    'تفاصيل: '   || nullif(left(btrim(p_details), 1500), ''));

  insert into public.leads (company, name, phone, area, source, client_type, status, notes)
  values ('jaguar', v_name, v_phone, nullif(left(btrim(p_location), 80), ''), 'website',
          case when p_client_role ilike '%developer%' or p_client_role ilike '%contractor%' then 'dealer' else 'end_customer' end,
          'new', v_notes);
  return 'ok';
end;
$$;
revoke execute on function public.submit_web_lead(text,text,text,text,text,text,text,text) from public;
grant execute on function public.submit_web_lead(text,text,text,text,text,text,text,text) to anon, authenticated;
