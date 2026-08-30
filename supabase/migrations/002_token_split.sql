ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS tokens_weekly int DEFAULT 2,
  ADD COLUMN IF NOT EXISTS tokens_purchased int DEFAULT 0;

-- Migra i dati esistenti: tutti i tokens_available attuali → tokens_weekly
UPDATE profiles SET tokens_weekly = LEAST(tokens_available, 2), tokens_purchased = GREATEST(tokens_available - 2, 0) WHERE tokens_available IS NOT NULL;
