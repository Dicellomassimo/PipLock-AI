-- =============================================================================
-- PipLock AI — Schema database (Supabase/Postgres)
-- Incolla tutto questo nel SQL Editor di Supabase ed esegui con "Run"
-- URL progetto: https://fltxpskrhjczpcaxvkpj.supabase.co
-- =============================================================================

-- ---------------------------------------------------------------------------
-- TABELLA: profiles
-- ---------------------------------------------------------------------------
create table if not exists profiles (
  id                uuid references auth.users(id) on delete cascade primary key,
  account_mode      text default 'personal' check (account_mode in ('personal', 'challenge')),
  tokens_available  int default 2,
  tokens_reset_at   timestamptz default now(),
  subscription_tier text default 'free' check (subscription_tier in ('free', 'pro')),
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

-- Trigger aggiornamento updated_at (riutilizzato su tutte le tabelle)
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on profiles
  for each row execute procedure update_updated_at();

-- RLS
alter table profiles enable row level security;

create policy "select_own_profile"
  on profiles for select using (auth.uid() = id);

create policy "insert_own_profile"
  on profiles for insert with check (auth.uid() = id);

create policy "update_own_profile"
  on profiles for update using (auth.uid() = id);

-- Trigger: crea profilo automaticamente al signup
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, account_mode, tokens_available, subscription_tier)
  values (new.id, 'personal', 2, 'free')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ---------------------------------------------------------------------------
-- TABELLA: personal_rules
-- ---------------------------------------------------------------------------
create table if not exists personal_rules (
  user_id                uuid references profiles(id) on delete cascade primary key,
  max_daily_loss         numeric,
  max_daily_loss_type    text check (max_daily_loss_type in ('amount', 'percent')),
  max_trades_per_day     int,
  max_weekly_loss        numeric,
  trading_hours_enabled  boolean default false,
  trading_hours_start    time,
  trading_hours_end      time,
  killswitch_duration    text default '6h' check (killswitch_duration in ('2h', '6h', 'midnight', '24h')),
  timezone               text default 'Europe/Rome',
  updated_at             timestamptz default now()
);

create trigger personal_rules_updated_at
  before update on personal_rules
  for each row execute procedure update_updated_at();

alter table personal_rules enable row level security;

create policy "all_own_personal_rules"
  on personal_rules for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- TABELLA: challenges
-- ---------------------------------------------------------------------------
create table if not exists challenges (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid references profiles(id) on delete cascade,
  prop_firm_name      text,
  account_size        numeric not null,
  profit_target       numeric not null,
  max_daily_loss      numeric not null,
  max_total_drawdown  numeric not null,
  duration_days       int not null,
  style               text default 'moderate' check (style in ('conservative', 'moderate', 'aggressive')),
  status              text default 'active' check (status in ('active', 'passed', 'failed', 'abandoned')),
  current_day         int default 0,
  ai_plan             jsonb,
  started_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

create trigger challenges_updated_at
  before update on challenges
  for each row execute procedure update_updated_at();

alter table challenges enable row level security;

create policy "all_own_challenges"
  on challenges for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Funzione usata dalla Edge Function reset-daily-limits
create or replace function increment_challenge_day()
returns void language sql as $$
  update challenges set current_day = current_day + 1 where status = 'active';
$$;

-- ---------------------------------------------------------------------------
-- TABELLA: killswitch_events
-- ---------------------------------------------------------------------------
create table if not exists killswitch_events (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid references profiles(id) on delete cascade,
  triggered_at          timestamptz default now(),
  reason                text check (reason in (
                           'daily_loss', 'max_trades', 'revenge_pattern',
                           'overleveraging', 'fomo_pattern'
                         )),
  account_mode          text check (account_mode in ('personal', 'challenge')),
  lock_duration_minutes int,
  unlocked_early        boolean default false,
  unlocked_with_token   boolean default false,
  resolved_at           timestamptz
);

create index if not exists idx_ks_events_user on killswitch_events(user_id);
create index if not exists idx_ks_events_time on killswitch_events(triggered_at desc);

alter table killswitch_events enable row level security;

create policy "all_own_ks_events"
  on killswitch_events for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- TABELLA: broker_connections
-- ---------------------------------------------------------------------------
create table if not exists broker_connections (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references profiles(id) on delete cascade,
  connection_type  text default 'ea_webhook' check (connection_type in ('ea_webhook', 'metaapi')),
  broker           text default 'mt5' check (broker in ('mt4', 'mt5', 'ctrader')),
  webhook_secret   text,
  status           text default 'disconnected' check (status in ('connected', 'error', 'disconnected')),
  last_sync_at     timestamptz,
  created_at       timestamptz default now()
);

-- Un solo record per utente
create unique index if not exists idx_broker_user on broker_connections(user_id);

alter table broker_connections enable row level security;

create policy "select_own_broker"
  on broker_connections for select using (auth.uid() = user_id);

create policy "insert_own_broker"
  on broker_connections for insert with check (auth.uid() = user_id);

create policy "update_own_broker"
  on broker_connections for update using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- TABELLA: notification_prefs
-- ---------------------------------------------------------------------------
create table if not exists notification_prefs (
  user_id              uuid references profiles(id) on delete cascade primary key,
  news_alerts          boolean default true,
  session_changes      boolean default true,
  risk_warnings        boolean default true,
  challenge_reminders  boolean default true,
  fomo_alerts          boolean default true,
  fcm_token            text,
  updated_at           timestamptz default now()
);

create trigger notification_prefs_updated_at
  before update on notification_prefs
  for each row execute procedure update_updated_at();

alter table notification_prefs enable row level security;

create policy "all_own_notification_prefs"
  on notification_prefs for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- TABELLA: risk_alerts
-- Avvisi soft (non bloccanti) — soft warning, FOMO, revenge trading
-- ---------------------------------------------------------------------------
create table if not exists risk_alerts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references profiles(id) on delete cascade,
  alert_type       text check (alert_type in ('soft_warning', 'fomo_pattern', 'revenge_pattern')),
  message          text,
  equity           numeric,
  drawdown_percent numeric,
  dismissed        boolean default false,
  created_at       timestamptz default now()
);

create index if not exists idx_risk_alerts_user on risk_alerts(user_id);
create index if not exists idx_risk_alerts_time on risk_alerts(created_at desc);

alter table risk_alerts enable row level security;

create policy "all_own_risk_alerts"
  on risk_alerts for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- REALTIME: abilita subscription per le tabelle chiave
-- (permette a Flutter di ricevere aggiornamenti istantanei dall'EA)
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table killswitch_events;
alter publication supabase_realtime add table risk_alerts;
alter publication supabase_realtime add table broker_connections;

-- =============================================================================
-- FINE SCRIPT — tutte le tabelle, RLS, trigger e indici sono pronti
-- =============================================================================
