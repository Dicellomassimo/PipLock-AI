/**
 * PipLock AI — Edge Function: ea-webhook
 *
 * Riceve i dati inviati dall'Expert Advisor MQL5.
 * Gestisce eventi: heartbeat, connected, hard_killswitch, soft_warning, max_trades
 *
 * Variabili d'ambiente (configurate automaticamente da Supabase):
 *   SUPABASE_URL              — URL del progetto
 *   SUPABASE_SERVICE_ROLE_KEY — Service role key (server-side only)
 *
 * Autenticazione: per-user SHA-256 hashed secret stored in broker_connections.
 * Deploy: supabase functions deploy ea-webhook
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Security headers applied to every non-OPTIONS response
const securityHeaders = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "Content-Security-Policy": "default-src 'none'",
};

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface EAPayload {
  user_id: string;
  event:
    | "heartbeat"
    | "connected"
    | "hard_killswitch"
    | "soft_warning"
    | "max_trades";
  equity: number;
  balance: number;
  drawdown_percent: number;
  trades: number;
  daily_pnl: number;
  secret?: string;
  account_login?: string;
  account_server?: string;
  consecutive_losses?: number;
  last_lot_size?: number;
  last_trade_close_time?: string;
}

// ------------------------------------------------------------------ //
// Sanitize numeric values to prevent injection via malformed numbers  //
// ------------------------------------------------------------------ //
function sanitizeNumber(
  val: unknown,
  min: number,
  max: number,
  fallback = 0,
): number {
  const n = Number(val);
  if (!isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

// ------------------------------------------------------------------ //
// Compute SHA-256 hex digest of a string (Web Crypto — no deps)      //
// ------------------------------------------------------------------ //
async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ------------------------------------------------------------------ //
// Entry point                                                         //
// ------------------------------------------------------------------ //
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
    );
  }

  // ---------------------------------------------------------------- //
  // Payload size limit — reject bodies over 32 KB                    //
  // ---------------------------------------------------------------- //
  const contentLength = Number(req.headers.get("Content-Length") ?? 0);
  if (contentLength > 32 * 1024) {
    return new Response(
      JSON.stringify({ error: "Payload too large" }),
      { status: 413, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
    );
  }

  try {
    // ---------------------------------------------------------------- //
    // 1. Parse body                                                     //
    // ---------------------------------------------------------------- //
    let payload: EAPayload;
    try {
      payload = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
      );
    }

    // ---------------------------------------------------------------- //
    // 2. Validate required fields + UUID format                         //
    // ---------------------------------------------------------------- //
    if (!payload.user_id || !payload.event) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: user_id, event" }),
        { status: 400, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!UUID_REGEX.test(payload.user_id)) {
      return new Response(
        JSON.stringify({ error: "Invalid user_id format" }),
        { status: 400, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
      );
    }

    const allowedEvents = [
      "heartbeat",
      "connected",
      "hard_killswitch",
      "soft_warning",
      "max_trades",
    ];
    if (!allowedEvents.includes(payload.event)) {
      return new Response(
        JSON.stringify({ error: `Unknown event type: ${payload.event}` }),
        { status: 400, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
      );
    }

    // ---------------------------------------------------------------- //
    // 3. Sanitize numeric inputs                                        //
    // ---------------------------------------------------------------- //
    const equity = sanitizeNumber(payload.equity, -1_000_000, 10_000_000);
    const balance = sanitizeNumber(payload.balance, -1_000_000, 10_000_000);
    const drawdownPct = sanitizeNumber(payload.drawdown_percent, 0, 100);
    const trades = Math.floor(sanitizeNumber(payload.trades, 0, 10_000));
    const dailyPnl = sanitizeNumber(payload.daily_pnl, -1_000_000, 10_000_000);

    // ---------------------------------------------------------------- //
    // 4. Init Supabase with service_role (server-side only)            //
    // ---------------------------------------------------------------- //
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ---------------------------------------------------------------- //
    // 5. Per-user webhook secret validation                             //
    //    DB stores SHA-256(raw_secret). EA sends raw_secret.           //
    //    We hash the incoming secret and compare to the stored hash.   //
    // ---------------------------------------------------------------- //
    const { data: brokerRow } = await supabase
      .from("broker_connections")
      .select("webhook_secret")
      .eq("user_id", payload.user_id)
      .maybeSingle();

    if (brokerRow?.webhook_secret) {
      const incomingHash = await sha256Hex(payload.secret ?? "");
      if (incomingHash !== brokerRow.webhook_secret) {
        console.warn(
          `[ea-webhook] Invalid secret for user_id: ${payload.user_id}`,
        );
        return new Response(
          JSON.stringify({ error: "Unauthorized — invalid secret" }),
          { status: 401, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
        );
      }
    } else {
      // No secret configured yet — allow connection so user can set one up,
      // but log a warning so it's visible in function logs.
      console.warn(
        `[ea-webhook] No webhook_secret configured for user: ${payload.user_id} — set one in the app`,
      );
    }

    // ---------------------------------------------------------------- //
    // 6. Verify the user_id exists to prevent orphan records           //
    // ---------------------------------------------------------------- //
    const { data: profileRow } = await supabase
      .from("profiles")
      .select("id")
      .eq("id", payload.user_id)
      .maybeSingle();

    if (!profileRow) {
      console.warn(
        `[ea-webhook] Unknown user_id: ${payload.user_id}`,
      );
      return new Response(
        JSON.stringify({ error: "Unauthorized — unknown user" }),
        { status: 401, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
      );
    }

    // ---------------------------------------------------------------- //
    // 7. Route event                                                    //
    // ---------------------------------------------------------------- //
    console.log(
      `[ea-webhook] ${payload.event} | user: ${payload.user_id} | drawdown: ${drawdownPct}% | trades: ${trades}`,
    );

    const sanitized = {
      ...payload,
      equity,
      balance,
      drawdown_percent: drawdownPct,
      trades,
      daily_pnl: dailyPnl,
    };

    switch (payload.event) {
      case "heartbeat":
      case "connected":
        await handleHeartbeat(supabase, sanitized);
        break;
      case "hard_killswitch":
        await handleHardKillswitch(supabase, sanitized);
        break;
      case "soft_warning":
        await handleSoftWarning(supabase, sanitized);
        break;
      case "max_trades":
        await handleMaxTrades(supabase, sanitized);
        break;
    }

    return new Response(
      JSON.stringify({
        received: true,
        event: payload.event,
        timestamp: new Date().toISOString(),
      }),
      { status: 200, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[ea-webhook] Internal error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, ...securityHeaders, "Content-Type": "application/json" } },
    );
  }
});

// ------------------------------------------------------------------ //
// HANDLER: heartbeat / connected                                       //
// ------------------------------------------------------------------ //
async function handleHeartbeat(
  supabase: ReturnType<typeof createClient>,
  payload: EAPayload,
) {
  // Sanitize new optional fields
  const equity = sanitizeNumber(payload.equity, -1_000_000, 10_000_000);
  const balance = sanitizeNumber(payload.balance, -1_000_000, 10_000_000);
  const dailyPnl = sanitizeNumber(payload.daily_pnl, -1_000_000, 10_000_000);
  const drawdownPct = sanitizeNumber(payload.drawdown_percent, 0, 100);
  const trades = Math.floor(sanitizeNumber(payload.trades, 0, 10_000));
  const consecutiveLosses = Math.floor(sanitizeNumber(payload.consecutive_losses ?? 0, 0, 100));
  const lastLotSize = sanitizeNumber(payload.last_lot_size ?? 0, 0, 10000);
  const lastTradeCloseTime = typeof payload.last_trade_close_time === 'string' ? payload.last_trade_close_time : null;

  const { error } = await supabase
    .from("broker_connections")
    .upsert(
      {
        user_id: payload.user_id,
        connection_type: "ea_webhook",
        broker: "mt5",
        status: "connected",
        last_sync_at: new Date().toISOString(),
        // webhook_secret is NOT touched here — only rotate_webhook_secret() can update it
        live_data: {
          equity,
          balance,
          daily_pnl: dailyPnl,
          daily_loss_usd: Math.max(0, -dailyPnl),
          daily_loss_pct: balance > 0 ? Math.max(0, (-dailyPnl / balance) * 100) : 0,
          drawdown_pct: drawdownPct,
          open_positions: 0,   // EA doesn't track open positions separately
          trades_today: trades,
          currency: typeof (payload as any).currency === 'string' ? (payload as any).currency : 'USD',
          consecutive_losses: consecutiveLosses,
          last_lot_size: lastLotSize > 0 ? lastLotSize : null,
          last_trade_close_time: lastTradeCloseTime,
          last_update: new Date().toISOString(),
        },
      },
      { onConflict: "user_id", ignoreDuplicates: false },
    );

  if (error) {
    console.error("[ea-webhook] Heartbeat upsert error:", error);
    throw error;
  }
}

// ------------------------------------------------------------------ //
// HANDLER: hard_killswitch                                             //
// ------------------------------------------------------------------ //
async function handleHardKillswitch(
  supabase: ReturnType<typeof createClient>,
  payload: EAPayload,
) {
  const { error: ksError } = await supabase
    .from("killswitch_events")
    .insert({
      user_id: payload.user_id,
      triggered_at: new Date().toISOString(),
      reason: "daily_loss",
      account_mode: "challenge",
      lock_duration_minutes: 480,
      unlocked_early: false,
      unlocked_with_token: false,
    });

  if (ksError) {
    console.error("[ea-webhook] killswitch_events insert error:", ksError);
    throw ksError;
  }

  await supabase
    .from("broker_connections")
    .upsert(
      {
        user_id: payload.user_id,
        connection_type: "ea_webhook",
        broker: "mt5",
        status: "connected",
        last_sync_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );

  console.log(
    `[ea-webhook] HARD KILLSWITCH | user: ${payload.user_id} | drawdown: ${payload.drawdown_percent}%`,
  );
}

// ------------------------------------------------------------------ //
// HANDLER: soft_warning                                                //
// ------------------------------------------------------------------ //
async function handleSoftWarning(
  supabase: ReturnType<typeof createClient>,
  payload: EAPayload,
) {
  const message =
    `Drawdown at ${payload.drawdown_percent.toFixed(2)}% — approaching daily limit. ` +
    `Consider stopping. Current equity: ${payload.equity.toFixed(2)}`;

  const { error } = await supabase
    .from("risk_alerts")
    .insert({
      user_id: payload.user_id,
      alert_type: "soft_warning",
      message,
      equity: payload.equity,
      drawdown_percent: payload.drawdown_percent,
      created_at: new Date().toISOString(),
      dismissed: false,
    });

  if (error) {
    console.error("[ea-webhook] risk_alerts insert error:", error);
    throw error;
  }
}

// ------------------------------------------------------------------ //
// HANDLER: max_trades                                                  //
// ------------------------------------------------------------------ //
async function handleMaxTrades(
  supabase: ReturnType<typeof createClient>,
  payload: EAPayload,
) {
  const { error } = await supabase
    .from("killswitch_events")
    .insert({
      user_id: payload.user_id,
      triggered_at: new Date().toISOString(),
      reason: "max_trades",
      account_mode: "challenge",
      lock_duration_minutes: 480,
      unlocked_early: false,
      unlocked_with_token: false,
    });

  if (error) {
    console.error("[ea-webhook] killswitch_events (max_trades) insert error:", error);
    throw error;
  }

  console.log(
    `[ea-webhook] MAX TRADES | user: ${payload.user_id} | trades: ${payload.trades}`,
  );
}
