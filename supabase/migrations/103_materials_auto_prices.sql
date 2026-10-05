-- Daily automatic prices (used by the mat-daily-prices edge function): run log + writer that
-- keeps the highest price of the day. Not scheduled yet: waiting for approval of the sources/rule.
create table public.mat_price_runs (
  id bigint generated always as identity primary key,
  ran_at timestamptz not null default now(),
  run_date date not null,
  status text not null check (status in ('applied','skipped','error')),
  prices jsonb not null default '{}'::jsonb,
  sources jsonb not null default '[]'::jsonb,
  message text
);
create index mat_price_runs_ran_idx on public.mat_price_runs (ran_at desc);
alter table public.mat_price_runs enable row level security;
create policy "staff read price runs" on public.mat_price_runs for select to authenticated using ((select public.mat_is_staff()));

-- p = {"date":"2026-10-05","steel":{"Ezz Steel":40850,...},"cement":{"Suez Cement":3900,...}}
create or replace function public.mat_apply_scraped_prices(p jsonb)
returns int language plpgsql security definer set search_path = '' as $$
declare n int; d date := coalesce((p ->> 'date')::date, (now() at time zone 'Africa/Cairo')::date);
begin
  with chosen as (
    select i.id as item_id, (coalesce(p -> 'steel', '{}'::jsonb) || coalesce(p -> 'cement', '{}'::jsonb) ->> i.manufacturer)::numeric as price
    from public.mat_daily_price_items i where i.active
  ), ins as (
    insert into public.mat_price_history (item_id, area_id, price, recorded_on)
    select c.item_id, a.id, c.price, d from chosen c cross join public.mat_areas a
    where c.price is not null and c.price > 0
    on conflict (item_id, area_id, recorded_on)
      do update set price = greatest(public.mat_price_history.price, excluded.price), recorded_at = now()
    returning item_id
  ) select count(*) into n from ins;

  update public.mat_daily_price_items i set is_sample = false
  where i.is_sample and (coalesce(p -> 'steel', '{}'::jsonb) || coalesce(p -> 'cement', '{}'::jsonb)) ? i.manufacturer;

  update public.mat_products pr set base_price = h.price, updated_at = now()
  from public.mat_daily_price_items i
  join public.mat_price_history h on h.item_id = i.id and h.recorded_on = d
  join public.mat_areas a on a.id = h.area_id and a.slug = 'cairo'
  where i.product_id = pr.id and pr.base_price <> h.price;
  return n;
end;
$$;
revoke execute on function public.mat_apply_scraped_prices(jsonb) from public, anon, authenticated;
grant execute on function public.mat_apply_scraped_prices(jsonb) to service_role;
