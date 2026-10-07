-- Team system shared by two companies (Tuya Suez and Jaguar Smart Construction).
-- Every row carries its company; a RESTRICTIVE policy on each table means a user only ever
-- sees and writes rows of their own company, on top of the existing role policies.
-- Existing rows (all Tuya Suez) are backfilled with 'tuya-suez'.

alter table public.team_members add column if not exists company text not null default 'tuya-suez'
  check (company in ('tuya-suez', 'jaguar'));

create or replace function public.my_company()
returns text language sql stable security definer set search_path = '' as $$
  select company from public.team_members
  where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''));
$$;
revoke execute on function public.my_company() from public, anon;
grant execute on function public.my_company() to authenticated;

do $$
declare t text;
begin
  foreach t in array array['leads','follow_ups','products','quotations','quotation_items','inventory_items',
                           'inventory_moves','installations','installation_items','installation_photos'] loop
    execute format('alter table public.%I add column if not exists company text', t);
    execute format('update public.%I set company = ''tuya-suez'' where company is null', t);
    execute format('alter table public.%I alter column company set default public.my_company()', t);
    execute format('alter table public.%I alter column company set not null', t);
    execute format('create index if not exists %I on public.%I (company)', t || '_company_idx', t);
    execute format('create policy "company isolation" on public.%I as restrictive for all to authenticated
                    using (company = (select public.my_company())) with check (company = (select public.my_company()))', t);
  end loop;
end $$;

-- quotation numbers: Q-1001… for Tuya Suez, JS-Q-1001… for Jaguar (one shared counter)
alter table public.quotations alter column quote_number
  set default (case public.my_company() when 'jaguar' then 'JS-Q-' else 'Q-' end || nextval('public.quote_number_seq')::text);

-- the security-definer helpers (replace_quotation_items, inventory_adjust, install_*) bypass RLS,
-- so child rows they touch must belong to the caller's company. Server jobs (no signed-in user) pass.
create or replace function public.same_company_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare me text := public.my_company(); parent text; r record;
begin
  if me is null then return coalesce(new, old); end if;
  if tg_op = 'DELETE' then r := old; else r := new; end if;
  if tg_table_name = 'quotation_items' then
    select company into parent from public.quotations where id = r.quotation_id;
  elsif tg_table_name = 'inventory_moves' then
    select company into parent from public.inventory_items where id = r.item_id;
  elsif tg_table_name = 'installation_items' then
    select company into parent from public.installations where id = r.installation_id;
    if parent = me then select company into parent from public.inventory_items where id = r.item_id; end if;
  end if;
  -- removing lines of a parent that is itself being removed (cascade): the parent's own delete already passed RLS
  if tg_op = 'DELETE' and parent is null and r.company = me then return old; end if;
  if parent is distinct from me then raise exception 'not allowed'; end if;
  return coalesce(new, old);
end;
$$;
revoke execute on function public.same_company_guard() from public, anon, authenticated;

create trigger quotation_items_company_guard before insert or update or delete on public.quotation_items
  for each row execute function public.same_company_guard();
create trigger inventory_moves_company_guard before insert on public.inventory_moves
  for each row execute function public.same_company_guard();
create trigger installation_items_company_guard before insert or delete on public.installation_items
  for each row execute function public.same_company_guard();

-- inventory_adjust and request_quote_deletion update rows directly: refuse other companies' rows
create or replace function public.row_company_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare me text := public.my_company();
begin
  if me is not null and old.company is distinct from me then raise exception 'not allowed'; end if;
  new.company := old.company;  -- company never changes
  return new;
end;
$$;
revoke execute on function public.row_company_guard() from public, anon, authenticated;
create trigger inventory_items_company_guard before update on public.inventory_items
  for each row execute function public.row_company_guard();
create trigger quotations_company_guard before update on public.quotations
  for each row execute function public.row_company_guard();
