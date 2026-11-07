-- Control-center app (/app): «المصاريف والحسابات». System subscriptions (company is null) and manual
-- expenses per company (company = jaguar | tuya-suez | aix). Owner only: read and write through
-- app_is_owner() from 104. Numbers come only from Abdallah or real invoices; a row without an amount
-- shows «مستني الرقم» in the app.
-- Run once by hand in the Supabase SQL editor (project jaguar-smart). Safe to run again.

create table if not exists public.app_costs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  amount numeric check (amount is null or amount >= 0),
  currency text not null default 'USD' check (currency in ('USD', 'EGP', 'EUR')),
  period text not null default 'month' check (period in ('month', 'year', 'once')),
  company text check (company in ('jaguar', 'tuya-suez', 'aix')),
  source text,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists app_costs_company_idx on public.app_costs (company);

alter table public.app_costs enable row level security;
drop policy if exists "owner only" on public.app_costs;
create policy "owner only" on public.app_costs for all to authenticated
  using ((select public.app_is_owner())) with check ((select public.app_is_owner()));
revoke all on public.app_costs from anon;
grant select, insert, update, delete on public.app_costs to authenticated;

create or replace function public.app_costs_touch()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists app_costs_touch on public.app_costs;
create trigger app_costs_touch before update on public.app_costs for each row execute function public.app_costs_touch();

-- Seed: only numbers from a real invoice or confirmed by Abdallah (8 Nov 2026). Unknown amounts stay empty.
insert into public.app_costs (name, amount, currency, period, source, note)
select v.name, v.amount, 'USD', v.period, v.source, v.note
from (values
  ('Hostinger VPS (KVM 2)', 15.95::numeric, 'month', 'invoice H_53876259', '13.99 + 1.96 ضريبة · من 30 أكتوبر لـ 30 نوفمبر 2026 · تجديد تلقائي'),
  ('Green API', 0::numeric, 'month', 'Abdallah 2026-11-08', 'خطة Developer المجانية · دفعة PayPal 12$ يوم 19 أكتوبر ما اتخصمتش'),
  ('Meta WhatsApp', 0::numeric, 'month', 'Abdallah 2026-11-08', 'لسه مجاني'),
  ('Supadata', 0::numeric, 'month', 'Abdallah 2026-11-08', 'مش بيدفع'),
  ('Gemini (Google Cloud)', null::numeric, 'month', null, '⚠️ حساب الفوترة في Google Cloud متأخر من 1 نوفمبر، والمشروع ممكن يتوقف'),
  ('الدومينات (jaguarsmart.com على GoDaddy)', null::numeric, 'year', null, 'المبلغ مش معروف')
) as v(name, amount, period, source, note)
where not exists (select 1 from public.app_costs c where c.name = v.name and c.company is null);
