-- Run this in Supabase SQL Editor to enable multiple personal accounts
-- After running this, your existing personal_rules data will be migrated automatically

create table if not exists personal_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) not null,
  name text not null default 'Account',
  account_number text,
  connection_method text check (connection_method in ('manual','accessibility','ea','metaapi','ctrader','oanda')) default 'manual',
  max_daily_loss numeric,
  max_daily_loss_type text check (max_daily_loss_type in ('amount','percent')),
  max_trades_per_day int,
  max_weekly_loss numeric,
  trading_hours_enabled boolean default false,
  trading_hours_start text,
  trading_hours_end text,
  killswitch_duration text check (killswitch_duration in ('2h','6h','midnight','24h')) default '6h',
  timezone text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table personal_accounts enable row level security;

create policy if not exists "personal_accounts_self"
  on personal_accounts for all using (auth.uid() = user_id);

-- Migrate existing personal_rules → personal_accounts (safe, on conflict do nothing)
insert into personal_accounts (
  user_id, name, account_number, connection_method,
  max_daily_loss, max_daily_loss_type, max_trades_per_day, max_weekly_loss,
  trading_hours_enabled, trading_hours_start, trading_hours_end,
  killswitch_duration, timezone, created_at, updated_at
)
select
  user_id,
  'Main Account' as name,
  account_number,
  'manual' as connection_method,
  max_daily_loss, max_daily_loss_type, max_trades_per_day, max_weekly_loss,
  trading_hours_enabled,
  trading_hours_start::text,
  trading_hours_end::text,
  killswitch_duration, timezone,
  coalesce(updated_at, now()),
  coalesce(updated_at, now())
from personal_rules
on conflict do nothing;
