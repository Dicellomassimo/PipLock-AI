/**
 * PipLock AI — Edge Function: reset-daily-limits
 *
 * Funzione schedulata (cron) che viene eseguita ogni giorno a mezzanotte UTC.
 * Resetta i flag/contatori giornalieri per tutti gli utenti attivi.
 *
 * COME SCHEDULARE:
 *   Opzione 1 — supabase/config.toml (consigliata, già configurata):
 *     [functions.reset-daily-limits]
 *     schedule = "0 0 * * *"
 *
 *   Opzione 2 — Dashboard Supabase:
 *     Edge Functions → reset-daily-limits → Schedule → "0 0 * * *"
 *
 *   Opzione 3 — Supabase pg_cron (via SQL Editor):
 *     SELECT cron.schedule(
 *       'reset-daily-limits',
 *       '0 0 * * *',
 *       $$SELECT net.http_post(
 *         url := 'https://fltxpskrhjczpcaxvkpj.supabase.co/functions/v1/reset-daily-limits',
 *         headers := '{"Authorization": "Bearer <SERVICE_ROLE_KEY>"}'::jsonb
 *       )$$
 *     );
 *
 * Variabili d'ambiente:
 *   SUPABASE_URL              — impostata automaticamente in Edge Functions
 *   SUPABASE_SERVICE_ROLE_KEY — impostata automaticamente in Edge Functions
 *
 * Deploy:
 *   supabase functions deploy reset-daily-limits
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const securityHeaders = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Content-Security-Policy": "default-src 'none'",
};

const allHeaders = { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" };

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // ---------------------------------------------------------------- //
  // Authorization: only the Supabase cron system (service role) or   //
  // an explicit admin call with the service role Bearer token may     //
  // invoke this function. Reject anything else.                       //
  // ---------------------------------------------------------------- //
  const authHeader = req.headers.get("Authorization") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!authHeader.startsWith("Bearer ") ||
      authHeader.slice(7) !== serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: allHeaders },
    );
  }

  try {
    const startTime = new Date().toISOString();
    console.log(`[reset-daily-limits] Avvio reset giornaliero: ${startTime}`);

    // ---------------------------------------------------------------- //
    // Inizializza client Supabase con service_role                      //
    // ---------------------------------------------------------------- //
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const results: Record<string, unknown> = {};

    // ---------------------------------------------------------------- //
    // 1. Resetta i token settimanali se è lunedì (giorno 1 della week) //
    // ---------------------------------------------------------------- //
    const now = new Date();
    const dayOfWeek = now.getUTCDay(); // 0 = domenica, 1 = lunedì

    if (dayOfWeek === 1) {
      // È lunedì → reset token settimanali a 2 per tutti gli utenti free
      const { data: tokenReset, error: tokenError } = await supabase
        .from("profiles")
        .update({
          tokens_available: 2,
          tokens_reset_at: now.toISOString(),
        })
        .eq("subscription_tier", "free")
        .select("id");

      if (tokenError) {
        console.error("[reset-daily-limits] Errore reset token:", tokenError);
        results["token_reset"] = { error: tokenError.message };
      } else {
        const count = tokenReset?.length ?? 0;
        console.log(
          `[reset-daily-limits] Token resettati per ${count} utenti free`,
        );
        results["token_reset"] = { users_updated: count };
      }
    } else {
      results["token_reset"] = { skipped: "not Monday" };
    }

    // ---------------------------------------------------------------- //
    // 2. Chiudi le sfide (challenges) scadute                          //
    //    Se la challenge è attiva e duration_days è scaduta            //
    // ---------------------------------------------------------------- //
    const { data: expiredChallenges, error: challengeError } = await supabase
      .from("challenges")
      .select("id, started_at, duration_days")
      .eq("status", "active");

    if (challengeError) {
      console.error(
        "[reset-daily-limits] Errore lettura challenges:",
        challengeError,
      );
      results["challenges"] = { error: challengeError.message };
    } else {
      const expiredIds: string[] = [];

      for (const challenge of expiredChallenges ?? []) {
        const startedAt = new Date(challenge.started_at);
        const durationMs = challenge.duration_days * 24 * 60 * 60 * 1000;
        const expiresAt = new Date(startedAt.getTime() + durationMs);

        if (now > expiresAt) {
          expiredIds.push(challenge.id);
        }
      }

      if (expiredIds.length > 0) {
        const { error: updateError } = await supabase
          .from("challenges")
          .update({ status: "abandoned" })
          .in("id", expiredIds);

        if (updateError) {
          console.error(
            "[reset-daily-limits] Errore update challenges scadute:",
            updateError,
          );
          results["expired_challenges"] = { error: updateError.message };
        } else {
          console.log(
            `[reset-daily-limits] ${expiredIds.length} challenge marcate come 'abandoned'`,
          );
          results["expired_challenges"] = { updated: expiredIds.length };
        }
      } else {
        results["expired_challenges"] = { updated: 0 };
      }
    }

    // ---------------------------------------------------------------- //
    // 3. Aggiorna current_day per le challenge attive                  //
    // ---------------------------------------------------------------- //
    const { error: dayIncrementError } = await supabase.rpc(
      "increment_challenge_day",
    ).maybeSingle();
    // Nota: questa RPC va creata manualmente nel SQL Editor di Supabase:
    //   CREATE OR REPLACE FUNCTION increment_challenge_day()
    //   RETURNS void AS $$
    //     UPDATE challenges
    //     SET current_day = current_day + 1
    //     WHERE status = 'active';
    //   $$ LANGUAGE sql;
    // Se la funzione non esiste ancora, il campo error verrà ignorato silenziosamente.
    if (dayIncrementError) {
      console.warn(
        "[reset-daily-limits] increment_challenge_day non disponibile (ignorato):",
        dayIncrementError.message,
      );
      results["day_increment"] = { skipped: "RPC not available yet" };
    } else {
      results["day_increment"] = { ok: true };
    }

    // ---------------------------------------------------------------- //
    // 4. Marca le connessioni broker inattive da >5 minuti come 'error' //
    //    (indica che l'EA non sta più inviando heartbeat)               //
    // ---------------------------------------------------------------- //
    const fiveMinutesAgo = new Date(now.getTime() - 5 * 60 * 1000).toISOString();

    const { error: connError } = await supabase
      .from("broker_connections")
      .update({ status: "disconnected" })
      .eq("status", "connected")
      .lt("last_sync_at", fiveMinutesAgo);

    if (connError) {
      console.error(
        "[reset-daily-limits] Errore update broker_connections:",
        connError,
      );
      results["broker_connections"] = { error: connError.message };
    } else {
      results["broker_connections"] = { stale_marked_disconnected: true };
    }

    // ---------------------------------------------------------------- //
    // Risposta finale con riepilogo delle operazioni eseguite          //
    // ---------------------------------------------------------------- //
    const endTime = new Date().toISOString();
    console.log(
      `[reset-daily-limits] Completato: ${endTime} | Risultati:`,
      JSON.stringify(results),
    );

    return new Response(
      JSON.stringify({
        reset: true,
        timestamp: endTime,
        day_of_week: dayOfWeek,
        results,
      }),
      {
        status: 200,
        headers: allHeaders,
      },
    );
  } catch (err) {
    console.error("[reset-daily-limits] Errore interno:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: allHeaders,
      },
    );
  }
});
