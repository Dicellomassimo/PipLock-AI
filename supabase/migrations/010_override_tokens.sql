-- =============================================================================
-- PipLock AI — Override Tokens tracking (010)
-- Rinomina il concetto "token" in "override" e aggiunge il campo motivo
-- all'evento killswitch, per il report settimanale disciplina.
-- =============================================================================

-- Aggiungi override_reason a killswitch_events
ALTER TABLE killswitch_events
  ADD COLUMN IF NOT EXISTS override_reason text;

-- Aggiungi colonna override_week_count a profiles
-- (conta gli override usati questa settimana, resettato ogni lunedì)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS override_week_count   int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS override_week_reset_at timestamptz;

-- =============================================================================
-- END — esegui nel SQL Editor di Supabase → Run
-- =============================================================================
