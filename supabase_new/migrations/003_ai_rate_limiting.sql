-- =============================================================================
-- PipLock AI — AI Usage Rate Limiting (003)
-- Run in Supabase SQL Editor after 002_security_hardening.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Table: ai_usage
-- Tracks daily AI requests per user to enforce rate limits.
-- Free users: 10 plan generations + 30 chat messages per day.
-- Pro users: 100 plan generations + 200 chat messages per day.
-- ---------------------------------------------------------------------------
create table if not exists ai_usage (
  user_id       uuid references profiles(id) on delete cascade,
  usage_date    date not null default current_date,
  plan_calls    int  not null default 0,
  chat_calls    int  not null default 0,
  updated_at    timestamptz default now(),
  primary key (user_id, usage_date)
);

alter table ai_usage enable row level security;

-- Users can only read and write their own usage records
create policy "all_own_ai_usage"
  on ai_usage for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Function: check_and_increment_ai_usage
-- Atomically checks the rate limit and increments the counter.
-- Returns TRUE if the call is allowed, FALSE if the limit is exceeded.
-- call_type: 'plan' | 'chat'
-- ---------------------------------------------------------------------------
create or replace function check_and_increment_ai_usage(call_type text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid          uuid := auth.uid();
  is_pro       boolean;
  plan_limit   int;
  chat_limit   int;
  current_plan int;
  current_chat int;
begin
  if uid is null then return false; end if;

  -- Determine tier limits
  select (subscription_tier = 'pro') into is_pro
    from profiles where id = uid;

  plan_limit := case when is_pro then 100 else 10 end;
  chat_limit := case when is_pro then 200 else 30 end;

  -- Upsert today's usage row
  insert into ai_usage (user_id, usage_date, plan_calls, chat_calls)
    values (uid, current_date, 0, 0)
    on conflict (user_id, usage_date) do nothing;

  -- Read current counters
  select plan_calls, chat_calls into current_plan, current_chat
    from ai_usage
    where user_id = uid and usage_date = current_date;

  -- Check limit
  if call_type = 'plan' and current_plan >= plan_limit then return false; end if;
  if call_type = 'chat' and current_chat >= chat_limit then return false; end if;

  -- Increment
  if call_type = 'plan' then
    update ai_usage
      set plan_calls = plan_calls + 1, updated_at = now()
      where user_id = uid and usage_date = current_date;
  else
    update ai_usage
      set chat_calls = chat_calls + 1, updated_at = now()
      where user_id = uid and usage_date = current_date;
  end if;

  return true;
end;
$$;

revoke execute on function check_and_increment_ai_usage(text) from public;
grant  execute on function check_and_increment_ai_usage(text) to authenticated;

-- =============================================================================
-- END
-- =============================================================================
