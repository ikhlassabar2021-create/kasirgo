import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });

type Json = Record<string, any>;

const LLM_TIMEOUT_MS = Number(Deno.env.get("DOCTOR_LLM_TIMEOUT_MS") ?? 45000) || 45000;

async function callOnce(
  cfg: Json,
  apiKey: string,
  messages: Json[],
  tools: Json[] | null,
) {
  let base = String(cfg.base_url ?? "").replace(/\/+$/, "");
  const url = base.includes("/chat/completions") ? base : `${base}/chat/completions`;
  const body: Json = {
    model: cfg.model,
    messages,
    temperature: Number(cfg.temperature ?? 0.7),
    max_tokens: Number(cfg.max_tokens ?? 4000) || 4000,
  };
  if (tools && tools.length) {
    body.tools = tools;
    body.tool_choice = "auto";
  }
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), LLM_TIMEOUT_MS);
  let resp: Response;
  try {
    resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
  } catch (e) {
    if ((e as Error)?.name === "AbortError") {
      throw new Error(`Provider AI timeout (>${Math.round(LLM_TIMEOUT_MS / 1000)} detik).`);
    }
    throw e;
  } finally {
    clearTimeout(timer);
  }
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(data?.error?.message ?? data?.message ?? `LLM HTTP ${resp.status}`);
  }
  return data;
}

// Fallback otomatis: primary -> backup_1 -> backup_2 (base_url & model sama).
async function completionsWithFallback(
  sysCfg: Json,
  messages: Json[],
  tools: Json[] | null,
  temperature: number,
  maxTokens: number,
) {
  const keys = [sysCfg?.primary_key, sysCfg?.backup_key_1, sysCfg?.backup_key_2]
    .filter((k) => k && String(k).trim());
  if (!keys.length) return { ok: false, errors: ["Tidak ada kunci API yang diatur."] };

  const cfg: Json = {
    base_url: sysCfg.base_url,
    model: sysCfg.model_name,
    temperature,
    max_tokens: maxTokens,
  };

  const errors: string[] = [];
  for (let i = 0; i < keys.length; i++) {
    try {
      const data = await callOnce(cfg, String(keys[i]), messages, tools);
      return { ok: true, data, key_used: i };
    } catch (e) {
      const label = i === 0 ? "primary" : `backup_${i}`;
      errors.push(`${label}: ${String((e as Error)?.message ?? e).slice(0, 140)}`);
    }
  }
  return { ok: false, errors };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const authHeader = req.headers.get("Authorization") ?? "";
    // Panggilan internal antar Edge Function memakai service role key.
    const isService = authHeader === `Bearer ${serviceKey}` && !!serviceKey;

    const body = await req.json().catch(() => ({}));
    const mode = String(body.mode ?? "completions");

    let isPlatformAdmin = false;
    if (!isService) {
      if (!authHeader.startsWith("Bearer ")) {
        return json({ success: false, message: "Unauthorized" }, 401);
      }
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userErr } = await userClient.auth.getUser();
      if (userErr || !userData?.user) return json({ success: false, message: "Unauthorized" }, 401);
      const { data: adminFlag } = await userClient.rpc("is_platform_admin");
      isPlatformAdmin = !!adminFlag;
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: sysCfg } = await admin
      .from("system_api_configs")
      .select("*")
      .eq("is_active", true)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (mode === "test") {
      if (!isPlatformAdmin) return json({ success: false, message: "Forbidden" }, 403);
      if (!sysCfg?.base_url || !sysCfg?.model_name) {
        return json({ success: true, ok: false, message: "Lengkapi Base URL, Model, dan Primary Key." });
      }
      const r = await completionsWithFallback(
        sysCfg,
        [{ role: "user", content: "Balas satu kata: ok" }],
        null,
        0,
        16,
      );
      if (r.ok) {
        const sample = String(r.data?.choices?.[0]?.message?.content ?? "").slice(0, 120);
        return json({ success: true, ok: true, message: "Koneksi provider berhasil.", sample, key_used: r.key_used });
      }
      return json({ success: true, ok: false, message: (r.errors ?? []).join(" | ") });
    }

    // Completions (proxy). Klien ter-autentikasi atau panggilan internal service.
    if (!isService && !isPlatformAdmin && !authHeader) {
      return json({ success: false, message: "Unauthorized" }, 401);
    }
    if (!sysCfg?.base_url || !sysCfg?.model_name) {
      return json({ success: false, message: "Konfigurasi API AI belum diatur superadmin." }, 503);
    }
    const messages = Array.isArray(body.messages) ? (body.messages as Json[]) : [];
    if (!messages.length) return json({ success: false, message: "messages wajib." }, 400);
    const tools = Array.isArray(body.tools) ? (body.tools as Json[]) : null;
    const temperature = Number(body.temperature ?? 0.7);
    const maxTokens = Number(body.max_tokens ?? 4000) || 4000;

    const r = await completionsWithFallback(sysCfg, messages, tools, temperature, maxTokens);
    if (r.ok) {
      return json({ success: true, ok: true, data: r.data, key_used: r.key_used });
    }
    return json({ success: false, ok: false, errors: r.errors }, 502);
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});