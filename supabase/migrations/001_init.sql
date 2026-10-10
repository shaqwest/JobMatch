create extension if not exists vector;
create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  phone text,
  location text,
  summary text,
  skills text[] default '{}',
  experience text,
  education text,
  pref_type text default 'Any',
  pref_location text,
  cv_text text,
  embedding vector(1536),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  company text not null,
  website text,
  location text not null,
  type text not null check (type in ('WFO','Remote','Hybrid')),
  employment text not null check (employment in ('full_time','part_time','contract')),
  contract_duration text,
  salary_min int,
  salary_max int,
  posted_at timestamptz not null,
  source text not null,
  description text not null,
  responsibilities text,
  benefits text,
  workload text,
  apply_url text not null,
  company_rating numeric,
  embedding vector(1536),
  created_at timestamptz default now()
);
create index if not exists jobs_posted_at_idx on jobs(posted_at desc);
create index if not exists jobs_type_idx on jobs(type);
create index if not exists jobs_salary_idx on jobs(salary_min, salary_max);

create table if not exists applications (
  user_id uuid references auth.users(id) on delete cascade,
  job_id uuid references jobs(id) on delete cascade,
  status text default 'saved',
  created_at timestamptz default now(),
  primary key (user_id, job_id)
);

alter table profiles enable row level security;
alter table jobs enable row level security;
alter table applications enable row level security;

drop policy if exists "profiles self" on profiles;
create policy "profiles self" on profiles for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "jobs read all" on jobs;
create policy "jobs read all" on jobs for select using (true);

drop policy if exists "applications self" on applications;
create policy "applications self" on applications for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function update_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end; $$ language plpgsql;
drop trigger if exists profiles_updated_at on profiles;
create trigger profiles_updated_at before update on profiles for each row execute function update_updated_at();

-- Add storage bucket and strict policy
insert into storage.buckets (id, name, public) values ('cv_pdfs', 'cv_pdfs', false) on conflict do nothing;
drop policy if exists "cv_pdfs authenticated" on storage.objects;
drop policy if exists "cv_pdfs_owner_access" on storage.objects;
create policy "cv_pdfs_owner_access" on storage.objects 
for all to authenticated 
using (
  bucket_id = 'cv_pdfs' 
  and (storage.foldername(name))[1] = auth.uid()::text
) 
with check (
  bucket_id = 'cv_pdfs' 
  and (storage.foldername(name))[1] = auth.uid()::text
);
