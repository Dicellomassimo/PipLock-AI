-- =============================================================================
-- PipLock AI — AI Limits Tighter (006)
-- Updates Free/Pro limits to protect margins.
-- Free:  2 plan generations/day + 5 chat messages/day
-- Pro:   10 plan generations/day + 50 chat messages/day
-- Run in Supabase SQL Editor.
-- =============================================================================

-- Replace the rate-limit function with updated limits
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

  select (subscription_tier = 'pro') into is_pro
    from profiles where id = uid;

  -- Tighter limits: Free is minimal, Pro is generous but bounded
  plan_limit := case when is_pro then 10 else 2 end;
  chat_limit := case when is_pro then 50 else 5 end;

  insert into ai_usage (user_id, usage_date, plan_calls, chat_calls)
    values (uid, current_date, 0, 0)
    on conflict (user_id, usage_date) do nothing;

  select plan_calls, chat_calls into current_plan, current_chat
    from ai_usage
    where user_id = uid and usage_date = current_date;

  if call_type = 'plan' and current_plan >= plan_limit then return false; end if;
  if call_type = 'chat' and current_chat >= chat_limit then return false; end if;

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

-- New RPC: returns today's usage so the Flutter app can show "X/5 chats remaining"
create or replace function get_ai_usage_today()
returns json
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
  if uid is null then
    return json_build_object('plan_used', 0, 'chat_used', 0,
                             'plan_limit', 0, 'chat_limit', 0, 'is_pro', false);
  end if;

  select (subscription_tier = 'pro') into is_pro
    from profiles where id = uid;

  plan_limit := case when is_pro then 10 else 2 end;
  chat_limit := case when is_pro then 50 else 5 end;

  select coalesce(plan_calls, 0), coalesce(chat_calls, 0)
    into current_plan, current_chat
    from ai_usage
    where user_id = uid and usage_date = current_date;

  current_plan := coalesce(current_plan, 0);
  current_chat := coalesce(current_chat, 0);

  return json_build_object(
    'plan_used',  current_plan,
    'chat_used',  current_chat,
    'plan_limit', plan_limit,
    'chat_limit', chat_limit,
    'is_pro',     is_pro
  );
end;
$$;

revoke execute on function get_ai_usage_today() from public;
grant  execute on function get_ai_usage_today() to authenticated;

-- =============================================================================
-- END
-- =============================================================================
