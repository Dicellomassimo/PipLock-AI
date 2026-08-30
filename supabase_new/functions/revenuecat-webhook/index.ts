/**
 * PipLock AI — Edge Function: revenuecat-webhook
 *
 * Receives RevenueCat subscription events and updates subscription_tier
 * in the profiles table via service_role (bypasses RLS).
 *
 * This is the ONLY way subscription_tier can change — never from the client.
 * The RLS policy on profiles blocks client-side updates to subscription_tier.
 *
 * Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
 *   SUPABASE_URL              — auto-set
 *   SUPABASE_SERVICE_ROLE_KEY — auto-set
 *   REVENUECAT_WEBHOOK_SECRET — set in RevenueCat Dashboard → Webhooks → Shared Secret
 *
 * Deploy: supabase functions deploy revenuecat-webhook
 *
 * RevenueCat setup:
 *   Dashboard → Webhooks → Add Endpoint
 *   URL: https://<project>.supabase.co/functions/v1/revenuecat-webhook
 *   Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const securityHeaders = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
};

const jsonHeaders = {
  ...corsHeaders,
  ...securityHeaders,
  "Content-Type": "application/json",
};

// RevenueCat event types that activate/deactivate Pro
const PRO_ACTIVE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
]);

const PRO_INACTIVE_EVENTS = new Set([
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
  "SUBSCRIBER_ALIAS", // no tier change needed
]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    );
  }

  // Payload size limit — 32 KB max
  const contentLength = Number(req.headers.get("Content-Length") ?? 0);
  if (contentLength > 32 * 1024) {
    return new Response(
      JSON.stringify({ error: "Payload too large" }),
      { status: 413, headers: jsonHeaders },
    );
  }

  // ---------------------------------------------------------------- //
  // 1. Verify Authorization header (shared secret)                    //
  //    RevenueCat sends: Authorization: Bearer <shared_secret>        //
  // ---------------------------------------------------------------- //
  const webhookSecret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
  if (webhookSecret.length > 0) {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (authHeader !== `Bearer ${webhookSecret}`) {
      console.warn("[revenuecat-webhook] Invalid Authorization header");
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: jsonHeaders },
      );
    }
  } else {
    console.warn(
      "[revenuecat-webhook] REVENUECAT_WEBHOOK_SECRET not set — skipping auth check",
    );
  }

  // ---------------------------------------------------------------- //
  // 2. Parse body                                                     //
  // ---------------------------------------------------------------- //
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: jsonHeaders },
    );
  }

  const event = body["event"] as Record<string, unknown> | undefined;
  if (!event) {
    return new Response(
      JSON.stringify({ error: "Missing event field" }),
      { status: 400, headers: jsonHeaders },
    );
  }

  const eventType = event["type"] as string | undefined;
  // app_user_id = Supabase user UUID (set when configuring RevenueCat SDK)
  const appUserId = event["app_user_id"] as string | undefined;

  if (!eventType || !appUserId) {
    return new Response(
      JSON.stringify({ error: "Missing event.type or event.app_user_id" }),
      { status: 400, headers: jsonHeaders },
    );
  }

  // Validate UUID format
  const UUID_REGEX =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!UUID_REGEX.test(appUserId)) {
    return new Response(
      JSON.stringify({ error: "Invalid app_user_id format" }),
      { status: 400, headers: jsonHeaders },
    );
  }

  console.log(
    `[revenuecat-webhook] Event: ${eventType} | user: ${appUserId}`,
  );

  // ---------------------------------------------------------------- //
  // 3. Determine new subscription tier                                //
  // ---------------------------------------------------------------- //
  let newTier: string | null = null;

  if (PRO_ACTIVE_EVENTS.has(eventType)) {
    newTier = "pro";
  } else if (PRO_INACTIVE_EVENTS.has(eventType)) {
    newTier = "free";
  } else {
    // Unknown event — log and acknowledge without changing tier
    console.log(`[revenuecat-webhook] Unhandled event type: ${eventType}`);
    return new Response(
      JSON.stringify({ received: true, action: "ignored", event: eventType }),
      { status: 200, headers: jsonHeaders },
    );
  }

  // ---------------------------------------------------------------- //
  // 4. Update subscription_tier via service_role (bypasses RLS)      //
  //    This is the ONLY legitimate path for tier changes.            //
  // ---------------------------------------------------------------- //
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { error } = await supabase
    .from("profiles")
    .update({ subscription_tier: newTier })
    .eq("id", appUserId);

  if (error) {
    console.error("[revenuecat-webhook] DB update error:", error.message);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: jsonHeaders },
    );
  }

  console.log(
    `[revenuecat-webhook] Updated user ${appUserId} → ${newTier} (event: ${eventType})`,
  );

  return new Response(
    JSON.stringify({
      received: true,
      event: eventType,
      user: appUserId,
      tier: newTier,
    }),
    { status: 200, headers: jsonHeaders },
  );
});
