-- Jaguar Smart Materials: RLS, storage and the RPCs guests use.
-- Guests never touch orders/quotes/customers tables directly: they go through the
-- security-definer functions below, and read their own order only with its secret token.

-- ============ RLS ============
alter table public.mat_profiles enable row level security;
alter table public.mat_staff_invites enable row level security;
alter table public.mat_customers enable row level security;
alter table public.mat_areas enable row level security;
alter table public.mat_categories enable row level security;
alter table public.mat_brands enable row level security;
alter table public.mat_products enable row level security;
alter table public.mat_product_area_prices enable row level security;
alter table public.mat_daily_price_items enable row level security;
alter table public.mat_price_history enable row level security;
alter table public.mat_banners enable row level security;
alter table public.mat_carts enable row level security;
alter table public.mat_orders enable row level security;
alter table public.mat_order_items enable row level security;
alter table public.mat_quotes enable row level security;
alter table public.mat_quote_files enable row level security;
alter table public.mat_reviews enable row level security;

-- public catalog: everyone reads active rows, staff read everything and edit, only admin deletes
create policy "read areas" on public.mat_areas for select using (active or (select public.mat_is_staff()));
create policy "read categories" on public.mat_categories for select using (active or (select public.mat_is_staff()));
create policy "read brands" on public.mat_brands for select using (active or (select public.mat_is_staff()));
create policy "read products" on public.mat_products for select using (active or (select public.mat_is_staff()));
create policy "read area prices" on public.mat_product_area_prices for select using (true);
create policy "read daily items" on public.mat_daily_price_items for select using (active or (select public.mat_is_staff()));
create policy "read price history" on public.mat_price_history for select using (true);
create policy "read banners" on public.mat_banners for select using (
  (active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now())) or (select public.mat_is_staff()));
create policy "read reviews" on public.mat_reviews for select using (approved or (select public.mat_is_staff()));

create policy "staff insert areas" on public.mat_areas for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update areas" on public.mat_areas for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete areas" on public.mat_areas for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert categories" on public.mat_categories for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update categories" on public.mat_categories for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete categories" on public.mat_categories for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert brands" on public.mat_brands for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update brands" on public.mat_brands for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete brands" on public.mat_brands for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert products" on public.mat_products for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update products" on public.mat_products for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete products" on public.mat_products for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert area prices" on public.mat_product_area_prices for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update area prices" on public.mat_product_area_prices for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete area prices" on public.mat_product_area_prices for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert daily items" on public.mat_daily_price_items for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update daily items" on public.mat_daily_price_items for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete daily items" on public.mat_daily_price_items for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert price history" on public.mat_price_history for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update price history" on public.mat_price_history for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete price history" on public.mat_price_history for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff insert banners" on public.mat_banners for insert to authenticated with check ((select public.mat_is_staff()));
create policy "staff update banners" on public.mat_banners for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete banners" on public.mat_banners for delete to authenticated using ((select public.mat_is_admin()));
create policy "staff update reviews" on public.mat_reviews for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "admin delete reviews" on public.mat_reviews for delete to authenticated using ((select public.mat_is_admin()));

-- people: users see their own profile; only admin manages roles and invites
create policy "own profile" on public.mat_profiles for select to authenticated using (user_id = (select auth.uid()) or (select public.mat_is_staff()));
create policy "own profile update" on public.mat_profiles for update to authenticated
  using (user_id = (select auth.uid()) or (select public.mat_is_admin()))
  with check ((user_id = (select auth.uid()) and role = (select public.mat_role())) or (select public.mat_is_admin()));
create policy "admin invites" on public.mat_staff_invites for all to authenticated using ((select public.mat_is_admin())) with check ((select public.mat_is_admin()));

create policy "customers read" on public.mat_customers for select to authenticated using (user_id = (select auth.uid()) or (select public.mat_is_staff()));
create policy "customers staff update" on public.mat_customers for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "customers admin delete" on public.mat_customers for delete to authenticated using ((select public.mat_is_admin()));

create policy "own cart" on public.mat_carts for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- orders & quotes: owners read their own, staff read/update, admin deletes. Inserts only via RPC.
create policy "orders read" on public.mat_orders for select to authenticated using (user_id = (select auth.uid()) or (select public.mat_is_staff()));
create policy "orders staff update" on public.mat_orders for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "orders admin delete" on public.mat_orders for delete to authenticated using ((select public.mat_is_admin()));
create policy "order items read" on public.mat_order_items for select to authenticated using (
  (select public.mat_is_staff()) or exists (select 1 from public.mat_orders o where o.id = order_id and o.user_id = (select auth.uid())));
create policy "order items staff update" on public.mat_order_items for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "order items admin delete" on public.mat_order_items for delete to authenticated using ((select public.mat_is_admin()));

create policy "quotes read" on public.mat_quotes for select to authenticated using (user_id = (select auth.uid()) or (select public.mat_is_staff()));
create policy "quotes staff update" on public.mat_quotes for update to authenticated using ((select public.mat_is_staff())) with check ((select public.mat_is_staff()));
create policy "quotes admin delete" on public.mat_quotes for delete to authenticated using ((select public.mat_is_admin()));
create policy "quote files read" on public.mat_quote_files for select to authenticated using (
  (select public.mat_is_staff()) or exists (select 1 from public.mat_quotes q where q.id = quote_id and q.user_id = (select auth.uid())));
create policy "quote files staff insert" on public.mat_quote_files for insert to authenticated with check ((select public.mat_is_staff()));
create policy "quote files admin delete" on public.mat_quote_files for delete to authenticated using ((select public.mat_is_admin()));

-- ============ storage ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('mat-public', 'mat-public', true, 5242880, array['image/jpeg','image/png','image/webp','image/avif']),
  ('mat-quote-files', 'mat-quote-files', false, 15728640, array[
    'application/pdf','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/csv','image/jpeg','image/png','image/webp','image/heic'])
on conflict (id) do nothing;

create policy "mat public staff upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'mat-public' and (select public.mat_is_staff()));
create policy "mat public staff update" on storage.objects for update to authenticated
  using (bucket_id = 'mat-public' and (select public.mat_is_staff()));
create policy "mat public admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'mat-public' and (select public.mat_is_admin()));
-- anyone may upload RFQ files into incoming/<random>/..., nobody but staff can read them back
create policy "mat quote upload" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'mat-quote-files' and (storage.foldername(name))[1] = 'incoming');
create policy "mat quote staff upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'mat-quote-files' and (select public.mat_is_staff()));
create policy "mat quote staff read" on storage.objects for select to authenticated
  using (bucket_id = 'mat-quote-files' and (select public.mat_is_staff()));
create policy "mat quote admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'mat-quote-files' and (select public.mat_is_admin()));

-- ============ RPCs ============

-- find or create the customer record for a phone; keeps the latest name/email
create or replace function public.mat_upsert_customer(p_phone text, p_name text, p_email text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare cid uuid;
begin
  insert into public.mat_customers (phone, name, email, user_id)
  values (p_phone, p_name, nullif(trim(p_email), ''), auth.uid())
  on conflict (phone) do update set
    name = coalesce(excluded.name, public.mat_customers.name),
    email = coalesce(excluded.email, public.mat_customers.email),
    updated_at = now()
  returning id into cid;
  return cid;
end;
$$;

-- signed-in user: create the profile on first visit; invited emails get their staff/admin role
create or replace function public.mat_ensure_profile()
returns text language plpgsql security definer set search_path = '' as $$
declare r text; inv text; em text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if auth.uid() is null then return 'guest'; end if;
  select role into inv from public.mat_staff_invites where lower(email) = em;
  insert into public.mat_profiles (user_id, role, full_name)
  values (auth.uid(), coalesce(inv, 'customer'), coalesce(auth.jwt() -> 'user_metadata' ->> 'full_name', auth.jwt() -> 'user_metadata' ->> 'name'))
  on conflict (user_id) do update set role = case
    when public.mat_profiles.role = 'customer' and inv is not null then inv else public.mat_profiles.role end
  returning role into r;
  return r;
end;
$$;

-- guest checkout: prices, stock and delivery fee are computed here, never trusted from the browser
create or replace function public.mat_create_order(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ph text := public.mat_normalize_phone(p ->> 'phone');
  nm text := nullif(trim(p ->> 'name'), '');
  addr text := nullif(trim(p ->> 'address'), '');
  pay text := p ->> 'payment_method';
  ar public.mat_areas;
  cid uuid; oid uuid; onum text; tok text;
  it jsonb; pr public.mat_products; st text; q numeric; price numeric;
  sub numeric := 0; n int := 0;
begin
  if nm is null or length(nm) > 120 then raise exception 'invalid_name'; end if;
  if ph is null then raise exception 'invalid_phone'; end if;
  if addr is null or length(addr) > 500 then raise exception 'invalid_address'; end if;
  if pay not in ('cod','bank_transfer') then raise exception 'invalid_payment_method'; end if;
  select * into ar from public.mat_areas where id = (p ->> 'area_id')::uuid and active;
  if not found then raise exception 'invalid_area'; end if;
  if jsonb_typeof(p -> 'items') <> 'array' or jsonb_array_length(p -> 'items') = 0 or jsonb_array_length(p -> 'items') > 50 then
    raise exception 'invalid_items';
  end if;
  if (p ->> 'delivery_date') is not null and (p ->> 'delivery_date')::date < current_date then raise exception 'invalid_delivery_date'; end if;

  cid := public.mat_upsert_customer(ph, nm, p ->> 'email');
  insert into public.mat_orders (customer_id, user_id, name, phone, address, area_id, area_name, delivery_date, payment_method, notes)
  values (cid, auth.uid(), nm, ph, addr, ar.id, ar.name || ', ' || ar.governorate, (p ->> 'delivery_date')::date, pay,
          left(nullif(trim(p ->> 'notes'), ''), 1000))
  returning id, order_number, access_token into oid, onum, tok;

  for it in select * from jsonb_array_elements(p -> 'items') loop
    select * into pr from public.mat_products where id = (it ->> 'product_id')::uuid and active;
    if not found then raise exception 'invalid_product'; end if;
    q := (it ->> 'qty')::numeric;
    if q is null or q < pr.min_order_qty or q > 100000 then raise exception 'invalid_qty'; end if;
    select stock_status into st from public.mat_product_area_prices where product_id = pr.id and area_id = ar.id;
    if st = 'out_of_stock' then raise exception 'out_of_stock'; end if;
    price := public.mat_price(pr.id, ar.id);
    insert into public.mat_order_items (order_id, product_id, name, unit, qty, unit_price, line_total)
    values (oid, pr.id, pr.name, pr.unit, q, price, round(q * price, 2));
    sub := sub + round(q * price, 2); n := n + 1;
    update public.mat_products set popularity = popularity + 1 where id = pr.id;
  end loop;

  update public.mat_orders set subtotal = sub, delivery_fee = ar.delivery_fee, total = sub + ar.delivery_fee where id = oid;
  return jsonb_build_object('order_number', onum, 'token', tok, 'subtotal', sub, 'delivery_fee', ar.delivery_fee,
                            'total', sub + ar.delivery_fee, 'items', n);
end;
$$;

-- RFQ: files must already be uploaded to mat-quote-files/incoming/...
create or replace function public.mat_create_quote(p jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  ph text := public.mat_normalize_phone(p ->> 'phone');
  nm text := nullif(trim(p ->> 'name'), '');
  ar public.mat_areas;
  cid uuid; qid uuid; qnum text; tok text; f jsonb;
begin
  if nm is null or length(nm) > 120 then raise exception 'invalid_name'; end if;
  if ph is null then raise exception 'invalid_phone'; end if;
  if nullif(trim(p ->> 'materials_text'), '') is null
     and (jsonb_typeof(p -> 'files') is distinct from 'array' or jsonb_array_length(p -> 'files') = 0) then
    raise exception 'empty_request';
  end if;
  if (p ->> 'area_id') is not null then
    select * into ar from public.mat_areas where id = (p ->> 'area_id')::uuid and active;
  end if;
  cid := public.mat_upsert_customer(ph, nm, p ->> 'email');
  insert into public.mat_quotes (customer_id, user_id, name, phone, area_id, area_name, project_type, needed_by, materials_text, notes)
  values (cid, auth.uid(), nm, ph, ar.id, case when ar.id is null then null else ar.name || ', ' || ar.governorate end,
          left(nullif(trim(p ->> 'project_type'), ''), 80), (p ->> 'needed_by')::date,
          left(nullif(trim(p ->> 'materials_text'), ''), 5000), left(nullif(trim(p ->> 'notes'), ''), 2000))
  returning id, quote_number, access_token into qid, qnum, tok;

  if jsonb_typeof(p -> 'files') = 'array' then
    if jsonb_array_length(p -> 'files') > 5 then raise exception 'too_many_files'; end if;
    for f in select * from jsonb_array_elements(p -> 'files') loop
      if (f ->> 'path') !~ '^incoming/[0-9a-f-]{36}/[^/]+$'
         or not exists (select 1 from storage.objects o where o.bucket_id = 'mat-quote-files' and o.name = f ->> 'path') then
        raise exception 'invalid_file';
      end if;
      insert into public.mat_quote_files (quote_id, kind, path, file_name, mime, size_bytes)
      values (qid, case when f ->> 'kind' = 'photo' then 'photo' else 'boq' end, f ->> 'path',
              left(f ->> 'file_name', 200), left(f ->> 'mime', 120), (f ->> 'size')::bigint);
    end loop;
  end if;
  return jsonb_build_object('quote_number', qnum, 'token', tok);
end;
$$;

-- guest tracking: only the secret token opens an order (never the phone number)
create or replace function public.mat_get_order(p_token text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'order_number', o.order_number, 'status', o.status, 'created_at', o.created_at, 'name', o.name,
    'phone', o.phone, 'address', o.address, 'area_name', o.area_name, 'delivery_date', o.delivery_date,
    'payment_method', o.payment_method, 'subtotal', o.subtotal, 'delivery_fee', o.delivery_fee, 'total', o.total,
    'notes', o.notes, 'claimed', o.user_id is not null,
    'items', (select coalesce(jsonb_agg(jsonb_build_object('product_id', i.product_id, 'name', i.name, 'unit', i.unit,
               'qty', i.qty, 'unit_price', i.unit_price, 'line_total', i.line_total,
               'slug', (select slug from public.mat_products where id = i.product_id),
               'reviewed', exists (select 1 from public.mat_reviews r where r.order_id = o.id and r.product_id = i.product_id))
               order by i.name), '[]'::jsonb) from public.mat_order_items i where i.order_id = o.id))
  from public.mat_orders o where o.access_token = p_token and length(p_token) = 48;
$$;

create or replace function public.mat_get_quote(p_token text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('quote_number', q.quote_number, 'status', q.status, 'created_at', q.created_at,
    'name', q.name, 'area_name', q.area_name, 'project_type', q.project_type, 'needed_by', q.needed_by,
    'materials_text', q.materials_text, 'notes', q.notes, 'quoted_amount', q.quoted_amount, 'quote_note', q.quote_note,
    'files', (select count(*) from public.mat_quote_files f where f.quote_id = q.id and f.kind <> 'admin_quote'),
    'claimed', q.user_id is not null)
  from public.mat_quotes q where q.access_token = p_token and length(p_token) = 48;
$$;

-- signed-in user claims the orders/quotes whose tokens this browser holds (guest -> account merge)
create or replace function public.mat_claim(p_tokens text[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare no int; nq int;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if coalesce(array_length(p_tokens, 1), 0) > 100 then raise exception 'too_many'; end if;
  update public.mat_orders set user_id = auth.uid() where access_token = any(p_tokens) and user_id is null;
  get diagnostics no = row_count;
  update public.mat_quotes set user_id = auth.uid() where access_token = any(p_tokens) and user_id is null;
  get diagnostics nq = row_count;
  update public.mat_customers c set user_id = auth.uid()
  where c.user_id is null and c.id in (
    select customer_id from public.mat_orders where access_token = any(p_tokens)
    union select customer_id from public.mat_quotes where access_token = any(p_tokens));
  return jsonb_build_object('orders', no, 'quotes', nq);
end;
$$;

-- reviews: only for products in a delivered order, via the order's token
create or replace function public.mat_submit_review(p_token text, p_product uuid, p_rating int, p_body text, p_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare o public.mat_orders;
begin
  select * into o from public.mat_orders where access_token = p_token and length(p_token) = 48;
  if not found then raise exception 'invalid_token'; end if;
  if o.status <> 'delivered' then raise exception 'not_delivered'; end if;
  if not exists (select 1 from public.mat_order_items where order_id = o.id and product_id = p_product) then
    raise exception 'not_in_order';
  end if;
  if p_rating not between 1 and 5 then raise exception 'invalid_rating'; end if;
  insert into public.mat_reviews (product_id, order_id, customer_id, rating, body, author_name)
  values (p_product, o.id, o.customer_id, p_rating, left(nullif(trim(p_body), ''), 2000),
          left(coalesce(nullif(trim(p_name), ''), split_part(o.name, ' ', 1)), 60));
end;
$$;

-- admin: save a whole area's daily prices in one call (history is kept per day)
create or replace function public.mat_set_daily_prices(p_area uuid, p_prices jsonb, p_date date default current_date)
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if not public.mat_is_staff() then raise exception 'not_allowed'; end if;
  insert into public.mat_price_history (item_id, area_id, price, recorded_on, recorded_by)
  select (x ->> 'item_id')::uuid, p_area, (x ->> 'price')::numeric, p_date, auth.uid()
  from jsonb_array_elements(p_prices) x
  where (x ->> 'price') is not null and (x ->> 'price')::numeric > 0
  on conflict (item_id, area_id, recorded_on) do update set price = excluded.price, recorded_at = now(), recorded_by = excluded.recorded_by;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- admin customers view: one row per phone with order/quote totals
create or replace view public.mat_customer_summary with (security_invoker = true) as
select c.id, c.phone, c.name, c.email, c.user_id, c.created_at,
  (select count(*) from public.mat_orders o where o.customer_id = c.id) as orders_count,
  (select coalesce(sum(o.total), 0) from public.mat_orders o where o.customer_id = c.id and o.status <> 'cancelled') as orders_total,
  (select count(*) from public.mat_quotes q where q.customer_id = c.id) as quotes_count,
  greatest((select max(o.created_at) from public.mat_orders o where o.customer_id = c.id),
           (select max(q.created_at) from public.mat_quotes q where q.customer_id = c.id)) as last_activity
from public.mat_customers c;

-- ============ function privileges ============
revoke execute on function public.mat_upsert_customer(text, text, text) from public, anon, authenticated;
grant execute on function public.mat_normalize_phone(text) to anon, authenticated;
grant execute on function public.mat_role() to anon, authenticated;
grant execute on function public.mat_is_staff() to anon, authenticated;
grant execute on function public.mat_is_admin() to anon, authenticated;
grant execute on function public.mat_price(uuid, uuid) to anon, authenticated;
grant execute on function public.mat_create_order(jsonb) to anon, authenticated;
grant execute on function public.mat_create_quote(jsonb) to anon, authenticated;
grant execute on function public.mat_get_order(text) to anon, authenticated;
grant execute on function public.mat_get_quote(text) to anon, authenticated;
grant execute on function public.mat_submit_review(text, uuid, int, text, text) to anon, authenticated;
grant execute on function public.mat_ensure_profile() to authenticated;
grant execute on function public.mat_claim(text[]) to authenticated;
grant execute on function public.mat_set_daily_prices(uuid, jsonb, date) to authenticated;
revoke execute on function public.mat_token() from public, anon, authenticated;

-- only signed-in users may call these (they check the caller themselves as well)
revoke execute on function public.mat_claim(text[]) from public, anon;
revoke execute on function public.mat_ensure_profile() from public, anon;
revoke execute on function public.mat_set_daily_prices(uuid, jsonb, date) from public, anon;
