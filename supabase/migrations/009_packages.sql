-- Smart home packages: built in the CRM from the product list, shown on the company website.
-- The website only ever sees what get_site_packages returns (names, a summary per section and,
-- when allowed, the package total) — never the per-product prices.

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  company text not null default public.my_company(),
  name_ar text not null,
  name_en text,
  subtitle_ar text,                 -- e.g. "لحد ~130 م²"
  subtitle_en text,                 -- e.g. "Up to ~130 m²"
  install_pct numeric not null default 10 check (install_pct between 0 and 100),
  show_on_site boolean not null default false,
  show_price boolean not null default true,
  highlight boolean not null default false,
  sort int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index packages_company_idx on public.packages (company, sort);

create table public.package_items (
  id uuid primary key default gen_random_uuid(),
  company text not null default public.my_company(),
  package_id uuid not null references public.packages(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  qty numeric not null default 1 check (qty > 0),
  unique (package_id, product_id)
);
create index package_items_product_idx on public.package_items (product_id);
create index package_items_company_idx on public.package_items (company);

alter table public.packages enable row level security;
alter table public.package_items enable row level security;

create policy "team read packages" on public.packages for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "admin write packages" on public.packages for all to authenticated
  using ((select public.has_role(array['admin']))) with check ((select public.has_role(array['admin'])));
create policy "company isolation" on public.packages as restrictive for all to authenticated
  using (company = (select public.my_company())) with check (company = (select public.my_company()));

create policy "team read package_items" on public.package_items for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "admin write package_items" on public.package_items for all to authenticated
  using ((select public.has_role(array['admin']))) with check ((select public.has_role(array['admin'])));
create policy "company isolation" on public.package_items as restrictive for all to authenticated
  using (company = (select public.my_company())) with check (company = (select public.my_company()));

-- a package line may only point at a package and a product of the same company
create or replace function public.package_item_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.packages where id = new.package_id and company = new.company)
     or not exists (select 1 from public.products where id = new.product_id and company = new.company) then
    raise exception 'not allowed';
  end if;
  return new;
end;
$$;
revoke execute on function public.package_item_guard() from public, anon, authenticated;
create trigger package_items_guard before insert or update on public.package_items
  for each row execute function public.package_item_guard();

create or replace function public.packages_touch()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); new.company := old.company; return new; end;
$$;
create trigger packages_touch before update on public.packages for each row execute function public.packages_touch();

-- what the public website shows
create or replace function public.get_site_packages(p_company text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(x order by x->>'sort_key'), '[]'::jsonb) from (
    select jsonb_build_object(
      'sort_key', lpad(pk.sort::text, 6, '0') || pk.name_ar,
      'id', pk.id, 'name_ar', pk.name_ar, 'name_en', coalesce(pk.name_en, pk.name_ar),
      'subtitle_ar', pk.subtitle_ar, 'subtitle_en', pk.subtitle_en, 'highlight', pk.highlight,
      'install_pct', pk.install_pct,
      'price', case when pk.show_price then
          round(sum(pi.qty * coalesce(pr.end_user_price, 0)) * (1 + pk.install_pct / 100)) end,
      'has_unpriced', bool_or(pr.end_user_price is null),
      'sections', (select jsonb_agg(jsonb_build_object('category', c.category, 'qty', c.qty) order by c.qty desc)
                   from (select pr2.category, sum(pi2.qty) qty from public.package_items pi2
                         join public.products pr2 on pr2.id = pi2.product_id
                         where pi2.package_id = pk.id group by pr2.category) c),
      'highlights', (select jsonb_agg(jsonb_build_object('name_en', h.name, 'name_ar', h.name_ar, 'qty', h.qty))
                     from (select pr3.name, pr3.name_ar, pi3.qty from public.package_items pi3
                           join public.products pr3 on pr3.id = pi3.product_id
                           where pi3.package_id = pk.id
                             and pr3.category in ('Screens & Hubs','Locks','Intercom','Cameras','Curtains')
                           order by coalesce(pr3.end_user_price, 0) desc limit 4) h)
    ) x
    from public.packages pk
    join public.package_items pi on pi.package_id = pk.id
    join public.products pr on pr.id = pi.product_id
    where pk.company = p_company and pk.show_on_site
    group by pk.id
  ) t;
$$;
revoke execute on function public.get_site_packages(text) from public;
grant execute on function public.get_site_packages(text) to anon, authenticated;
