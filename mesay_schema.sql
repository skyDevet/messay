-- 0001: tables

create table if not exists public.business_info (
  id int primary key default 1 check (id = 1),          -- single row
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.business_info (id, data) values (1, '{}'::jsonb) on conflict (id) do nothing;

create table if not exists public.projects (
  id text primary key default gen_random_uuid()::text,
  title text not null,
  type text,
  icon text,
  image text,
  description text,
  budget text,
  duration text,
  year int,
  client text,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  loc text,
  stars int not null default 5 check (stars between 1 and 5),
  text text,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.quote_requests (
  id text primary key default gen_random_uuid()::text,
  user_id uuid references auth.users (id) on delete set null,
  user_email text,
  kind text not null check (kind in ('materials', 'services')),
  status text not null default 'new',
  client jsonb not null default '{}'::jsonb,
  cart jsonb,
  description text,
  service_type text,
  budget_range text,
  timeline text,
  created_at timestamptz not null default now()
);

create table if not exists public.proformas (
  id text primary key default gen_random_uuid()::text,
  number text unique,
  status text not null default 'draft',
  source_request_id text references public.quote_requests (id) on delete set null,
  client jsonb not null default '{}'::jsonb,
  lines jsonb not null default '[]'::jsonb,
  totals jsonb not null default '{}'::jsonb,
  terms text,
  valid_days int not null default 30,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null default 'admin',
  created_at timestamptz not null default now()
);

create index if not exists quote_requests_user_idx on public.quote_requests (user_id);
create index if not exists quote_requests_status_idx on public.quote_requests (status);
create index if not exists proformas_request_idx on public.proformas (source_request_id);

-- 0002: row level security + policies

-- SECURITY DEFINER avoids policy recursion when admin_users is checked from its own policies
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.business_info  enable row level security;
alter table public.projects       enable row level security;
alter table public.reviews        enable row level security;
alter table public.quote_requests enable row level security;
alter table public.proformas      enable row level security;
alter table public.admin_users    enable row level security;

-- Public read
drop policy if exists "business_info public read" on public.business_info;
create policy "business_info public read" on public.business_info
  for select to anon, authenticated using (true);

drop policy if exists "projects public read" on public.projects;
create policy "projects public read" on public.projects
  for select to anon, authenticated using (true);

drop policy if exists "reviews public read approved" on public.reviews;
create policy "reviews public read approved" on public.reviews
  for select to anon, authenticated using (approved = true);

-- Signed-in users can create their own quote requests
drop policy if exists "quote_requests insert own" on public.quote_requests;
create policy "quote_requests insert own" on public.quote_requests
  for insert to authenticated with check (auth.uid() = user_id);

-- Admins (anyone listed in admin_users) get full access everywhere
drop policy if exists "business_info admin all" on public.business_info;
create policy "business_info admin all" on public.business_info
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "projects admin all" on public.projects;
create policy "projects admin all" on public.projects
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "reviews admin all" on public.reviews;
create policy "reviews admin all" on public.reviews
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "quote_requests admin all" on public.quote_requests;
create policy "quote_requests admin all" on public.quote_requests
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "proformas admin all" on public.proformas;
create policy "proformas admin all" on public.proformas
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin_users admin all" on public.admin_users;
create policy "admin_users admin all" on public.admin_users
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- A signed-in user can read their own admin_users row (used by the login check)
drop policy if exists "admin_users read self" on public.admin_users;
create policy "admin_users read self" on public.admin_users
  for select to authenticated using (user_id = auth.uid());

-- Bootstrap your first admin (run once in the SQL editor, with your auth user id):
-- insert into public.admin_users (user_id, role) values ('00000000-0000-0000-0000-000000000000', 'admin');

-- 0003: storage bucket used by /api/uploads (signed upload URLs)
insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;
