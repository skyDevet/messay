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
