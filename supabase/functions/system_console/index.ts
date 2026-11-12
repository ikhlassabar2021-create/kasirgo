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
const MAX_TOOL_ROUNDS = 4;

const SYSTEM_PROMPT = `Kamu adalah "Console AI", asisten teknis superadmin platform KasirGo.
Tugasmu memeriksa, menjelaskan, memperbaiki, dan mengembangkan sistem KasirGo lewat database Supabase.

Aturan WAJIB:
- Gunakan bahasa Indonesia yang ringkas dan jelas. Jangan pakai kode markup mentah.
- Untuk membaca data gunakan fungsi run_sql dengan mode "read" (hanya SELECT/SHOW/EXPLAIN/WITH).
- Untuk MENGUBAH data (INSERT/UPDATE/DELETE/ALTER/CREATE/DROP) gunakan run_sql dengan mode "write", dan HANYA setelah jelas diperlukan serta ringkas.
- SEBELUM menulis, jelaskan apa yang akan diubah dan mengapa.
- JANGAN sentuh tabel sensitif: vault, auth, supabase_*, storage, pgbouncer.
- Jangan pernah mengekspos nilai secret; tampilkan hanya hint/keterangan.
- Bila butuh data untuk menjawab, jalankan run_sql (read) dulu, lalu simpulkan.
- Tampilkan jawaban sebagai teks dan, bila berguna, tabel ringkas (baris <= 8).

Skema penting (kolom utama):
- outlets: id, name, type, phone, address, owner_id, is_active
- user_roles: user_id, outlet_id, role, display_name
- products: id, outlet_id, name, base_price, stock, is_service, is_published
- transactions: id, outlet_id, final_amount, payment_method, payment_status, order_status, created_at
- supporters: id, outlet_id, status, start_date, end_date
- customers: id, outlet_id, name, phone
- platform_integrations: config JSONB untuk payment gateway/PPOB/dll.
- system_smtp_config: pengaturan SMTP email.
- system_api_configs: konfigurasi API AI (base_url/model/kunci di Vault).`;

const TOOLS: Json[] = [
  {
    type: "function",
    function: {
      name: "run_sql",
      description:
        "Jalankan SATU pernyataan SQL di database KasirGo. mode 'read' hanya untuk SELECT/SHOW/EXPLAIN/WITH; mode 'write' untuk DML/DDL (mengubah data).",
      parameters: {
        type: "object",
        properties: {
          sql: { type: "string", description: "Satu pernyataan SQL." },
          mode: { type: "string", enum: ["read", "write"], description: "read untuk hanya baca, write untuk mengubah." },
        },
        required: ["sql", "mode"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "list_tables",
      description: "Daftar nama tabel public yang ada di database.",
      parameters: { type: "object", properties: {} },
    },
  },
];

async function callOnce(cfg: Json, apiKey: string, messages: Json[], tools: Json[] | null) {
  let base = String(cfg.base_url ?? "").replace(/\/+$/, "");
  const url = base.includes("/chat/completions") ? base : `${base}/chat/completions`;
  const body: Json = {
    model: cfg.model,
    messages,
    temperature: 0.4,
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

type ProviderEntry = { base_url: string; model: string; key: string };

async function providersFromSysCfg(admin: ReturnType<typeof createClient>, sysCfg: Json | null): Promise<ProviderEntry[]> {
  if (!sysCfg?.base_url || !sysCfg?.model_name) return [];
  const slots: Array<{ secretId: unknown; base: string | null; model: string | null }> = [
    { secretId: sysCfg.primary_secret_id, base: sysCfg.base_url, model: sysCfg.model_name },
    {
      secretId: sysCfg.backup1_secret_id,
      base: (sysCfg.backup1_base_url as string | null) ?? sysCfg.base_url,
      model: (sysCfg.backup1_model_name as string | null) ?? sysCfg.model_name,
    },
    {
      secretId: sysCfg.backup2_secret_id,
      base: (sysCfg.backup2_base_url as string | null) ?? sysCfg.base_url,
      model: (sysCfg.backup2_model_name as string | null) ?? sysCfg.model_name,
    },
  ];
  const out: ProviderEntry[] = [];
  for (const s of slots) {
    if (!s.secretId || !s.base || !s.model) continue;
    const { data: secret, error } = await admin.rpc("vault_read_secret", { p_secret_id: s.secretId });
    if (error) continue;
    const key = String(secret ?? "").trim();
    if (key) out.push({ base_url: String(s.base), model: String(s.model), key });
  }
  return out;
}

async function completionsWithFallback(
  providers: ProviderEntry[],
  messages: Json[],
  tools: Json[] | null,
  temperature: number,
  maxTokens: number,
) {
  if (!providers.length) return { ok: false, errors: ["Tidak ada kunci API AI yang diatur superadmin."] };
  const errors: string[] = [];
  for (let i = 0; i < providers.length; i++) {
    const p = providers[i];
    try {
      const data = await callOnce(
        { base_url: p.base_url, model: p.model, temperature, max_tokens: maxTokens },
        p.key,
        messages,
        tools,
      );
      return { ok: true, data, key_used: i };
    } catch (e) {
      errors.push(`${i === 0 ? "primary" : `backup_${i}`}: ${String((e as Error)?.message ?? e).slice(0, 140)}`);
    }
  }
  return { ok: false, errors };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ success: false, message: "Unauthorized" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return json({ success: false, message: "Unauthorized" }, 401);
    const { data: adminFlag } = await userClient.rpc("is_platform_admin");
    if (!adminFlag) return json({ success: false, message: "Forbidden" }, 403);

    const actorId = userData.user.id;
    const admin = createClient(supabaseUrl, serviceKey);

    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "chat");

    // ---- daftar sesi ----
    if (action === "list") {
      const { data: sessions, error } = await userClient
        .from("console_ai_sessions")
        .select("id, title, created_at, updated_at")
        .order("updated_at", { ascending: false })
        .limit(30);
      if (error) throw new Error(error.message);
      return json({ success: true, sessions });
    }

    // ---- riwayat pesan ----
    if (action === "history") {
      const sessionId = String(body.session_id ?? "");
      if (!sessionId) return json({ success: false, message: "session_id wajib." }, 400);
      const { data: messages, error } = await userClient
        .from("console_ai_messages")
        .select("role, content, tool_calls, created_at")
        .eq("session_id", sessionId)
        .order("created_at", { ascending: true });
      if (error) throw new Error(error.message);
      return json({ success: true, messages });
    }

    // ---- hapus sesi ----
    if (action === "delete") {
      const sessionId = String(body.session_id ?? "");
      if (!sessionId) return json({ success: false, message: "session_id wajib." }, 400);
      const { error } = await userClient.from("console_ai_sessions").delete().eq("id", sessionId);
      if (error) throw new Error(error.message);
      return json({ success: true });
    }

    // ---- chat utama ----
    const sessionId = String(body.session_id ?? "");
    const userText = String(body.message ?? "").trim();
    if (!userText) return json({ success: false, message: "message wajib." }, 400);

    const { data: sysCfg } = await admin
      .from("system_api_configs")
      .select("*")
      .eq("is_active", true)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const providers = await providersFromSysCfg(admin, sysCfg);
    if (!providers.length) {
      return json({
        success: false,
        message: "Konfigurasi API AI belum diatur superadmin (Control Plane → Dokter Bisnis AI → Konfigurasi API AI).",
      }, 503);
    }

    // Muat riwayat (maks 20 pesan terakhir) untuk konteks.
    let history: Json[] = [];
    if (sessionId) {
      const { data: prev } = await userClient
        .from("console_ai_messages")
        .select("role, content")
        .eq("session_id", sessionId)
        .order("created_at", { ascending: false })
        .limit(20);
      history = ((prev ?? []) as Json[]).reverse().map((m) => ({ role: m.role, content: m.content }));
    }

    const messages: Json[] = [
      { role: "system", content: SYSTEM_PROMPT },
      ...history.filter((m) => m.role === "user" || m.role === "assistant"),
      { role: "user", content: userText },
    ];

    const toolLog: Json[] = [];
    let finalContent = "";

    for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
      const r = await completionsWithFallback(providers, messages, TOOLS, 0.4, 4000);
      if (!r.ok) {
        return json({ success: false, message: (r.errors ?? []).join(" | ") }, 502);
      }
      const msg = r.data?.choices?.[0]?.message ?? {};
      const toolCalls = msg.tool_calls ?? [];
      if (!toolCalls.length) {
        finalContent = String(msg.content ?? "");
        if (!finalContent.trim()) {
          finalContent = "Saya tidak menghasilkan jawaban. Coba ulangi atau perjelas pertanyaan Anda.";
        }
        messages.push({ role: "assistant", content: finalContent });
        break;
      }

      messages.push({
        role: "assistant",
        content: msg.content ?? null,
        tool_calls: toolCalls,
      });

      for (const tc of toolCalls) {
        const fnName = String(tc.function?.name ?? "");
        let args: Json = {};
        try {
          args = JSON.parse(String(tc.function?.arguments ?? "{}"));
        } catch { /* biarkan kosong */ }

        let toolResult: Json;
        if (fnName === "list_tables") {
          const { data, error } = await admin.rpc("console_ai_list_tables");
          if (error) toolResult = { ok: false, error: error.message };
          else toolResult = { ok: true, tables: data };
        } else if (fnName === "run_sql") {
          const sql = String(args.sql ?? "");
          const mode = args.mode === "write" ? "write" : "read";
          if (!sql) toolResult = { ok: false, error: "sql wajib." };
          else {
            // Panggil lewat userClient (JWT superadmin) supaya is_platform_admin()
            // melihat auth.uid() aktor, bukan service role.
            const { data, error } = await userClient.rpc("console_ai_run_sql", { p_sql: sql, p_mode: mode });
            if (error) toolResult = { ok: false, error: error.message };
            else toolResult = data as Json;
          }
        } else {
          toolResult = { ok: false, error: `Tool tidak dikenal: ${fnName}` };
        }

        toolLog.push({ name: fnName, mode: args?.mode ?? null, sql: String(args?.sql ?? "").slice(0, 500), ok: toolResult?.ok !== false });
        messages.push({
          role: "tool",
          tool_call_id: tc.id ?? `call_${round}`,
          content: JSON.stringify(toolResult),
        });
      }
    }

    if (!finalContent) {
      finalContent = "Selesai memproses, namun tidak ada kesimpulan. Lihat hasil tool di atas atau coba lagi.";
    }

    // Persistensi sesi + pesan.
    let sid = sessionId;
    if (!sid) {
      const title = userText.slice(0, 60);
      const { data: created, error } = await userClient
        .from("console_ai_sessions")
        .insert({ actor_id: actorId, title })
        .select("id")
        .single();
      if (!error && created) sid = created.id;
    } else {
      await userClient.from("console_ai_sessions").update({ updated_at: new Date().toISOString() }).eq("id", sid);
    }

    if (sid) {
      await userClient.from("console_ai_messages").insert([
        { session_id: sid, role: "user", content: userText },
        { session_id: sid, role: "assistant", content: finalContent, tool_calls: toolLog.length ? toolLog : null },
      ]);
    }

    return json({ success: true, session_id: sid, reply: finalContent, tool_calls: toolLog });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});