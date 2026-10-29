-- SHAHI security: row level security per role, activity log, public booking form, webhook intake.
-- Roles: admin (partners) · sales · ops · chef. The chef never reads customer, address or money
-- columns: the kitchen view goes through shahi_kitchen(), which returns only what the kitchen needs.

alter table public.shahi_staff enable row level security;
alter table public.shahi_menu_items enable row level security;
alter table public.shahi_packages enable row level security;
alter table public.shahi_package_items enable row level security;
alter table public.shahi_meal_plans enable row level security;
alter table public.shahi_settings enable row level security;
alter table public.shahi_customers enable row level security;
alter table public.shahi_leads enable row level security;
alter table public.shahi_lead_notes enable row level security;
alter table public.shahi_bookings enable row level security;
alter table public.shahi_payments enable row level security;
alter table public.shahi_activity_log enable row level security;

-- team
create policy "staff read team" on public.shahi_staff for select to authenticated
  using (user_id = (select auth.uid()) or (select public.shahi_has_role(array['admin','sales','ops','chef'])));
create policy "admin manage team" on public.shahi_staff for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));

-- catalogue: the public site reads active rows, the team reads all, admins edit
create policy "public read menu" on public.shahi_menu_items for select to anon, authenticated
  using (active or (select public.shahi_has_role(array['admin','sales','ops','chef'])));
create policy "admin write menu" on public.shahi_menu_items for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));
create policy "public read packages" on public.shahi_packages for select to anon, authenticated
  using (active or (select public.shahi_has_role(array['admin','sales','ops','chef'])));
create policy "admin write packages" on public.shahi_packages for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));
create policy "public read package items" on public.shahi_package_items for select to anon, authenticated using (true);
create policy "admin write package items" on public.shahi_package_items for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));
create policy "public read meal plans" on public.shahi_meal_plans for select to anon, authenticated
  using (active or (select public.shahi_has_role(array['admin','sales','ops','chef'])));
create policy "admin write meal plans" on public.shahi_meal_plans for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));
create policy "public read public settings" on public.shahi_settings for select to anon, authenticated
  using (key like 'public.%' or (select public.shahi_has_role(array['admin'])));
create policy "admin write settings" on public.shahi_settings for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));

-- customers
create policy "team read customers" on public.shahi_customers for select to authenticated
  using ((select public.shahi_has_role(array['admin','sales','ops'])));
create policy "sales add customers" on public.shahi_customers for insert to authenticated
  with check ((select public.shahi_has_role(array['admin','sales'])));
create policy "sales edit customers" on public.shahi_customers for update to authenticated
  using ((select public.shahi_has_role(array['admin','sales']))) with check ((select public.shahi_has_role(array['admin','sales'])));
create policy "admin delete customers" on public.shahi_customers for delete to authenticated
  using ((select public.shahi_has_role(array['admin'])));

-- leads & notes
create policy "sales read leads" on public.shahi_leads for select to authenticated
  using ((select public.shahi_has_role(array['admin','sales'])));
create policy "sales add leads" on public.shahi_leads for insert to authenticated
  with check ((select public.shahi_has_role(array['admin','sales'])));
create policy "sales edit leads" on public.shahi_leads for update to authenticated
  using ((select public.shahi_has_role(array['admin','sales']))) with check ((select public.shahi_has_role(array['admin','sales'])));
create policy "admin delete leads" on public.shahi_leads for delete to authenticated
  using ((select public.shahi_has_role(array['admin'])));
create policy "sales read notes" on public.shahi_lead_notes for select to authenticated
  using ((select public.shahi_has_role(array['admin','sales'])));
create policy "sales add notes" on public.shahi_lead_notes for insert to authenticated
  with check ((select public.shahi_has_role(array['admin','sales'])) and author = (select auth.uid()));
create policy "admin delete notes" on public.shahi_lead_notes for delete to authenticated
  using ((select public.shahi_has_role(array['admin'])));

-- bookings & payments (operations sees and updates bookings, e.g. team and done)
create policy "team read bookings" on public.shahi_bookings for select to authenticated
  using ((select public.shahi_has_role(array['admin','sales','ops'])));
create policy "sales add bookings" on public.shahi_bookings for insert to authenticated
  with check ((select public.shahi_has_role(array['admin','sales'])));
create policy "team edit bookings" on public.shahi_bookings for update to authenticated
  using ((select public.shahi_has_role(array['admin','sales','ops']))) with check ((select public.shahi_has_role(array['admin','sales','ops'])));
create policy "admin delete bookings" on public.shahi_bookings for delete to authenticated
  using ((select public.shahi_has_role(array['admin'])));
create policy "team read payments" on public.shahi_payments for select to authenticated
  using ((select public.shahi_has_role(array['admin','sales','ops'])));
create policy "sales add payments" on public.shahi_payments for insert to authenticated
  with check ((select public.shahi_has_role(array['admin','sales'])));
create policy "admin edit payments" on public.shahi_payments for update to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));
create policy "admin delete payments" on public.shahi_payments for delete to authenticated
  using ((select public.shahi_has_role(array['admin'])));

-- activity log: written by triggers only, read by admins
create policy "admin read activity" on public.shahi_activity_log for select to authenticated
  using ((select public.shahi_has_role(array['admin'])));

-- ============ triggers ============
create or replace function public.shahi_touch()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end;
$$;
create trigger shahi_leads_touch before update on public.shahi_leads for each row execute function public.shahi_touch();
create trigger shahi_bookings_touch before update on public.shahi_bookings for each row execute function public.shahi_touch();

-- who did what and when; for updates only the changed fields are kept
create or replace function public.shahi_log()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  rec jsonb := to_jsonb(coalesce(new, old));
  d jsonb;
begin
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(n.key, n.value) into d
    from jsonb_each(to_jsonb(new)) n
    where n.key not in ('updated_at') and n.value is distinct from to_jsonb(old) -> n.key;
    if d is null then return new; end if;
  elsif tg_op = 'DELETE' then
    d := rec;
  else
    d := rec - 'created_at' - 'updated_at';
  end if;
  insert into public.shahi_activity_log (actor, actor_email, action, entity, entity_id, details)
  values (auth.uid(), auth.jwt() ->> 'email', lower(tg_op), tg_table_name,
          coalesce(rec ->> 'id', rec ->> 'user_id', rec ->> 'key', rec ->> 'package_id'), d);
  return coalesce(new, old);
end;
$$;
revoke execute on function public.shahi_log() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['shahi_staff','shahi_menu_items','shahi_packages','shahi_package_items','shahi_meal_plans',
                           'shahi_settings','shahi_customers','shahi_leads','shahi_lead_notes','shahi_bookings','shahi_payments'] loop
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.shahi_log()', t || '_log', t);
  end loop;
end $$;

-- the public read policies evaluate shahi_has_role for visitors too; for them it simply returns false
grant execute on function public.shahi_has_role(text[]) to anon;
grant execute on function public.shahi_role() to anon;
