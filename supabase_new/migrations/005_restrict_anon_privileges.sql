-- =============================================================================
-- PipLock AI — Restrict anon role privileges (005)
-- Run in Supabase SQL Editor after 004_security_audit_log.sql
-- Principle of least privilege: anon should never touch business tables.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Revoke any accidental table-level privileges from anon
-- ---------------------------------------------------------------------------
revoke all on table profiles            from anon;
revoke all on table personal_rules      from anon;
revoke all on table challenges          from anon;
revoke all on table killswitch_events   from anon;
revoke all on table broker_connections  from anon;
revoke all on table notification_prefs  from anon;
revoke all on table security_audit_log  from anon;

-- ai_usage may not exist yet if 003 hasn't been run; guard with DO block
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'ai_usage'
  ) then
    revoke all on table ai_usage from anon;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Revoke security-definer functions from anon (guarded — only if they exist)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'log_security_event') then
    revoke execute on function log_security_event(text, jsonb) from anon;
  end if;

  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'rotate_webhook_secret') then
    revoke execute on function rotate_webhook_secret(text) from anon;
  end if;

  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'verify_webhook_secret') then
    revoke execute on function verify_webhook_secret(uuid, text) from anon;
  end if;

  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'check_and_increment_ai_usage') then
    revoke execute on function check_and_increment_ai_usage(text) from anon;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Confirm anon has no default sequence access on business tables
-- (Supabase auto-creates sequences for serial columns; anon should not use them)
-- ---------------------------------------------------------------------------
revoke usage on all sequences in schema public from anon;

-- =============================================================================
-- END
-- =============================================================================
