-- SHAHI invites: a single-use code lets a new team member create their own account and pick their own password.
-- The role comes from the code. Only the SHA-256 of a code is stored, so it is shown once when it is made.

create table public.shahi_invites (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  full_name text not null,
  role text not null check (role in ('admin','sales','ops','chef')),
  created_by uuid references public.shahi_staff(user_id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_at timestamptz,
  used_by uuid references auth.users(id) on delete set null
);

alter table public.shahi_invites enable row level security;
create policy "admin manage invites" on public.shahi_invites for all to authenticated
  using ((select public.shahi_has_role(array['admin']))) with check ((select public.shahi_has_role(array['admin'])));
