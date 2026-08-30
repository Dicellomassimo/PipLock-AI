-- Migration v2: token settimanali + currency
-- Esegui nel SQL Editor di Supabase

-- 1. Aggiungi tokens_purchased ai profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS tokens_purchased INT NOT NULL DEFAULT 0;

-- 2. Aggiungi currency alle personal_rules
ALTER TABLE personal_rules
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EUR';

-- 3. Setta tokens_reset_at per i profili esistenti che non ce l'hanno
UPDATE profiles
SET tokens_reset_at = DATE_TRUNC('week', NOW()) + INTERVAL '7 days'
WHERE tokens_reset_at IS NULL;
