-- Nile Dragon (نايل دراجون): Abdallah's China → Egypt import company, in the control-center app (/app).
-- Six tables, owner only (app_is_owner() from 104). Money in EGP is worked out by the database from the
-- amount and the rate, so the app never shows a number that was not entered: a missing rate gives NULL.
-- Seeded only with what Abdallah gave (8 Nov 2026). Run once by hand in the SQL editor. Safe to run again.

create table if not exists public.nd_suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  role text not null default 'بضاعة' check (role in ('شحن', 'بضاعة')),
  products text, wechat_id text, notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.nd_orders (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  supplier_id uuid references public.nd_suppliers(id) on delete set null,
  opened date not null default current_date,
  status text not null default 'مستني الأسعار'
    check (status in ('مستني الأسعار', 'اتطلبت', 'اتدفعت', 'في الشحن', 'وصلت', 'اتقفلت')),
  currency text check (currency in ('USD', 'CNY', 'EGP')),
  rate_to_egp numeric check (rate_to_egp is null or rate_to_egp > 0),
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.nd_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.nd_orders(id) on delete cascade,
  item text not null,
  ordered integer not null default 0 check (ordered >= 0),
  received integer not null default 0 check (received >= 0),
  unit_price numeric check (unit_price is null or unit_price >= 0),
  sent_to_supplier boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists nd_order_items_order_idx on public.nd_order_items (order_id);

create table if not exists public.nd_payments (
  id uuid primary key default gen_random_uuid(),
  paid_on date not null default current_date,
  direction text not null check (direction in ('دخل', 'خرج')),
  party text not null,
  order_id uuid references public.nd_orders(id) on delete set null,
  amount numeric not null check (amount >= 0),
  currency text not null default 'EGP' check (currency in ('USD', 'CNY', 'EGP')),
  rate_to_egp numeric check (rate_to_egp is null or rate_to_egp > 0),
  amount_egp numeric generated always as (amount * coalesce(rate_to_egp, case when currency = 'EGP' then 1 end)) stored,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.nd_shipments (
  id uuid primary key default gen_random_uuid(),
  shipment text not null,
  order_id uuid references public.nd_orders(id) on delete set null,
  carrier text, route text,
  weight_kg numeric check (weight_kg is null or weight_kg >= 0),
  price_per_kg numeric check (price_per_kg is null or price_per_kg >= 0),
  currency text not null default 'USD' check (currency in ('USD', 'CNY', 'EGP')),
  rate_to_egp numeric check (rate_to_egp is null or rate_to_egp > 0),
  freight numeric generated always as (weight_kg * price_per_kg) stored,
  customs_egp numeric check (customs_egp is null or customs_egp >= 0),
  other_egp numeric check (other_egp is null or other_egp >= 0),
  -- NULL when there is freight but no rate to turn it into pounds
  total_egp numeric generated always as (
    case when weight_kg is not null and price_per_kg is not null
              and coalesce(rate_to_egp, case when currency = 'EGP' then 1 end) is null then null
         else coalesce(weight_kg * price_per_kg * coalesce(rate_to_egp, case when currency = 'EGP' then 1 end), 0)
              + coalesce(customs_egp, 0) + coalesce(other_egp, 0) end) stored,
  status text not null default 'لسه' check (status in ('لسه', 'في الطريق', 'في الجمارك', 'وصلت')),
  created_at timestamptz not null default now()
);

create table if not exists public.nd_clients (
  id uuid primary key default gen_random_uuid(),
  client text not null,
  goods text,
  weight_kg numeric check (weight_kg is null or weight_kg >= 0),
  charge_egp numeric check (charge_egp is null or charge_egp >= 0),
  paid_egp numeric check (paid_egp is null or paid_egp >= 0),
  status text not null default 'لسه' check (status in ('لسه', 'في الطريق', 'وصلت', 'اتسلّمت')),
  created_at timestamptz not null default now()
);

-- owner only
do $$
declare t text;
begin
  foreach t in array array['nd_suppliers','nd_orders','nd_order_items','nd_payments','nd_shipments','nd_clients'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "owner only" on public.%I', t);
    execute format('create policy "owner only" on public.%I for all to authenticated using ((select public.app_is_owner())) with check ((select public.app_is_owner()))', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;

-- seed: only what Abdallah gave
insert into public.nd_suppliers (name, role, products, notes) values
  ('Aya 小雅', 'شحن', 'شحن من الصين لمصر', null),
  ('Heidi', 'بضاعة', 'مفاتيح سمارت', null),
  ('Shuoqi Feng', 'بضاعة', 'شاشات', null),
  ('Penny 酱油君', 'بضاعة', null, 'EXW · الإنتاج من 8 لـ 10 أيام · FedEx جوي من 5 لـ 8 أيام · مفيش بحري لمصر'),
  ('Mr Chen 曼浦科技', 'بضاعة', null, 'بيسعّر طلبية ND-001')
on conflict (name) do nothing;

insert into public.nd_orders (code, supplier_id, opened, status, note)
select 'ND-001', s.id, date '2026-11-01', 'مستني الأسعار', 'المفاتيح بس اللي اتبعتت لمستر تشن. باقي الأصناف لسه ما اتبعتتش للمورد.'
from public.nd_suppliers s where s.name = 'Mr Chen 曼浦科技'
on conflict (code) do nothing;

insert into public.nd_order_items (order_id, item, ordered, received, sent_to_supplier)
select o.id, v.item, v.ordered, 0, v.sent
from public.nd_orders o, (values
  ('مفتاح ستارة Tuya Zigbee أسود', 40, true),
  ('مفتاح 2 خط Tuya Zigbee أسود', 20, true),
  ('مفتاح 3 خط Tuya Zigbee أسود', 20, true),
  ('مفتاح 4 خط Tuya Zigbee أسود', 30, true),
  ('ريموت IR واي فاي', 21, false),
  ('ريموت IR Zigbee', 30, false),
  ('حساس وجود', 20, false),
  ('حساس غاز', 10, false),
  ('حساس تسريب مياه', 20, false),
  ('هاب لاسلكي', 5, false),
  ('محبس', 10, false)
) as v(item, ordered, sent)
where o.code = 'ND-001' and not exists (select 1 from public.nd_order_items i where i.order_id = o.id);
