-- twentytwo — platform schema (auth: logins, dashboards, brand domain logic)
-- Run AFTER supabase-schema.sql, in the Supabase SQL editor.
-- Adds: brands, brand_join_requests, a domain existence check, and creator self-service policies.

-- ============ brands (one account-holder per company domain) ============
create table if not exists brands (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references auth.users(id) on delete set null,  -- the account holder
  created_at   timestamptz not null default now(),
  company      text not null,
  domain       text not null unique,        -- e.g. acme.com  (one brand account per domain)
  contact_name text,
  website      text,
  status       text not null default 'active'
);
alter table brands enable row level security;
-- a brand holder can see and manage only their own row; brands are NOT publicly listable
create policy "brands self read"   on brands for select using (auth.uid() = user_id);
create policy "brands self insert" on brands for insert with check (auth.uid() = user_id);
create policy "brands self update" on brands for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============ brand_join_requests (someone from an already-registered domain tried to sign up) ============
-- The edge function (added later) reads these to email the existing holder with a redacted address.
create table if not exists brand_join_requests (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  domain          text not null,
  requester_email text not null,
  company         text,
  notified        boolean not null default false
);
alter table brand_join_requests enable row level security;
create policy "brand_join_requests insert (public)" on brand_join_requests for insert with check (true);

-- ============ domain existence check (no row data leaked) ============
-- Returns only true/false for a domain, so the signup page can detect a collision
-- without ever exposing which companies are registered.
create or replace function domain_taken(p_domain text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from brands where lower(domain) = lower(p_domain));
$$;
grant execute on function domain_taken(text) to anon, authenticated;

-- ============ creators: self-service for the dashboard ============
-- Let a creator read their own row regardless of approval status (public read of 'approved' already exists).
create policy "creators self read" on creators for select using (auth.uid() = user_id);

-- Self-signups must NOT be able to publish themselves to the board: force a non-approved status on insert.
drop policy if exists "creators self insert" on creators;
create policy "creators self insert" on creators for insert
  with check (auth.uid() = user_id and status in ('waitlist','reviewing'));
