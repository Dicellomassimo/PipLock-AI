-- =============================================================================
-- PipLock AI — Security Audit Log (004)
-- Run in Supabase SQL Editor after 003_ai_rate_limiting.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: security_audit_log
-- Immutable append-only log of security-relevant events.
-- ---------------------------------------------------------------------------
create table if not exists security_audit_log (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references profiles(id) on delete set null,
  event_type  text not null check (event_type in (
                'login_failed',
                'login_success',
                'password_changed',
                'killswitch_triggered',
                'rules_updated',
                'token_consumed',
                'rate_limit_hit',
                'suspicious_upload'
              )),
  metadata    jsonb,
  ip_hint     text,  -- optional: partial IP for forensics (not stored in full)
  created_at  timestamptz default now()
);

create index if not exists idx_audit_user  on security_audit_log(user_id);
create index if not exists idx_audit_event on security_audit_log(event_type);
create index if not exists idx_audit_time  on security_audit_log(created_at desc);

-- RLS: users can read their own audit entries; only service_role can insert.
alter table security_audit_log enable row level security;

create policy "select_own_audit_log"
  on security_audit_log for select
  using (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE policy for authenticated role —
-- only the service_role (Edge Functions) writes to this table.
-- Client-side writes are blocked entirely.

-- ---------------------------------------------------------------------------
-- Function: log_security_event
-- Called by Edge Functions and the Dart app (via RPC) to write audit entries.
-- Uses security definer so it can write even though clients can't INSERT directly.
-- ---------------------------------------------------------------------------
create or replace function log_security_event(
  p_event_type  text,
  p_metadata    jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Validate event type matches constraint
  insert into security_audit_log (user_id, event_type, metadata)
    values (auth.uid(), p_event_type, p_metadata);
end;
$$;

revoke execute on function log_security_event(text, jsonb) from public;
grant  execute on function log_security_event(text, jsonb) to authenticated;

-- =============================================================================
-- END
-- =============================================================================
