-- =============================================================================
-- PipLock AI — AI Limits Update (011)
-- Trial users: 2 plan generations/day + 5 chat messages/day  (unchanged)
-- Pro users:   3 plan generations/day + 20 chat messages/day (reduced from 10/50)
--
-- Rationale: Pro users rarely need more than 3 plan generations or 20 messages
-- per day. This reduces Groq API spend by ~60% while keeping the experience
-- complete. The Edge Function (ai-proxy) enforces these limits server-side.
-- =============================================================================

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

  plan_limit := case when is_pro then 3  else 2 end;
  chat_limit := case when is_pro then 20 else 5 end;

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

-- Update get_ai_usage_today to return new limits
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

  plan_limit := case when is_pro then 3  else 2 end;
  chat_limit := case when is_pro then 20 else 5 end;

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
