-- Migration 008: Aggiunge live_data a broker_connections e nuovi reason al killswitch
-- Bugfix critico: la colonna live_data era usata da Flutter ma non esisteva in DB.

-- Aggiunge colonna live_data a broker_connections (era usata da Flutter ma non esisteva)
ALTER TABLE broker_connections ADD COLUMN IF NOT EXISTS live_data jsonb;

-- Estende il check constraint su killswitch_events.reason con nuovi tipi
ALTER TABLE killswitch_events DROP CONSTRAINT IF EXISTS killswitch_events_reason_check;
ALTER TABLE killswitch_events ADD CONSTRAINT killswitch_events_reason_check
  CHECK (reason IN (
    'daily_loss', 'max_trades', 'revenge_pattern', 'overleveraging', 'fomo_pattern',
    'consecutive_losses', 'fast_reentry', 'plan_violation', 'trading_hours'
  ));
