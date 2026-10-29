-- SHAHI (شاهي): catering brand — public site + team dashboard.
-- All objects use the shahi_ prefix and are fully separate from the Jaguar / Tuya tables.

-- ============ team & roles ============
create table public.shahi_staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text not null,
  role text not null check (role in ('admin','sales','ops','chef')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- role of the signed-in user, or null when not an active Shahi team member
create or replace function public.shahi_role()
returns text language sql stable security definer set search_path = '' as $$
  select role from public.shahi_staff where user_id = auth.uid() and active;
$$;
create or replace function public.shahi_has_role(roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.shahi_role() = any(roles), false);
$$;
revoke execute on function public.shahi_role() from public, anon;
revoke execute on function public.shahi_has_role(text[]) from public, anon;
grant execute on function public.shahi_role() to authenticated;
grant execute on function public.shahi_has_role(text[]) to authenticated;

-- ============ catalogue (shown on the public site) ============
create table public.shahi_menu_items (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  description_ar text,
  description_en text,
  category text not null default 'gathering' check (category in ('gathering','a_la_carte','dessert','drink','meal_prep')),
  image_url text,
  active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

create table public.shahi_packages (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  guests int not null check (guests > 0),
  price numeric check (price >= 0),          -- null = not set yet (site shows "تواصل معانا")
  old_price numeric check (old_price >= 0),  -- optional "before discount"
  description_ar text,
  description_en text,
  highlight boolean not null default false,
  active boolean not null default true,
  sort int not null default 0,
  created_at timestamptz not null default now()
);

create table public.shahi_package_items (
  package_id uuid not null references public.shahi_packages(id) on delete cascade,
  menu_item_id uuid not null references public.shahi_menu_items(id) on delete cascade,
  note text,                                 -- e.g. quantity per guest
  sort int not null default 0,
  primary key (package_id, menu_item_id)
);
create index shahi_package_items_item_idx on public.shahi_package_items (menu_item_id);

create table public.shahi_meal_plans (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  period text not null check (period in ('weekly','monthly')),
  meals_per_day int check (meals_per_day > 0),
  price numeric check (price >= 0),          -- null = not set yet
  description_ar text,
  description_en text,
  active boolean not null default true,
  sort int not null default 0
);

-- key/value settings; only keys starting with "public." are readable by the website
create table public.shahi_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

-- ============ customers, leads, bookings, payments ============
create table public.shahi_customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null unique,
  email text,
  area text,
  address text,
  notes text,
  created_at timestamptz not null default now()
);

create table public.shahi_leads (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.shahi_customers(id) on delete set null,
  name text not null,
  phone text not null,
  area text,
  address text,
  event_type text,
  event_date date,
  event_time time,
  guests int check (guests > 0),
  package_id uuid references public.shahi_packages(id) on delete set null,
  request text,                 -- what the customer asked for
  allergies text,
  source text not null default 'website' check (source in ('website','whatsapp','ad','facebook','instagram','tiktok','phone','other')),
  status text not null default 'new' check (status in ('new','contacted','menu_sent','booked','done','cancelled')),
  assigned_to uuid references public.shahi_staff(user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index shahi_leads_status_idx on public.shahi_leads (status, created_at desc);
create index shahi_leads_customer_idx on public.shahi_leads (customer_id);
create index shahi_leads_package_idx on public.shahi_leads (package_id);
create index shahi_leads_assigned_idx on public.shahi_leads (assigned_to);

create table public.shahi_lead_notes (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.shahi_leads(id) on delete cascade,
  author uuid references public.shahi_staff(user_id) on delete set null,
  author_name text,
  body text not null,
  created_at timestamptz not null default now()
);
create index shahi_lead_notes_lead_idx on public.shahi_lead_notes (lead_id, created_at);

create table public.shahi_bookings (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references public.shahi_leads(id) on delete set null,
  customer_id uuid references public.shahi_customers(id) on delete set null,
  package_id uuid references public.shahi_packages(id) on delete set null,
  guests int not null check (guests > 0),
  event_at timestamptz not null,
  area text,
  address text,
  location_url text,
  total_price numeric check (total_price >= 0),
  menu_notes text,              -- what the kitchen must prepare beyond the package
  allergies text,
  team_notes text,
  team uuid[] not null default '{}',   -- staff assigned to the event
  status text not null default 'confirmed' check (status in ('confirmed','done','cancelled')),
  created_by uuid references public.shahi_staff(user_id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index shahi_bookings_event_idx on public.shahi_bookings (event_at);
create index shahi_bookings_lead_idx on public.shahi_bookings (lead_id);
create index shahi_bookings_customer_idx on public.shahi_bookings (customer_id);
create index shahi_bookings_package_idx on public.shahi_bookings (package_id);
create index shahi_bookings_created_by_idx on public.shahi_bookings (created_by);

create table public.shahi_payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.shahi_bookings(id) on delete cascade,
  kind text not null check (kind in ('deposit','balance','other')),
  amount numeric not null check (amount > 0),
  method text,
  note text,
  paid_at date not null default current_date,
  recorded_by uuid references public.shahi_staff(user_id) on delete set null,
  created_at timestamptz not null default now()
);
create index shahi_payments_booking_idx on public.shahi_payments (booking_id);
create index shahi_payments_recorded_by_idx on public.shahi_payments (recorded_by);

create table public.shahi_activity_log (
  id bigint generated always as identity primary key,
  actor uuid,
  actor_email text,
  action text not null,         -- insert / update / delete / login …
  entity text not null,         -- table name
  entity_id text,
  details jsonb,
  at timestamptz not null default now()
);
create index shahi_activity_at_idx on public.shahi_activity_log (at desc);

create index shahi_lead_notes_author_idx on public.shahi_lead_notes (author);
