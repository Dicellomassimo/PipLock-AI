/**
 * PipLock AI — Edge Function: ai-proxy
 *
 * Proxies AI requests from the Flutter client to Groq, keeping the API key
 * server-side. Verifies the user's Supabase JWT, enforces rate limiting via
 * the check_and_increment_ai_usage RPC, then forwards to Groq.
 *
 * Required env vars (set in Supabase Dashboard → Edge Functions → Secrets):
 *   GROQ_API_KEY      — your Groq API key (server-side secret, never in APK)
 *   SUPABASE_URL      — auto-set by Supabase
 *   SUPABASE_ANON_KEY — auto-set by Supabase
 *
 * Deploy: supabase functions deploy ai-proxy
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

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL_PRIMARY = "openai/gpt-oss-120b";
const MODEL_FALLBACK = "openai/gpt-oss-20b";
const MAX_TOKENS_CAP = 2000;

async function callGroq(
  apiKey: string,
  model: string,
  messages: unknown[],
  temperature: number,
  maxTokens: number,
): Promise<{ ok: boolean; content?: string; status?: number }> {
  let delayMs = 500;
  const maxAttempts = 3;

  for (let i = 0; i < maxAttempts; i++) {
    const res = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ model, messages, temperature, max_tokens: maxTokens }),
      signal: AbortSignal.timeout(20_000),
    });

    if (res.status === 429 || res.status >= 500) {
      if (i < maxAttempts - 1) {
        await new Promise((r) => setTimeout(r, delayMs));
        delayMs *= 2;
        continue;
      }
      return { ok: false, status: res.status };
    }

    if (res.ok) {
      const data = await res.json() as Record<string, unknown>;
      const choices = data["choices"] as Array<Record<string, unknown>> | undefined;
      const content = choices?.[0]?.["message"] as Record<string, unknown> | undefined;
      const text = content?.["content"] as string | undefined;
      if (text) return { ok: true, content: text };
      return { ok: false, status: res.status };
    }

    return { ok: false, status: res.status };
  }

  return { ok: false };
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    );
  }

  // ---------------------------------------------------------------- //
  // 1. Verify user JWT                                                //
  // ---------------------------------------------------------------- //
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid Authorization header" }),
      { status: 401, headers: jsonHeaders },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Create a user-authenticated Supabase client (respects RLS)
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: jsonHeaders },
    );
  }

  // ---------------------------------------------------------------- //
  // 2. Parse request body                                             //
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

  const callType = body["call_type"] as string | undefined;
  const messages = body["messages"] as unknown[] | undefined;
  const temperature = (body["temperature"] as number | undefined) ?? 0.7;
  const maxTokensRaw = (body["max_tokens"] as number | undefined) ?? 400;

  if (!callType || !messages || !Array.isArray(messages)) {
    return new Response(
      JSON.stringify({ error: "Missing required fields: call_type, messages" }),
      { status: 400, headers: jsonHeaders },
    );
  }

  if (callType !== "chat" && callType !== "plan") {
    return new Response(
      JSON.stringify({ error: "call_type must be 'chat' or 'plan'" }),
      { status: 400, headers: jsonHeaders },
    );
  }

  // Cap max_tokens
  const maxTokens = Math.min(maxTokensRaw, MAX_TOKENS_CAP);

  // ---------------------------------------------------------------- //
  // 3. Rate limiting via Supabase RPC (user-authenticated client)    //
  // ---------------------------------------------------------------- //
  try {
    const { data: allowed, error: rpcError } = await userClient.rpc(
      "check_and_increment_ai_usage",
      { call_type: callType },
    );

    if (rpcError) {
      // Log but fail open — don't block users if DB is temporarily down
      console.warn("[ai-proxy] Rate limit RPC error:", rpcError.message);
    } else if (allowed === false) {
      return new Response(
        JSON.stringify({
          error: "rate_limited",
          message: "Daily AI limit reached. Upgrade to Pro for more.",
        }),
        { status: 429, headers: jsonHeaders },
      );
    }
  } catch (e) {
    // Fail open
    console.warn("[ai-proxy] Rate limit check failed:", e);
  }

  // ---------------------------------------------------------------- //
  // 4. Call Groq API (primary model, then fallback)                  //
  // ---------------------------------------------------------------- //
  const groqApiKey = Deno.env.get("GROQ_API_KEY");
  if (!groqApiKey) {
    console.error("[ai-proxy] GROQ_API_KEY env var not set");
    return new Response(
      JSON.stringify({ error: "Service misconfigured" }),
      { status: 500, headers: jsonHeaders },
    );
  }

  // Try primary model
  let result = await callGroq(groqApiKey, MODEL_PRIMARY, messages, temperature, maxTokens);

  // Fallback to secondary model on 404/400 (model not found) or total failure
  if (!result.ok) {
    console.warn(
      `[ai-proxy] Primary model failed (status=${result.status ?? "unknown"}), trying fallback`,
    );
    result = await callGroq(groqApiKey, MODEL_FALLBACK, messages, temperature, maxTokens);
  }

  if (result.ok && result.content) {
    return new Response(
      JSON.stringify({ content: result.content }),
      { status: 200, headers: jsonHeaders },
    );
  }

  console.error("[ai-proxy] Both models failed");
  return new Response(
    JSON.stringify({ error: "AI service temporarily unavailable" }),
    { status: 502, headers: jsonHeaders },
  );
});
