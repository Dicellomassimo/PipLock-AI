-- =============================================================================
-- PipLock AI — Fix trigger updated_at (007)
-- Risolve errore PostgreSQL 42703 ("column not found") causato dal trigger
-- update_updated_at applicato a tabelle prive della colonna updated_at.
--
-- Tabelle SENZA updated_at (trigger NON deve esistere):
--   killswitch_events, broker_connections, risk_alerts, security_audit_log
--
-- Tabelle CON updated_at (trigger DEVE esistere):
--   profiles, personal_rules, challenges, notification_prefs, ai_usage
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Rimuovi trigger errati (su tabelle senza colonna updated_at)
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS update_updated_at ON killswitch_events;
DROP TRIGGER IF EXISTS killswitch_events_updated_at ON killswitch_events;

DROP TRIGGER IF EXISTS update_updated_at ON broker_connections;
DROP TRIGGER IF EXISTS broker_connections_updated_at ON broker_connections;

DROP TRIGGER IF EXISTS update_updated_at ON risk_alerts;
DROP TRIGGER IF EXISTS risk_alerts_updated_at ON risk_alerts;

DROP TRIGGER IF EXISTS update_updated_at ON security_audit_log;
DROP TRIGGER IF EXISTS security_audit_log_updated_at ON security_audit_log;

-- ---------------------------------------------------------------------------
-- 2. Assicura che la funzione trigger esista (idempotente)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. Ricrea i trigger sulle tabelle che devono averli
--    (DROP IF EXISTS + CREATE per renderli idempotenti)
-- ---------------------------------------------------------------------------

-- profiles
DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- personal_rules
DROP TRIGGER IF EXISTS personal_rules_updated_at ON personal_rules;
CREATE TRIGGER personal_rules_updated_at
  BEFORE UPDATE ON personal_rules
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- challenges
DROP TRIGGER IF EXISTS challenges_updated_at ON challenges;
CREATE TRIGGER challenges_updated_at
  BEFORE UPDATE ON challenges
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- notification_prefs
DROP TRIGGER IF EXISTS notification_prefs_updated_at ON notification_prefs;
CREATE TRIGGER notification_prefs_updated_at
  BEFORE UPDATE ON notification_prefs
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- ai_usage (ha updated_at, ma il trigger non era nelle migration precedenti)
DROP TRIGGER IF EXISTS ai_usage_updated_at ON ai_usage;
CREATE TRIGGER ai_usage_updated_at
  BEFORE UPDATE ON ai_usage
  FOR EACH ROW EXECUTE PROCEDURE update_updated_at();

-- =============================================================================
-- END — esegui questo script nel SQL Editor di Supabase → Run
-- =============================================================================
