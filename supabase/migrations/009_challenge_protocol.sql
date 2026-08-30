-- =============================================================================
-- PipLock AI — Challenge Protocol columns (009)
-- Aggiunge i campi del Challenge Protocol alla tabella challenges,
-- inclusi preset prop firm, parametri strategia, Monte Carlo e regole.
-- =============================================================================

ALTER TABLE challenges
  ADD COLUMN IF NOT EXISTS prop_firm_preset       text,
  ADD COLUMN IF NOT EXISTS phases                 int         NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS drawdown_type          text        NOT NULL DEFAULT 'static'
                             CHECK (drawdown_type IN ('static','trailing_eod')),
  ADD COLUMN IF NOT EXISTS consistency_rule       boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS consistency_rule_pct   numeric,
  ADD COLUMN IF NOT EXISTS news_restriction       boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS overnight_restriction  boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS win_rate               numeric,
  ADD COLUMN IF NOT EXISTS avg_rr                 numeric,
  ADD COLUMN IF NOT EXISTS trades_per_day_strategy int,
  ADD COLUMN IF NOT EXISTS risk_profile           text        NOT NULL DEFAULT 'balanced'
                             CHECK (risk_profile IN ('conservative','balanced','aggressive')),
  ADD COLUMN IF NOT EXISTS monte_carlo_pass_pct   numeric,
  ADD COLUMN IF NOT EXISTS monte_carlo_range      text,
  ADD COLUMN IF NOT EXISTS monte_carlo_updated_at timestamptz;

-- =============================================================================
-- END — già applicata manualmente in Supabase SQL Editor il 2026-08-28
-- =============================================================================
