-- =============================================================================
-- PipLock AI — Security Hardening (002)
-- Run in Supabase SQL Editor after 001_initial_schema.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. BLOCK FIELD TAMPERING: prevent clients from escalating their own
--    subscription tier or inflating their token balance via the anon key.
--    The service role key (Edge Functions) bypasses RLS and can still write.
-- ---------------------------------------------------------------------------
drop policy if exists "update_own_profile" on profiles;

create policy "update_own_profile"
  on profiles for update
  using (auth.uid() = id)
  with check (
    auth.uid() = id
    -- Client cannot change subscription_tier (only Edge Functions / webhooks can)
    and subscription_tier = (
      select p.subscription_tier from profiles p where p.id = auth.uid()
    )
    -- Client cannot inflate token balance
    and tokens_available = (
      select p.tokens_available from profiles p where p.id = auth.uid()
    )
    and tokens_reset_at = (
      select p.tokens_reset_at from profiles p where p.id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 2. PGCRYPTO: enable extension for SHA-256 hashing of webhook secrets
-- ---------------------------------------------------------------------------
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 3. WEBHOOK SECRET HASHING: helper function
--    Usage: select hash_webhook_secret('my_raw_secret')  → returns hex digest
-- ---------------------------------------------------------------------------
create or replace function hash_webhook_secret(secret text)
returns text
language sql
immutable
as $$
  select encode(digest(secret, 'sha256'), 'hex')
$$;

-- ---------------------------------------------------------------------------
-- 4. PROTECT WEBHOOK SECRET: prevent client from overwriting the stored hash
--    (the hashed secret can only be rotated via the dedicated function below)
-- ---------------------------------------------------------------------------
drop policy if exists "update_own_broker" on broker_connections;

create policy "update_own_broker"
  on broker_connections for update
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    -- Client cannot replace the stored hash with a different value
    and webhook_secret is not distinct from (
      select b.webhook_secret from broker_connections b where b.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- 5. ROTATE WEBHOOK SECRET: security-definer RPC callable by the client.
--    Hashes the raw secret before storing — DB never holds plaintext.
--    Returns the raw secret once so the EA can be configured.
--    After this call the raw secret is unrecoverable from the DB.
-- ---------------------------------------------------------------------------
create or replace function rotate_webhook_secret(raw_secret text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if length(raw_secret) < 16 then
    raise exception 'Secret must be at least 16 characters';
  end if;

  update broker_connections
    set webhook_secret = encode(digest(raw_secret, 'sha256'), 'hex')
    where user_id = auth.uid();

  if not found then
    raise exception 'No broker connection found for current user';
  end if;

  return raw_secret;
end;
$$;

-- Grant execute to authenticated users only
revoke execute on function rotate_webhook_secret(text) from public;
grant  execute on function rotate_webhook_secret(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. VERIFY WEBHOOK SECRET: used by ea-webhook Edge Function to check
--    the hash of the incoming secret against the stored hash.
--    Called with service_role, so no RLS bypass needed here.
-- ---------------------------------------------------------------------------
create or replace function verify_webhook_secret(p_user_id uuid, raw_secret text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from broker_connections
    where user_id = p_user_id
      and webhook_secret = encode(digest(raw_secret, 'sha256'), 'hex')
  )
$$;

-- =============================================================================
-- END — apply in Supabase SQL Editor, then redeploy ea-webhook Edge Function
-- =============================================================================
