-- jaguar-smart (Jaguar + Tuya Suez). Stock value at cost for the control-center app («رصيد المخزن» /
-- «رأس المال»): each stock item can point to a product of the same company and/or carry its own unit cost.
-- Value = quantity × coalesce(unit_cost, product.dealer_price). Items with neither show as «من غير سعر».
-- Same columns as supabase-aix/002 in the AIX project. Run once by hand in the SQL editor. Safe to run again.

alter table public.inventory_items add column if not exists product_id uuid references public.products(id) on delete set null;
alter table public.inventory_items add column if not exists unit_cost numeric;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'inventory_items_unit_cost_check') then
    alter table public.inventory_items add constraint inventory_items_unit_cost_check check (unit_cost is null or unit_cost >= 0);
  end if;
end $$;
create index if not exists inventory_items_product_id_idx on public.inventory_items (product_id);

-- quantity stays function-only (001); the two new columns are writable like name / min_qty
grant insert (product_id, unit_cost), update (product_id, unit_cost) on public.inventory_items to authenticated;

-- a stock item may only point to a product of its own company (004 keeps companies apart)
create or replace function public.inventory_product_same_company()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.product_id is not null and not exists (
    select 1 from public.products p where p.id = new.product_id and p.company = new.company) then
    raise exception 'not allowed';
  end if;
  return new;
end $$;
revoke execute on function public.inventory_product_same_company() from public, anon, authenticated;
drop trigger if exists inventory_product_same_company on public.inventory_items;
create trigger inventory_product_same_company before insert or update of product_id on public.inventory_items
  for each row execute function public.inventory_product_same_company();
