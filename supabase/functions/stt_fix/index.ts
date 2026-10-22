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

const LLM_TIMEOUT_MS = 12000;
const MAX_INPUT = 800;

const SYSTEM_PROMPT = `Kamu adalah mesin PERAPI TRANSKRIP suara Bahasa Indonesia untuk aplikasi kasir UMKM "KasirGo".
Tugasmu HANYA memperbaiki hasil transkrip suara-ke-teks yang salah dengar.

ATURAN WAJIB:
1. Perbaiki ejaan, spasi, tanda baca, dan kata yang salah dengar agar jadi kalimat Indonesia yang wajar.
2. JANGAN menjawab pertanyaan, JANGAN menambah informasi baru, JANGAN menghapus maksud pembicara.
3. JANGAN menerjemahkan ke bahasa lain. Pertahankan gaya bicara santai pemilik warung.
4. Bakukan istilah usaha: omzet, laba, margin, stok, kulakan, kasbon, pelanggan, diskon, promo, resep, bundling, HPP, QRIS, tunai, laporan, karyawan, shift.
5. Bila transkrip menyebut nama produk/barang yang mirip dengan daftar kosakata, tulis persis seperti di daftar.
6. Angka dan nominal ditulis dengan angka (contoh: 25000, 12%).
7. Balas HANYA teks hasil perbaikan pada satu baris. Tanpa penjelasan, tanpa tanda kutip, tanpa awalan seperti "Hasil:".
8. Bila transkrip sudah benar, balas teks itu apa adanya.`;

async function callLlm(cfg: Json, messages: Json[]): Promise<string> {
  const base = String(cfg.base_url ?? "").replace(/\/+$/, "");
  const url = base.includes("/chat/completions") ? base : `${base}/chat/completions`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), LLM_TIMEOUT_MS);
  try {
    const resp = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${cfg.api_key}`,
      },
      body: JSON.stringify({
        model: cfg.model,
        messages,
        temperature: 0.1,
        max_tokens: 400,
      }),
      signal: ctrl.signal,
    });
    const data = await resp.json().catch(() => ({}));
    if (!resp.ok) {
      throw new Error(data?.error?.message ?? data?.message ?? `LLM HTTP ${resp.status}`);
    }
    const content = data?.choices?.[0]?.message?.content;
    return typeof content === "string" ? content : "";
  } finally {
    clearTimeout(timer);
  }
}

/// Buang pembungkus yang kadang ditambahkan model ("Hasil: ...", kutip, dsb).
function unwrap(raw: string): string {
  let s = raw.replace(/\r/g, "").trim();
  s = s.split("\n").map((l) => l.trim()).filter(Boolean).join(" ");
  s = s.replace(/^```[a-zA-Z]*\s*/, "").replace(/```$/, "").trim();
  s = s.replace(/^(hasil|transkrip|teks|output)\s*[:=]\s*/i, "").trim();
  s = s.replace(/^["“'`]+|["”'`]+$/g, "").trim();
  return s;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ error: "Unauthorized" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);

  let body: Json = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "Body tidak valid" }, 400);
  }

  const original = String(body.text ?? "").replace(/\s+/g, " ").trim();
  if (!original) return json({ error: "Teks kosong" }, 400);
  if (original.length < 4) return json({ ok: true, text: original, provider: "skip" });
  const text = original.length > MAX_INPUT ? original.slice(0, MAX_INPUT) : original;
  const outletId = String(body.outlet_id ?? "");

  const vocab: string[] = Array.isArray(body.vocabulary)
    ? body.vocabulary
      .map((v: unknown) => String(v ?? "").trim())
      .filter((v: string) => v.length > 1 && v.length <= 40)
      .slice(0, 40)
    : [];

  try {
    const admin = createClient(supabaseUrl, serviceKey);

    // Provider: override outlet -> fallback global (sama seperti Dokter Bisnis).
    let cfg: Json = {};
    if (outletId) {
      const { data: override } = await admin
        .from("outlet_ai_configs")
        .select("base_url, api_key_enc, model, temperature, max_tokens, is_active")
        .eq("outlet_id", outletId)
        .maybeSingle();
      if (override?.is_active && override?.api_key_enc) {
        cfg = {
          base_url: override.base_url,
          api_key: override.api_key_enc,
          model: override.model,
        };
      }
    }
    if (!cfg.api_key) {
      const { data: pcfg } = await admin
        .from("platform_configs").select("value").eq("key", "business_doctor").maybeSingle();
      const g: Json = pcfg?.value ?? {};
      cfg = {
        base_url: g?.provider_default?.base_url,
        api_key: g?.provider_default?.api_key,
        model: g?.provider_default?.model,
      };
    }
    if (!cfg.api_key || !cfg.base_url || !cfg.model) {
      return json({ ok: false, text: original, error: "provider_not_configured" });
    }

    const userContent = vocab.length
      ? `Kosakata produk outlet: ${vocab.join(", ")}\n\nTranskrip: ${text}`
      : `Transkrip: ${text}`;

    const out = unwrap(await callLlm(cfg, [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: userContent },
    ]));

    // Jaga-jaga: model menjawab panjang/menolak -> pakai teks asli.
    if (!out) return json({ ok: false, text: original, error: "empty_result" });
    const growth = out.length / Math.max(text.length, 1);
    if (growth > 2.2 || out.length < 2) {
      return json({ ok: false, text: original, error: "unsafe_result" });
    }
    return json({ ok: true, text: out, provider: "llm" });
  } catch (e) {
    return json({ ok: false, text: original, error: String((e as Error)?.message ?? e) });
  }
});
