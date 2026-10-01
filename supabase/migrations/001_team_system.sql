-- Jaguar Smart Construction: team system schema, roles and RLS

-- ===== Team + roles =====
create table public.team_members (
  email text primary key,
  role text not null default 'crm' check (role in ('admin','crm','inventory','installs')),
  display_name text,
  added_at timestamptz not null default now()
);
alter table public.team_members enable row level security;
-- no policies: clients never read team_members directly

create or replace function public.my_role()
returns text language sql stable security definer set search_path = '' as $$
  select role from public.team_members
  where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''));
$$;

create or replace function public.has_role(allowed text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(public.my_role() = any(allowed), false);
$$;

-- ===== CRM =====
create table public.leads (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  phone text not null,
  area text,
  source text,
  client_type text not null default 'end_customer' check (client_type in ('end_customer','dealer')),
  status text not null default 'new' check (status in ('new','contacted','site_visit','quotation_sent','negotiation','won','lost')),
  budget numeric,
  assigned_to text,
  next_follow_up date,
  notes text
);
alter table public.leads enable row level security;
create policy "team read leads" on public.leads for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "team insert leads" on public.leads for insert to authenticated with check ((select public.has_role(array['admin','crm'])));
create policy "team update leads" on public.leads for update to authenticated using ((select public.has_role(array['admin','crm']))) with check ((select public.has_role(array['admin','crm'])));
create policy "admin delete leads" on public.leads for delete to authenticated using ((select public.has_role(array['admin'])));

create table public.follow_ups (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references public.leads(id) on delete cascade,
  created_at timestamptz not null default now(),
  note text not null,
  done_by text
);
create index follow_ups_lead_idx on public.follow_ups (lead_id, created_at desc);
alter table public.follow_ups enable row level security;
create policy "team read follow_ups" on public.follow_ups for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "team insert follow_ups" on public.follow_ups for insert to authenticated with check ((select public.has_role(array['admin','crm'])));
create policy "team update follow_ups" on public.follow_ups for update to authenticated using ((select public.has_role(array['admin','crm']))) with check ((select public.has_role(array['admin','crm'])));
create policy "admin delete follow_ups" on public.follow_ups for delete to authenticated using ((select public.has_role(array['admin'])));

-- ===== Products (no cost / supplier columns, ever) =====
create table public.products (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  code text,
  name text not null,
  description text,
  category text,
  brand text,
  end_user_price numeric,
  dealer_price numeric,
  active boolean not null default true
);
create unique index products_code_key on public.products (code) where code is not null;
alter table public.products enable row level security;
create policy "team read products" on public.products for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "admin insert products" on public.products for insert to authenticated with check ((select public.has_role(array['admin'])));
create policy "admin update products" on public.products for update to authenticated using ((select public.has_role(array['admin']))) with check ((select public.has_role(array['admin'])));
create policy "admin delete products" on public.products for delete to authenticated using ((select public.has_role(array['admin'])));

-- ===== Quotations =====
create sequence public.quote_number_seq start 1001;
create table public.quotations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  quote_number text not null unique default ('Q-' || nextval('public.quote_number_seq')::text),
  lead_id uuid references public.leads(id) on delete set null,
  client_name text not null,
  client_type text not null default 'end_customer' check (client_type in ('end_customer','dealer')),
  quote_date date not null default current_date,
  valid_until date default (current_date + 7),
  status text not null default 'draft' check (status in ('draft','sent','accepted','rejected')),
  subtotal numeric not null default 0,
  install_pct numeric not null default 0,
  install_amount numeric not null default 0,
  discount_pct numeric not null default 0,
  discount_amount numeric not null default 0,
  total numeric not null default 0,
  terms text,
  notes text,
  created_by text,
  delete_requested_by text,
  delete_requested_at timestamptz
);
create index quotations_lead_id_idx on public.quotations (lead_id);
alter table public.quotations enable row level security;
create policy "team read quotations" on public.quotations for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "team insert quotations" on public.quotations for insert to authenticated with check ((select public.has_role(array['admin','crm'])));
-- sales may only edit drafts; admin may edit anything
create policy "team update quotations" on public.quotations for update to authenticated
  using ((select public.has_role(array['admin'])) or ((select public.has_role(array['crm'])) and status = 'draft'))
  with check ((select public.has_role(array['admin','crm'])));
create policy "admin delete quotations" on public.quotations for delete to authenticated using ((select public.has_role(array['admin'])));

create table public.quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.quotations(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  room text,
  name text not null,
  description text,
  qty numeric not null default 1 check (qty > 0),
  unit_price numeric not null default 0,
  discount_pct numeric not null default 0 check (discount_pct between 0 and 100),
  sort_order int not null default 0
);
create index quotation_items_quotation_id_idx on public.quotation_items (quotation_id);
create index quotation_items_product_id_idx on public.quotation_items (product_id);
alter table public.quotation_items enable row level security;
create policy "team read quotation_items" on public.quotation_items for select to authenticated using ((select public.has_role(array['admin','crm'])));
create policy "team insert quotation_items" on public.quotation_items for insert to authenticated
  with check ((select public.has_role(array['admin'])) or ((select public.has_role(array['crm'])) and exists (select 1 from public.quotations q where q.id = quotation_id and q.status = 'draft')));
create policy "team update quotation_items" on public.quotation_items for update to authenticated
  using ((select public.has_role(array['admin'])) or ((select public.has_role(array['crm'])) and exists (select 1 from public.quotations q where q.id = quotation_id and q.status = 'draft')))
  with check ((select public.has_role(array['admin'])) or ((select public.has_role(array['crm'])) and exists (select 1 from public.quotations q where q.id = quotation_id and q.status = 'draft')));
create policy "admin delete quotation_items" on public.quotation_items for delete to authenticated using ((select public.has_role(array['admin'])));

create or replace function public.request_quote_deletion(p_quote uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_role(array['admin','crm']) then raise exception 'not allowed'; end if;
  update public.quotations set delete_requested_by = auth.jwt() ->> 'email', delete_requested_at = now()
  where id = p_quote and delete_requested_at is null;
end;
$$;

-- ===== Inventory =====
create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  category text,
  unit text not null default 'قطعة',
  quantity numeric not null default 0 check (quantity >= 0),
  min_qty numeric,
  location text,
  notes text,
  updated_at timestamptz not null default now(),
  updated_by text
);
alter table public.inventory_items enable row level security;
create policy "inventory team read items" on public.inventory_items for select to authenticated using ((select public.has_role(array['admin','inventory','installs'])));
create policy "inventory team insert items" on public.inventory_items for insert to authenticated with check ((select public.has_role(array['admin','inventory'])));
create policy "inventory team update items" on public.inventory_items for update to authenticated using ((select public.has_role(array['admin','inventory']))) with check ((select public.has_role(array['admin','inventory'])));
create policy "inventory team delete items" on public.inventory_items for delete to authenticated using ((select public.has_role(array['admin','inventory'])));

create table public.inventory_moves (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  item_id uuid not null references public.inventory_items(id) on delete cascade,
  kind text not null check (kind in ('count','in','out')),
  amount numeric not null,
  qty_before numeric not null,
  qty_after numeric not null,
  note text,
  done_by text
);
create index inventory_moves_item_idx on public.inventory_moves (item_id, created_at desc);
alter table public.inventory_moves enable row level security;
create policy "inventory team moves read" on public.inventory_moves for select to authenticated using ((select public.has_role(array['admin','inventory'])));
-- moves are written only by the functions below

create or replace function public.inventory_adjust(p_item uuid, p_kind text, p_amount numeric, p_note text default null)
returns public.inventory_items language plpgsql security definer set search_path = '' as $$
declare
  it public.inventory_items;
  new_qty numeric;
  who text := auth.jwt() ->> 'email';
begin
  if not public.has_role(array['admin','inventory']) then raise exception 'not allowed'; end if;
  if p_amount is null or p_amount < 0 then raise exception 'amount must be zero or more'; end if;
  select * into it from public.inventory_items where id = p_item for update;
  if not found then raise exception 'item not found'; end if;
  new_qty := case p_kind
    when 'count' then p_amount
    when 'in' then it.quantity + p_amount
    when 'out' then it.quantity - p_amount
  end;
  if new_qty is null then raise exception 'bad kind'; end if;
  if new_qty < 0 then raise exception 'not enough stock'; end if;
  insert into public.inventory_moves(item_id, kind, amount, qty_before, qty_after, note, done_by)
    values (p_item, p_kind, p_amount, it.quantity, new_qty, nullif(trim(p_note), ''), who);
  update public.inventory_items set quantity = new_qty, updated_at = now(), updated_by = who
    where id = p_item returning * into it;
  return it;
end;
$$;

-- ===== Installations =====
create table public.installations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  customer_name text not null,
  phone text,
  area text,
  address text,
  scheduled_date date,
  scheduled_time text,
  technician text,
  status text not null default 'pending' check (status in ('pending','in_progress','done','cancelled')),
  notes text,
  created_by text,
  updated_at timestamptz not null default now()
);
alter table public.installations enable row level security;
create policy "installs team" on public.installations for all to authenticated
  using ((select public.has_role(array['admin','installs']))) with check ((select public.has_role(array['admin','installs'])));

create table public.installation_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  installation_id uuid not null references public.installations(id) on delete cascade,
  item_id uuid not null references public.inventory_items(id) on delete restrict,
  qty numeric not null check (qty > 0),
  done_by text
);
create index installation_items_inst_idx on public.installation_items (installation_id);
create index installation_items_item_idx on public.installation_items (item_id);
alter table public.installation_items enable row level security;
create policy "installs team read items" on public.installation_items for select to authenticated using ((select public.has_role(array['admin','installs'])));

create table public.installation_photos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  installation_id uuid not null references public.installations(id) on delete cascade,
  kind text not null check (kind in ('before','after')),
  path text not null,
  uploaded_by text
);
create index installation_photos_inst_idx on public.installation_photos (installation_id);
alter table public.installation_photos enable row level security;
create policy "installs team photos" on public.installation_photos for all to authenticated
  using ((select public.has_role(array['admin','installs']))) with check ((select public.has_role(array['admin','installs'])));

create or replace function public.install_take_item(p_installation uuid, p_item uuid, p_qty numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare
  it public.inventory_items;
  inst public.installations;
  who text := auth.jwt() ->> 'email';
begin
  if not public.has_role(array['admin','installs']) then raise exception 'not allowed'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'amount must be more than zero'; end if;
  select * into inst from public.installations where id = p_installation;
  if not found then raise exception 'installation not found'; end if;
  select * into it from public.inventory_items where id = p_item for update;
  if not found then raise exception 'item not found'; end if;
  if it.quantity < p_qty then raise exception 'not enough stock'; end if;
  insert into public.installation_items(installation_id, item_id, qty, done_by) values (p_installation, p_item, p_qty, who);
  insert into public.inventory_moves(item_id, kind, amount, qty_before, qty_after, note, done_by)
    values (p_item, 'out', p_qty, it.quantity, it.quantity - p_qty, 'تركيبة: ' || inst.customer_name, who);
  update public.inventory_items set quantity = it.quantity - p_qty, updated_at = now(), updated_by = who where id = p_item;
end;
$$;

-- ===== Storage: private bucket for installation photos =====
insert into storage.buckets (id, name, public) values ('install-photos', 'install-photos', false)
on conflict (id) do nothing;
create policy "install photos read" on storage.objects for select to authenticated
  using (bucket_id = 'install-photos' and (select public.has_role(array['admin','installs'])));
create policy "install photos upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'install-photos' and (select public.has_role(array['admin','installs'])));
create policy "install photos delete" on storage.objects for delete to authenticated
  using (bucket_id = 'install-photos' and (select public.has_role(array['admin','installs'])));

-- ===== Function privileges: only signed-in users may call RPCs =====
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;

-- ===== Inventory quantity is changed only by the functions above, so every change is logged =====
revoke insert, update on public.inventory_items from authenticated, anon;
grant insert (name, category, unit, min_qty, location, notes, updated_by, updated_at) on public.inventory_items to authenticated;
grant update (name, category, unit, min_qty, location, notes, updated_by, updated_at) on public.inventory_items to authenticated;
