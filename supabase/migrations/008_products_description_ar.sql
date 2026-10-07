-- Arabic descriptions for the Home Sense products (applied through the dashboard migration of the same name).
alter table public.products add column if not exists description_ar text;
-- values: see the products_description_ar migration in Supabase (33 English descriptions mapped to Arabic).
