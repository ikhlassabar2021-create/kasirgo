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

const DISCLAIMER = "Ini saran AI, bukan jaminan. Keputusan tetap di tangan Anda.";

type Json = Record<string, any>;

const FORBIDDEN = /\b(politik|presiden|pemilu|agama|sara|khilafah|pinjol ilegal|judi|narkoba)\b/i;

function daysAgo(n: number) {
  return new Date(Date.now() - n * 86400000).toISOString();
}

function dayKey(iso: string) {
  return iso.slice(0, 10);
}

async function loadSnapshot(admin: any, outletId: string) {
  const [outletRes, prodRes, trxRes] = await Promise.all([
    admin.from("outlets").select("name, type, created_at").eq("id", outletId).maybeSingle(),
    admin.from("products").select("id, name, stock, base_price, category, min_stock_alert").eq("outlet_id", outletId),
    admin
      .from("transactions")
      .select("id, final_amount, payment_status, status, created_at")
      .eq("outlet_id", outletId)
      .gte("created_at", daysAgo(30)),
  ]);
  const products = prodRes.data ?? [];
  const trx = trxRes.data ?? [];
  const paid = trx.filter((t: Json) => String(t.payment_status ?? "") === "paid");
  const revenue30 = paid.reduce((s: number, t: Json) => s + Number(t.final_amount ?? 0), 0);
  const today = dayKey(new Date().toISOString());
  const revenueToday = paid
    .filter((t: Json) => dayKey(String(t.created_at)) === today)
    .reduce((s: number, t: Json) => s + Number(t.final_amount ?? 0), 0);
  const lowStock = products.filter((p: Json) => Number(p.stock ?? 0) <= Number(p.min_stock_alert ?? 5));
  const ageDays = outletRes.data?.created_at
    ? Math.floor((Date.now() - new Date(outletRes.data.created_at).getTime()) / 86400000)
    : null;
  return {
    outlet_name: outletRes.data?.name ?? null,
    outlet_type: outletRes.data?.type ?? null,
    business_age_days: ageDays,
    product_count: products.length,
    total_stock: products.reduce((s: number, p: Json) => s + Number(p.stock ?? 0), 0),
    low_stock_count: lowStock.length,
    low_stock: lowStock.slice(0, 10).map((p: Json) => ({ name: p.name, stock: p.stock })),
    trx_30d: paid.length,
    revenue_30d: revenue30,
    revenue_today: revenueToday,
    avg_ticket: paid.length ? Math.round(revenue30 / paid.length) : 0,
  };
}

async function toolGetSnapshot(admin: any, outletId: string) {
  return await loadSnapshot(admin, outletId);
}

async function toolSalesTrend(admin: any, outletId: string, days = 14) {
  const { data } = await admin
    .from("transactions")
    .select("final_amount, payment_status, created_at")
    .eq("outlet_id", outletId)
    .gte("created_at", daysAgo(days));
  const map: Record<string, number> = {};
  for (const t of data ?? []) {
    if (String(t.payment_status ?? "") !== "paid") continue;
    const k = dayKey(String(t.created_at));
    map[k] = (map[k] ?? 0) + Number(t.final_amount ?? 0);
  }
  return Object.entries(map)
    .sort()
    .map(([date, total]) => ({ date, total }));
}

async function toolLowStock(admin: any, outletId: string, threshold = 5) {
  const { data } = await admin
    .from("products")
    .select("name, stock, unit, min_stock_alert")
    .eq("outlet_id", outletId)
    .lte("stock", threshold)
    .order("stock", { ascending: true })
    .limit(20);
  return data ?? [];
}

async function toolSlowProducts(admin: any, outletId: string, days = 14) {
  const { data: trx } = await admin
    .from("transactions")
    .select("id")
    .eq("outlet_id", outletId)
    .gte("created_at", daysAgo(days));
  const ids = (trx ?? []).map((t: Json) => t.id);
  const sold = new Set<string>();
  if (ids.length) {
    const { data: items } = await admin
      .from("transaction_items")
      .select("product_id")
      .in("transaction_id", ids);
    for (const it of items ?? []) if (it.product_id) sold.add(String(it.product_id));
  }
  const { data: prods } = await admin
    .from("products")
    .select("id, name, stock, base_price")
    .eq("outlet_id", outletId)
    .limit(200);
  return (prods ?? [])
    .filter((p: Json) => !sold.has(String(p.id)))
    .slice(0, 20)
    .map((p: Json) => ({ name: p.name, stock: p.stock, price: p.base_price }));
}

async function toolCashflow(admin: any, outletId: string, days = 30) {
  const { data } = await admin
    .from("transactions")
    .select("final_amount, payment_status")
    .eq("outlet_id", outletId)
    .gte("created_at", daysAgo(days));
  const paid = (data ?? []).filter((t: Json) => String(t.payment_status ?? "") === "paid");
  const revenue = paid.reduce((s: number, t: Json) => s + Number(t.final_amount ?? 0), 0);
  return {
    days,
    revenue,
    trx_count: paid.length,
    avg_ticket: paid.length ? Math.round(revenue / paid.length) : 0,
  };
}

const TOOLS = [
  {
    type: "function",
    function: {
      name: "get_business_snapshot",
      description: "Ringkasan bisnis: jumlah produk, stok, penjualan 30 hari, omzet hari ini, umur usaha.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "get_sales_trend",
      description: "Tren omzet harian N hari terakhir.",
      parameters: { type: "object", properties: { days: { type: "integer" } } },
    },
  },
  {
    type: "function",
    function: {
      name: "get_low_stock",
      description: "Daftar produk stok menipis.",
      parameters: { type: "object", properties: { threshold: { type: "integer" } } },
    },
  },
  {
    type: "function",
    function: {
      name: "list_slow_products",
      description: "Produk yang tidak terjual dalam N hari (stok mati).",
      parameters: { type: "object", properties: { days: { type: "integer" } } },
    },
  },
  {
    type: "function",
    function: {
      name: "get_cashflow",
      description: "Arus kas: total omzet & rata-rata transaksi N hari.",
      parameters: { type: "object", properties: { days: { type: "integer" } } },
    },
  },
  {
    type: "function",
    function: {
      name: "recall_memory",
      description: "Baca memori jangka panjang & kasus terbuka outlet.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "save_memory",
      description: "Simpan vonis/resep/lesson ke memori outlet.",
      parameters: {
        type: "object",
        properties: {
          kind: { type: "string", enum: ["diagnosis", "prescription", "result", "lesson", "fact"] },
          title: { type: "string" },
          content: { type: "string" },
          status: { type: "string", enum: ["open", "achieved", "failed"] },
        },
        required: ["kind", "title"],
      },
    },
  },
];

async function execTool(admin: any, outletId: string, name: string, args: Json) {
  switch (name) {
    case "get_business_snapshot":
      return await toolGetSnapshot(admin, outletId);
    case "get_sales_trend":
      return await toolSalesTrend(admin, outletId, Number(args?.days) || 14);
    case "get_low_stock":
      return await toolLowStock(admin, outletId, Number(args?.threshold) || 5);
    case "list_slow_products":
      return await toolSlowProducts(admin, outletId, Number(args?.days) || 14);
    case "get_cashflow":
      return await toolCashflow(admin, outletId, Number(args?.days) || 30);
    case "recall_memory": {
      const { data } = await admin
        .from("doctor_memory")
        .select("kind, title, content, status, lesson, due_at")
        .eq("outlet_id", outletId)
        .order("created_at", { ascending: false })
        .limit(20);
      return data ?? [];
    }
    case "save_memory": {
      const { data } = await admin
        .from("doctor_memory")
        .insert({
          outlet_id: outletId,
          kind: String(args?.kind ?? "fact"),
          title: String(args?.title ?? "").slice(0, 200),
          content: String(args?.content ?? ""),
          status: String(args?.status ?? "open"),
        })
        .select("id")
        .maybeSingle();
      return { saved: true, id: data?.id ?? null };
    }
    default:
      return { error: `unknown_tool:${name}` };
  }
}

function buildSystem(cfg: Json, snap: Json, profile: Json | null, openCases: Json[], history: Json[]) {
  const roleMap = cfg.role_outlet ?? {};
  const roleText = roleMap?.[snap.outlet_type] ?? "Fokus pada perbaikan omzet dan arus kas UMKM.";
  const guard = Array.isArray(cfg.guardrails) ? cfg.guardrails.join("\n- ") : "";
  const openText = openCases.length
    ? openCases.map((m) => `- [${m.kind}/${m.status}] ${m.title}: ${m.content ?? ""}`).join("\n")
    : "(belum ada kasus terbuka)";
  const histText = history.length
    ? history.map((m) => `${m.role}: ${String(m.content ?? "").slice(0, 300)}`).join("\n")
    : "(sesi baru)";
  return `${cfg.prompt_utama ?? "Kamu adalah Dokter Bisnis KasirGo."}

PERAN UNTUK TIPE OUTLET (${snap.outlet_type ?? "umum"}):
${roleText}

GUARDRAILS:
- ${guard}

FASE: ${profile?.phase ?? "A"} | Umur usaha: ${snap.business_age_days ?? "?"} hari
MEMORI JANGKA PANJANG:
${profile?.memory_digest ?? "(belum ada)"}
KASUS TERBUKA:
${openText}

SNAPSHOT BISNIS (ringkas):
${JSON.stringify(snap)}

RIWAYAT SINGKAT:
${histText}

ATURAN OUTPUT:
- Balas HANYA JSON valid tanpa markdown fence, bentuk:
  {"reply":"teks singkat ramah gaptek","blocks":[...],"phase":"A|B|C","memory":{"kind":"diagnosis|prescription|lesson","title":"...","content":"..."}}
- blocks berisi item {type} salah satu:
  {"type":"text","text":"..."},
  {"type":"card","tone":"info|warning|success|danger","title":"...","body":"..."},
  {"type":"gauge","label":"Skor Kesehatan Usaha","value":0-100,"hint":"..."},
  {"type":"checklist","title":"Peta Resep","items":[{"text":"...","done":false}]},
  {"type":"choices","prompt":"...","options":[{"label":"...","value":"..."}]},
  {"type":"action","label":"...","action_key":"sidak_bos|dynamic_pricing|bundling|cross_sell|referral|wa_marketing|progress_tracker"}
- Bahasa Indonesia sederhana, minim istilah teknis, langkah kecil yang bisa dikerjakan.
- Selalu akhiri dengan disclaimer singkat "saran AI".`;
}

function extractJson(text: string): Json | null {
  const t = String(text ?? "").trim();
  const cleaned = t.replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const s = cleaned.indexOf("{");
    const e = cleaned.lastIndexOf("}");
    if (s >= 0 && e > s) {
      try {
        return JSON.parse(cleaned.slice(s, e + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

function fallbackBlocks(snap: Json, reason: string) {
  const score = Math.max(
    0,
    Math.min(100, 40 + Math.min(30, snap.trx_30d ?? 0) - Math.min(20, (snap.low_stock_count ?? 0) * 2)),
  );
  const items: Json[] = [];
  if ((snap.low_stock_count ?? 0) > 0) {
    items.push({ text: `Segera isi ulang ${snap.low_stock_count} produk yang stoknya menipis`, done: false });
  }
  items.push({ text: "Catat penjualan hari ini di aplikasi agar Dokter bisa menganalisa", done: false });
  items.push({ text: "Tawarkan produk paling laku ke pelanggan langganan", done: false });
  return [
    { type: "card", tone: "warning", title: "Otak penuh belum aktif", body: reason },
    { type: "gauge", label: "Skor Kesehatan Usaha (perkiraan)", value: score, hint: "Berdasarkan data aplikasi" },
    { type: "checklist", title: "Langkah awal", items },
    { type: "action", label: "Aktifkan Program Pendukung", action_key: "upgrade" },
  ];
}

async function callLlm(cfg: Json, messages: Json[], useTools: boolean) {
  let base = String(cfg.base_url ?? "").replace(/\/+$/, "");
  const url = base.includes("/chat/completions") ? base : `${base}/chat/completions`;
  const body: Json = {
    model: cfg.model,
    messages,
    temperature: Number(cfg.temperature ?? 0.7),
    max_tokens: Number(cfg.max_tokens ?? 800),
  };
  if (useTools) {
    body.tools = TOOLS;
    body.tool_choice = "auto";
  }
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${cfg.api_key}` },
    body: JSON.stringify(body),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data?.error?.message ?? data?.message ?? `LLM HTTP ${resp.status}`);
  return data;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ success: false, message: "Unauthorized" }, 401);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return json({ success: false, message: "Unauthorized" }, 401);
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const outletId = String(body.outlet_id ?? "");
    const message = String(body.message ?? "").slice(0, 4000);
    let conversationId = body.conversation_id ? String(body.conversation_id) : null;
    const mode = String(body.mode ?? "chat");
    if (!outletId) return json({ success: false, message: "outlet_id wajib." }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: owned } = await admin
      .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
    let isMember = !!owned;
    if (!isMember) {
      const { data: role } = await admin
        .from("user_roles").select("id").eq("outlet_id", outletId).eq("user_id", userId).maybeSingle();
      isMember = !!role;
    }
    if (!isMember) return json({ success: false, message: "Forbidden" }, 403);

    // Gating: butuh Program Pendukung/trial aktif sebelum memanggil LLM.
    const { data: active } = await admin.rpc("outlet_supporter_active", { target_outlet: outletId });
    if (!active) {
      return json({
        success: true,
        gated: true,
        conversation_id: conversationId,
        blocks: [
          { type: "card", tone: "warning", title: "Dokter Bisnis terkunci", body: "Aktifkan Program Pendukung Rp50.000/bulan untuk berkonsultasi dengan Dokter Bisnis AI." },
          { type: "action", label: "Aktifkan Program Pendukung", action_key: "upgrade" },
        ],
        disclaimer: DISCLAIMER,
      });
    }

    if (FORBIDDEN.test(message)) {
      return json({
        success: true,
        conversation_id: conversationId,
        blocks: [
          { type: "card", tone: "warning", title: "Maaf", body: "Dokter Bisnis hanya membahas usaha Anda (omzet, stok, promosi). Yuk tanya soal bisnis." },
        ],
        disclaimer: DISCLAIMER,
      });
    }

    // Provider: override outlet -> fallback global.
    const { data: override } = await admin
      .from("outlet_ai_configs")
      .select("provider, base_url, api_key_enc, model, temperature, max_tokens, is_active")
      .eq("outlet_id", outletId)
      .maybeSingle();
    const { data: pcfg } = await admin
      .from("platform_configs").select("value").eq("key", "business_doctor").maybeSingle();
    const globalCfg: Json = pcfg?.value ?? {};
    const provider = override?.is_active && override?.api_key_enc
      ? {
        base_url: override.base_url,
        api_key: override.api_key_enc,
        model: override.model,
        temperature: override.temperature,
        max_tokens: override.max_tokens,
      }
      : {
        base_url: globalCfg?.provider_default?.base_url,
        api_key: globalCfg?.provider_default?.api_key,
        model: globalCfg?.provider_default?.model,
        temperature: globalCfg?.provider_default?.temperature,
        max_tokens: globalCfg?.provider_default?.max_tokens,
      };

    const snap = await loadSnapshot(admin, outletId);
    const { data: profile } = await admin
      .from("doctor_outlet_profile").select("*").eq("outlet_id", outletId).maybeSingle();
    const { data: openCases } = await admin
      .from("doctor_memory").select("kind, title, content, status")
      .eq("outlet_id", outletId).eq("status", "open").limit(10);

    // Conversation.
    if (!conversationId) {
      const title = message ? message.slice(0, 60) : `Konsultasi ${new Date().toLocaleDateString("id-ID")}`;
      const { data: conv } = await admin
        .from("doctor_conversations")
        .insert({ outlet_id: outletId, user_id: userId, title, phase: profile?.phase ?? "A", status: "aktif" })
        .select("id, phase")
        .maybeSingle();
      conversationId = conv?.id ?? null;
    }
    if (conversationId && message) {
      await admin.from("doctor_messages").insert({
        conversation_id: conversationId, outlet_id: outletId, role: "user", content: message,
      });
    }

    const { data: history } = await admin
      .from("doctor_messages").select("role, content")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true }).limit(12);

    const messages: Json[] = [
      { role: "system", content: buildSystem(globalCfg, snap, profile, openCases ?? [], history ?? []) },
      { role: "user", content: message || "Mulai diagnosa usaha saya." },
    ];

    let parsed: Json | null = null;
    let fallbackReason = "";
    let tokens = 0;

    if (!provider.base_url || !provider.api_key || !provider.model) {
      fallbackReason = "Provider AI belum diatur superadmin. Sementara pakai analisa lokal.";
    } else {
      try {
        let data: Json;
        try {
          data = await callLlm(provider, messages, true);
        } catch (_e) {
          data = await callLlm(provider, messages, false);
        }
        // Tool loop (maks 2 putaran).
        for (let round = 0; round < 2; round++) {
          const choice = data?.choices?.[0];
          tokens += Number(data?.usage?.total_tokens ?? 0);
          const toolCalls = choice?.message?.tool_calls ?? [];
          if (!toolCalls.length) break;
          messages.push(choice.message);
          for (const tc of toolCalls) {
            let args: Json = {};
            try { args = JSON.parse(tc?.function?.arguments ?? "{}"); } catch { args = {}; }
            const result = await execTool(admin, outletId, tc?.function?.name, args);
            messages.push({ role: "tool", tool_call_id: tc.id, content: JSON.stringify(result) });
          }
          data = await callLlm(provider, messages, true);
        }
        parsed = extractJson(data?.choices?.[0]?.message?.content ?? "");
        if (!parsed) parsed = { reply: String(data?.choices?.[0]?.message?.content ?? ""), blocks: [] };
      } catch (e) {
        fallbackReason = `Provider AI gagal: ${String((e as Error)?.message ?? e).slice(0, 160)}`;
      }
    }

    const replyText = String(parsed?.reply ?? parsed?.content ?? "").trim();
    let blocks: Json[] = Array.isArray(parsed?.blocks) ? parsed.blocks : [];
    if (!blocks.length && replyText) blocks = [{ type: "text", text: replyText }];
    if (fallbackReason) blocks = fallbackBlocks(snap, fallbackReason);
    if (!blocks.length) blocks = fallbackBlocks(snap, "Belum ada jawaban dari AI.");

    // Simpan jawaban assistant.
    await admin.from("doctor_messages").insert({
      conversation_id: conversationId, outlet_id: outletId, role: "assistant",
      content: replyText || "(blok terstruktur)", blocks, tokens,
    });
    await admin.from("doctor_conversations")
      .update({ updated_at: new Date().toISOString(), phase: String(parsed?.phase ?? profile?.phase ?? "A") })
      .eq("id", conversationId);

    // Memori: simpan vonis/resep + perbarui digest.
    const mem = parsed?.memory;
    if (mem?.title) {
      await admin.from("doctor_memory").insert({
        outlet_id: outletId, conversation_id: conversationId,
        kind: String(mem.kind ?? "diagnosis"), title: String(mem.title).slice(0, 200),
        content: String(mem.content ?? replyText).slice(0, 2000), status: "open",
      });
    }
    const digestLine = `${new Date().toISOString().slice(0, 10)}: ${String(parsed?.memory?.title ?? replyText).slice(0, 160)}`;
    const newDigest = [profile?.memory_digest, digestLine].filter(Boolean).join("\n").slice(-4000);
    await admin.from("doctor_outlet_profile").upsert({
      outlet_id: outletId,
      memory_digest: newDigest,
      business_age_days: snap.business_age_days,
      phase: String(parsed?.phase ?? profile?.phase ?? "A"),
      total_conversations: Number(profile?.total_conversations ?? 0) + (conversationId ? 0 : 1),
      updated_at: new Date().toISOString(),
    });

    return json({
      success: true,
      conversation_id: conversationId,
      phase: String(parsed?.phase ?? profile?.phase ?? "A"),
      blocks,
      reply: replyText,
      fallback: !!fallbackReason,
      tokens,
      disclaimer: DISCLAIMER,
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
