-- Jaguar Smart Materials (jaguarsmart.com/materials)
-- All store objects use the mat_ prefix so they never collide with the Tuya Suez team system
-- that lives in the same Supabase project.

-- ============ helpers ============

-- Egyptian mobile -> +20XXXXXXXXXX, or null when it is not a valid Egyptian mobile number
create or replace function public.mat_normalize_phone(p text)
returns text language sql immutable set search_path = '' as $$
  with d as (select regexp_replace(coalesce(p, ''), '\D', '', 'g') as n)
  select case
    when n ~ '^01[0125][0-9]{8}$'     then '+2' || n
    when n ~ '^201[0125][0-9]{8}$'    then '+' || n
    when n ~ '^00201[0125][0-9]{8}$'  then '+' || substr(n, 3)
    when n ~ '^1[0125][0-9]{8}$'      then '+20' || n
    else null end
  from d;
$$;

create or replace function public.mat_token()
returns text language sql volatile set search_path = '' as $$
  select encode(extensions.gen_random_bytes(24), 'hex');
$$;

-- ============ people & roles ============

create table public.mat_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('customer','staff','admin')),
  full_name text,
  phone text,                 -- normalized, unverified until phone OTP (phase 2)
  phone_verified boolean not null default false,
  created_at timestamptz not null default now()
);

-- emails that get a staff/admin role the first time they sign in
create table public.mat_staff_invites (
  email text primary key,
  role text not null check (role in ('staff','admin')),
  created_at timestamptz not null default now()
);

create or replace function public.mat_role()
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((select role from public.mat_profiles where user_id = auth.uid()), 'guest');
$$;

create or replace function public.mat_is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.mat_role() in ('staff','admin');
$$;

create or replace function public.mat_is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.mat_role() = 'admin';
$$;

-- customers are keyed by normalized phone (guests and accounts alike)
create table public.mat_customers (
  id uuid primary key default gen_random_uuid(),
  phone text not null unique check (phone ~ '^\+201[0125][0-9]{8}$'),
  name text,
  email text,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index mat_customers_user_idx on public.mat_customers (user_id);

-- ============ catalog ============

create table public.mat_areas (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  governorate text not null,
  name text not null,
  name_ar text,
  delivery_fee numeric not null default 0 check (delivery_fee >= 0),
  delivery_days_min int not null default 1,
  delivery_days_max int not null default 3,
  sort int not null default 0,
  active boolean not null default true
);

create table public.mat_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  name_ar text,
  icon text,
  sort int not null default 0,
  active boolean not null default true
);

create table public.mat_brands (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  logo_url text,
  sort int not null default 0,
  active boolean not null default true
);

create table public.mat_products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  sku text unique,
  name text not null,
  name_ar text,
  category_id uuid not null references public.mat_categories(id),
  brand_id uuid references public.mat_brands(id),
  unit text not null check (unit in ('ton','bag','m2','m3','piece','meter','roll','liter','kg')),
  base_price numeric not null check (base_price >= 0),
  min_order_qty numeric not null default 1 check (min_order_qty > 0),
  qty_step numeric not null default 1 check (qty_step > 0),
  description text,
  specs jsonb not null default '{}'::jsonb,
  images text[] not null default '{}',
  is_featured boolean not null default false,
  is_best_seller boolean not null default false,
  popularity int not null default 0,
  active boolean not null default true,
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index mat_products_category_idx on public.mat_products (category_id) where active;
create index mat_products_brand_idx on public.mat_products (brand_id);

-- per-area price adjustment, stock and delivery time
create table public.mat_product_area_prices (
  product_id uuid not null references public.mat_products(id) on delete cascade,
  area_id uuid not null references public.mat_areas(id) on delete cascade,
  price_adjustment numeric not null default 0,
  price_override numeric check (price_override >= 0),
  stock_status text not null default 'in_stock' check (stock_status in ('in_stock','low_stock','out_of_stock','on_order')),
  delivery_days_min int,
  delivery_days_max int,
  updated_at timestamptz not null default now(),
  primary key (product_id, area_id)
);
create index mat_pap_area_idx on public.mat_product_area_prices (area_id);

-- price of a product in an area (null area = base price)
create or replace function public.mat_price(p_product uuid, p_area uuid)
returns numeric language sql stable set search_path = '' as $$
  select coalesce(ap.price_override, p.base_price + coalesce(ap.price_adjustment, 0))
  from public.mat_products p
  left join public.mat_product_area_prices ap on ap.product_id = p.id and ap.area_id = p_area
  where p.id = p_product;
$$;

-- ============ daily prices (ticker + /prices) ============

create table public.mat_daily_price_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('steel','cement')),
  manufacturer text not null,
  label text not null,             -- e.g. 'Rebar 16 mm', 'Grey cement (CEM I 42.5)'
  size_mm int,
  unit text not null default 'ton',
  product_id uuid references public.mat_products(id) on delete set null,
  show_in_ticker boolean not null default false,
  sort int not null default 0,
  active boolean not null default true,
  is_sample boolean not null default false
);

create table public.mat_price_history (
  id bigint generated always as identity primary key,
  item_id uuid not null references public.mat_daily_price_items(id) on delete cascade,
  area_id uuid not null references public.mat_areas(id) on delete cascade,
  price numeric not null check (price > 0),
  recorded_on date not null default current_date,
  recorded_at timestamptz not null default now(),
  recorded_by uuid references auth.users(id) on delete set null,
  unique (item_id, area_id, recorded_on)
);
create index mat_price_history_lookup on public.mat_price_history (item_id, area_id, recorded_on desc);
create index mat_price_history_area_idx on public.mat_price_history (area_id);

-- latest price, previous day's price and % change per item and area
create or replace view public.mat_current_prices with (security_invoker = true) as
select distinct on (h.item_id, h.area_id)
  h.item_id, h.area_id, i.kind, i.manufacturer, i.label, i.size_mm, i.unit, i.show_in_ticker, i.sort, i.is_sample,
  h.price, h.recorded_on, h.recorded_at,
  prev.price as prev_price,
  case when prev.price is null or prev.price = 0 then null
       else round((h.price - prev.price) / prev.price * 100, 2) end as change_pct
from public.mat_price_history h
join public.mat_daily_price_items i on i.id = h.item_id and i.active
left join lateral (
  select p.price from public.mat_price_history p
  where p.item_id = h.item_id and p.area_id = h.area_id and p.recorded_on < h.recorded_on
  order by p.recorded_on desc limit 1
) prev on true
order by h.item_id, h.area_id, h.recorded_on desc;

-- ============ marketing ============

create table public.mat_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  image_url text,
  link_url text,
  cta_label text,
  sort int not null default 0,
  active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  is_sample boolean not null default false
);

-- ============ carts (signed-in users; guests keep the cart in a cookie) ============

create table public.mat_carts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,    -- [{product_id, qty}]
  updated_at timestamptz not null default now()
);

-- ============ orders ============

create sequence public.mat_order_seq start 10001;
create table public.mat_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('JS-' || nextval('public.mat_order_seq')::text),
  access_token text not null unique default public.mat_token(),
  customer_id uuid not null references public.mat_customers(id),
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  phone text not null,
  address text not null,
  area_id uuid not null references public.mat_areas(id),
  area_name text not null,
  delivery_date date,
  payment_method text not null check (payment_method in ('cod','bank_transfer')),
  status text not null default 'new' check (status in ('new','confirmed','out_for_delivery','delivered','cancelled')),
  subtotal numeric not null default 0,
  delivery_fee numeric not null default 0,
  total numeric not null default 0,
  notes text,
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index mat_orders_customer_idx on public.mat_orders (customer_id, created_at desc);
create index mat_orders_user_idx on public.mat_orders (user_id);
create index mat_orders_status_idx on public.mat_orders (status, created_at desc);
create index mat_orders_area_idx on public.mat_orders (area_id);

create table public.mat_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.mat_orders(id) on delete cascade,
  product_id uuid references public.mat_products(id) on delete set null,
  name text not null,
  unit text not null,
  qty numeric not null check (qty > 0),
  unit_price numeric not null check (unit_price >= 0),
  line_total numeric not null
);
create index mat_order_items_order_idx on public.mat_order_items (order_id);
create index mat_order_items_product_idx on public.mat_order_items (product_id);

-- ============ quotes (RFQ) ============

create sequence public.mat_quote_seq start 1001;
create table public.mat_quotes (
  id uuid primary key default gen_random_uuid(),
  quote_number text not null unique default ('RFQ-' || nextval('public.mat_quote_seq')::text),
  access_token text not null unique default public.mat_token(),
  customer_id uuid not null references public.mat_customers(id),
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  phone text not null,
  area_id uuid references public.mat_areas(id),
  area_name text,
  project_type text,
  needed_by date,
  materials_text text,
  notes text,
  status text not null default 'new' check (status in ('new','priced','sent','won','lost')),
  quoted_amount numeric,
  quote_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index mat_quotes_customer_idx on public.mat_quotes (customer_id, created_at desc);
create index mat_quotes_user_idx on public.mat_quotes (user_id);
create index mat_quotes_status_idx on public.mat_quotes (status, created_at desc);
create index mat_quotes_area_idx on public.mat_quotes (area_id);

create table public.mat_quote_files (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.mat_quotes(id) on delete cascade,
  kind text not null check (kind in ('boq','photo','admin_quote')),
  path text not null,
  file_name text,
  mime text,
  size_bytes bigint,
  created_at timestamptz not null default now()
);
create index mat_quote_files_quote_idx on public.mat_quote_files (quote_id);

-- ============ reviews (only from delivered orders) ============

create table public.mat_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.mat_products(id) on delete cascade,
  order_id uuid not null references public.mat_orders(id) on delete cascade,
  customer_id uuid references public.mat_customers(id) on delete set null,
  rating int not null check (rating between 1 and 5),
  body text,
  author_name text not null,
  approved boolean not null default true,
  created_at timestamptz not null default now(),
  unique (order_id, product_id)
);
create index mat_reviews_product_idx on public.mat_reviews (product_id, created_at desc) where approved;
create index mat_reviews_customer_idx on public.mat_reviews (customer_id);
