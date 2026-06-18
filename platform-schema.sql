-- twentytwo — platform schema (auth: logins, dashboards, brand domain logic, claimable profiles)
-- Run AFTER supabase-schema.sql, in the Supabase SQL editor. Safe to re-run.

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
drop policy if exists "brands self read"   on brands;
drop policy if exists "brands self insert" on brands;
drop policy if exists "brands self update" on brands;
create policy "brands self read"   on brands for select using (auth.uid() = user_id);
create policy "brands self insert" on brands for insert with check (auth.uid() = user_id);
create policy "brands self update" on brands for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============ brand_join_requests (already-registered domain tried to sign up) ============
create table if not exists brand_join_requests (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  domain          text not null,
  requester_email text not null,
  company         text,
  notified        boolean not null default false
);
alter table brand_join_requests enable row level security;
drop policy if exists "brand_join_requests insert (public)" on brand_join_requests;
create policy "brand_join_requests insert (public)" on brand_join_requests for insert with check (true);

-- ============ domain existence check (no row data leaked) ============
create or replace function domain_taken(p_domain text)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from brands where lower(domain) = lower(p_domain));
$$;
grant execute on function domain_taken(text) to anon, authenticated;

-- ============ creators: claimable profiles + self-service ============
-- Pre-create profiles for creators ahead of joining; they claim them on first login.
alter table creators add column if not exists claim_email text;   -- email we expect them to claim with
alter table creators add column if not exists claimed boolean not null default false;

-- a creator can read their own row regardless of approval status
drop policy if exists "creators self read" on creators;
create policy "creators self read" on creators for select using (auth.uid() = user_id);

-- self-signups can't publish themselves to the board: force a non-approved status on insert
drop policy if exists "creators self insert" on creators;
create policy "creators self insert" on creators for insert
  with check (auth.uid() = user_id and status in ('waitlist','reviewing'));

-- Claim: link a pre-created profile to the logged-in user when their (verified) email matches.
-- Magic-link login proves the user owns the email, so matching on it is safe.
create or replace function claim_creator()
returns text language plpgsql security definer set search_path = public as $$
declare v_email text; v_handle text;
begin
  select email into v_email from auth.users where id = auth.uid();
  if v_email is null then return null; end if;
  update creators
     set user_id = auth.uid(), claimed = true
   where claimed = false and user_id is null and lower(claim_email) = lower(v_email)
   returning handle into v_handle;
  return v_handle;  -- the claimed handle, or null if nothing matched
end$$;
grant execute on function claim_creator() to authenticated;
