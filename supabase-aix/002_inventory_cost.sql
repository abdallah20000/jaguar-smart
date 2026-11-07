-- AIX Supabase project (xenrnhgxwhujyvtpwmsk), NOT jaguar-smart.
-- Stock value at cost for the control-center app («رصيد المخزن» / «رأس المال»): each stock item can point
-- to a product and/or carry its own unit cost. Value = quantity × coalesce(unit_cost, product.dealer_price).
-- Items with neither are shown as «من غير سعر». Run once by hand in the AIX SQL editor. Safe to run again.

alter table public.inventory_items add column if not exists product_id uuid references public.products(id) on delete set null;
alter table public.inventory_items add column if not exists unit_cost numeric;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'inventory_items_unit_cost_check') then
    alter table public.inventory_items add constraint inventory_items_unit_cost_check check (unit_cost is null or unit_cost >= 0);
  end if;
end $$;
create index if not exists inventory_items_product_id_idx on public.inventory_items (product_id);

-- if the inventory page writes through column grants (as in the CRM template), allow the two new columns
grant insert (product_id, unit_cost), update (product_id, unit_cost) on public.inventory_items to authenticated;
