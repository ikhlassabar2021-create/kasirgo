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

const DISCLAIMER = "Konten ini dibuat AI. Periksa dulu sebelum dipublikasikan.";

type Json = Record<string, any>;

const CHANNELS = ["fb", "fb_group", "ig", "tiktok", "shopee", "wa_status", "wa_broadcast"];

async function callLlm(cfg: Json, messages: Json[]) {
  let base = String(cfg.base_url ?? "").replace(/\/+$/, "");
  const url = base.includes("/chat/completions") ? base : `${base}/chat/completions`;
  const body: Json = {
    model: cfg.model,
    messages,
    temperature: Number(cfg.temperature ?? 0.7),
    max_tokens: Number(cfg.max_tokens ?? 2000) || 2000,
  };
  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${cfg.api_key}` },
    body: JSON.stringify(body),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data?.error?.message ?? data?.message ?? `LLM HTTP ${resp.status}`);
  return data;
}

function extractJson(text: string): Json | null {
  if (!text) return null;
  const start = text.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  for (let i = start; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}") {
      depth--;
      if (depth === 0) {
        try {
          return JSON.parse(text.slice(start, i + 1));
        } catch {
          return null;
        }
      }
    }
  }
  return null;
}

function sanitize(text: string) {
  return String(text ?? "")
    .replace(/```[\s\S]*?```/g, "")
    .trim();
}

function buildPrompt(
  outlet: Json,
  brief: string,
  tone: string,
  goal: string,
  channels: string[],
  products: Json[],
) {
  const list = products
    .map((p) => `- ${p.name} | harga Rp${Number(p.base_price ?? 0)} | stok ${p.stock ?? 0}`)
    .join("\n");
  return [
    {
      role: "system",
      content:
        `Kamu adalah "Squad Digital Marketing AI" untuk UMKM Indonesia. Tulis konten promosi dalam Bahasa Indonesia yang ramah, jujur, dan tidak berlebihan (tanpa klaim palsu).\n` +
        `Toko: ${outlet?.name ?? "-"} (${outlet?.type ?? "-"}).\n` +
        `Kanal target: ${channels.join(", ") || "umum"}.\n` +
        `Balas HANYA JSON valid: {"variants":[{"title":"...","caption":"...","hashtags":"...","channel":"..."}],"tips":"..."}.\n` +
        `Buat 1-3 variasi. Sertakan harga & ajakan bertindak bila relevan. Jangan bahas politik/agama/SARA/judi/pinjol.`,
    },
    {
      role: "user",
      content:
        `Brief: ${brief || "promosi produk unggulan"}\n` +
        `Tujuan: ${goal || "menaikkan penjualan"}\n` +
        `Gaya: ${tone || "ramah"}\n` +
        (list ? `Produk pilihan:\n${list}` : ""),
    },
  ];
}

function buildVideoPrompt(
  outlet: Json,
  brief: string,
  tone: string,
  goal: string,
  duration: number,
  products: Json[],
) {
  const list = products
    .map((p) => `- ${p.name} | Rp${Number(p.base_price ?? 0)}`)
    .join("\n");
  return [
    {
      role: "system",
      content:
        `Kamu sutradara iklan pendek UMKM Indonesia. Buat naskah video promosi ${duration} detik.\n` +
        `Toko: ${outlet?.name ?? "-"} (${outlet?.type ?? "-"}).\n` +
        `Balas HANYA JSON valid: {"title":"...","voiceover":"...","scenes":[{"text":"...","duration":4}],"music":"...","tips":"..."}.\n` +
        `Buat 3-6 scene, tiap scene teks singkat maks 60 karakter. Bahasa Indonesia ramah & jujur, tanpa klaim medis/berlebihan. Jangan bahas politik/agama/SARA/judi/pinjol.`,
    },
    {
      role: "user",
      content:
        `Brief: ${brief || "promo produk unggulan"}\n` +
        `Tujuan: ${goal || "menaikkan penjualan"}\n` +
        `Gaya: ${tone || "ramah"}\n` +
        (list ? `Produk:\n${list}` : ""),
    },
  ];
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
    const mode = String(body.mode ?? "generate");
    const outletId = String(body.outlet_id ?? "");

    const { data: isAdminFlag } = await userClient.rpc("is_platform_admin");
    const isPlatformAdmin = !!isAdminFlag;

    if (mode === "test_provider") {
      if (!isPlatformAdmin) return json({ success: false, message: "Forbidden" }, 403);
      const p = (body.provider ?? {}) as Json;
      if (!p.base_url || !p.api_key || !p.model) {
        return json({ success: true, ok: false, message: "Lengkapi Base URL, API Key, dan Model." });
      }
      try {
        const data = await callLlm({ ...p, max_tokens: 16, temperature: 0 }, [
          { role: "user", content: "Balas satu kata: ok" },
        ]);
        const sample = String(data?.choices?.[0]?.message?.content ?? "").slice(0, 120);
        return json({ success: true, ok: true, message: "Koneksi provider berhasil.", sample });
      } catch (e) {
        return json({ success: true, ok: false, message: String((e as Error)?.message ?? e).slice(0, 300) });
      }
    }

    if (!outletId) return json({ success: false, message: "outlet_id wajib." }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    if (!isPlatformAdmin) {
      const { data: owned } = await admin
        .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
      let isMember = !!owned;
      if (!isMember) {
        const { data: role } = await admin
          .from("user_roles").select("id").eq("outlet_id", outletId).eq("user_id", userId).maybeSingle();
        isMember = !!role;
      }
      if (!isMember) return json({ success: false, message: "Forbidden" }, 403);
    }

    const { data: active } = isPlatformAdmin
      ? { data: true }
      : await admin.rpc("outlet_supporter_active", { target_outlet: outletId });
    if (!active) {
      return json({
        success: true,
        gated: true,
        blocks: [
          {
            type: "card",
            tone: "warning",
            title: "Squad Digital Marketing terkunci",
            body: "Aktifkan Program Pendukung Rp50.000/bulan untuk membuat konten promosi dengan AI.",
          },
          { type: "action", label: "Aktifkan Program Pendukung", action_key: "upgrade" },
        ],
        disclaimer: DISCLAIMER,
      });
    }

    const { data: outlet } = await admin
      .from("outlets").select("name, type").eq("id", outletId).maybeSingle();

    const { data: dcfg } = await admin
      .from("platform_configs").select("value").eq("key", "digital_marketing_llm").maybeSingle();
    const globalCfg: Json = dcfg?.value ?? {};

    const { data: override } = await admin
      .from("outlet_dm_configs")
      .select("provider, base_url, api_key_enc, model, temperature, max_tokens, is_active, unlimited_tokens, token_quota")
      .eq("outlet_id", outletId)
      .maybeSingle();

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

    const rl = (globalCfg?.rate_limit ?? {}) as Json;
    const maxAssets = Number(rl.assets_per_day ?? 20);
    const quota = Number(override?.token_quota ?? 0);
    const maxTokens = quota > 0 ? quota : Number(rl.tokens_per_day ?? 150000);
    const { data: usage } = await admin.rpc("dm_usage_today", { p_outlet: outletId });
    const usedAssets = Number(usage?.assets ?? 0);
    const usedTokens = Number(usage?.tokens ?? 0);
    if (!isPlatformAdmin && !override?.unlimited_tokens) {
      if (usedAssets >= maxAssets) {
        return json({
          success: true,
          blocks: [{
            type: "card",
            tone: "warning",
            title: "Batas harian tercapai",
            body: `Kuota konten hari ini habis (${usedAssets}/${maxAssets}). Coba lagi besok ya.`,
          }],
          disclaimer: DISCLAIMER,
        });
      }
      if (usedTokens >= maxTokens) {
        return json({
          success: true,
          blocks: [{
            type: "card",
            tone: "warning",
            title: "Batas token tercapai",
            body: "Kuota token AI hari ini habis. Coba lagi besok ya.",
          }],
          disclaimer: DISCLAIMER,
        });
      }
    }

    const brief = String(body.brief ?? "").slice(0, 1000);
    const tone = String(body.tone ?? "ramah").slice(0, 40);
    const goal = String(body.goal ?? "").slice(0, 120);
    const channels: string[] = (Array.isArray(body.channels) ? body.channels : [])
      .map((c: unknown) => String(c))
      .filter((c: string) => CHANNELS.includes(c));
    const productIds: string[] = Array.isArray(body.product_ids)
      ? body.product_ids.map((p: unknown) => String(p))
      : [];

    let products: Json[] = [];
    if (productIds.length) {
      const { data: prods } = await admin
        .from("products").select("id, name, base_price, stock, image_local_path")
        .eq("outlet_id", outletId).in("id", productIds.slice(0, 8));
      products = prods ?? [];
    }

    if (!provider.base_url || !provider.api_key || !provider.model) {
      return json({
        success: true,
        fallback: true,
        blocks: [{
          type: "card",
          tone: "warning",
          title: "AI belum aktif",
          body: "Provider AI belum diatur superadmin. Sementara susun konten manual dulu ya.",
        }],
        disclaimer: DISCLAIMER,
      });
    }

    const kind = String(body.kind ?? "copy");
    if (kind === "video") {
      const duration = Number(body.duration ?? 20);
      let vparsed: Json | null = null;
      let vtokens = 0;
      try {
        const data = await callLlm(
          provider,
          buildVideoPrompt(outlet ?? {}, brief, tone, goal, duration, products),
        );
        vtokens = Number(data?.usage?.total_tokens ?? 0);
        vparsed = extractJson(String(data?.choices?.[0]?.message?.content ?? ""));
      } catch (e) {
        return json({
          success: true,
          fallback: true,
          blocks: [{
            type: "card",
            tone: "warning",
            title: "AI sedang tidak bisa dihubungi",
            body: String((e as Error)?.message ?? e).slice(0, 200),
          }],
          disclaimer: DISCLAIMER,
        });
      }
      const scenes: Json[] = Array.isArray(vparsed?.scenes) ? vparsed.scenes.slice(0, 8) : [];
      if (!scenes.length) {
        return json({
          success: true,
          fallback: true,
          blocks: [{
            type: "card",
            tone: "warning",
            title: "Naskah video belum siap",
            body: "Coba lagi dengan brief yang lebih spesifik ya.",
          }],
          disclaimer: DISCLAIMER,
        });
      }
      const voiceover = sanitize(String(vparsed?.voiceover ?? vparsed?.narration ?? ""));
      const title = String(vparsed?.title ?? "").trim() || (brief.slice(0, 60) || "Video Promo");
      const { data: asset } = await admin.from("dm_assets").insert({
        outlet_id: outletId,
        kind: "video",
        title: title.slice(0, 120),
        content: voiceover,
        caption: voiceover,
        hashtags: "",
        source: productIds.length ? "product" : "brief",
        status: "draft",
        meta: {
          scenes: scenes.map((s) => ({ text: String(s?.text ?? ""), duration: Number(s?.duration ?? 4) })),
          music: String(vparsed?.music ?? "upbeat"),
          duration,
          tone,
          goal,
          generated_by: "dm_creative",
        },
      }).select("id, title, content, kind, status").maybeSingle();
      await admin.from("dm_usage").upsert({
        outlet_id: outletId,
        day: new Date().toISOString().slice(0, 10),
        assets: usedAssets + 1,
        tokens: usedTokens + vtokens,
        requests: Number(usage?.requests ?? 0) + 1,
      }, { onConflict: "outlet_id,day" });
      const blocks: Json[] = [];
      if (vparsed?.tips) blocks.push({ type: "text", text: sanitize(String(vparsed.tips)) });
      blocks.push({
        type: "video",
        title: title.slice(0, 120),
        duration,
        music: String(vparsed?.music ?? "upbeat"),
        voiceover,
        scenes: scenes.map((s) => ({ text: String(s?.text ?? ""), duration: Number(s?.duration ?? 4) })),
        asset_id: asset?.id ?? null,
      });
      return json({ success: true, asset, blocks, tokens: vtokens, disclaimer: DISCLAIMER });
    }

    let parsed: Json | null = null;
    let tokens = 0;
    try {
      const data = await callLlm(provider, buildPrompt(outlet ?? {}, brief, tone, goal, channels, products));
      tokens = Number(data?.usage?.total_tokens ?? 0);
      parsed = extractJson(String(data?.choices?.[0]?.message?.content ?? ""));
    } catch (e) {
      return json({
        success: true,
        fallback: true,
        blocks: [{
          type: "card",
          tone: "warning",
          title: "AI sedang tidak bisa dihubungi",
          body: String((e as Error)?.message ?? e).slice(0, 200),
        }],
        disclaimer: DISCLAIMER,
      });
    }

    const variants: Json[] = Array.isArray(parsed?.variants) ? parsed.variants.slice(0, 3) : [];
    if (!variants.length) {
      const caption = sanitize(String(parsed?.caption ?? ""));
      if (caption) variants.push({ title: brief.slice(0, 60) || "Konten Promosi", caption, hashtags: "", channel: channels[0] ?? "ig" });
    }

    const saved: Json[] = [];
    for (const v of variants) {
      const caption = sanitize(String(v?.caption ?? ""));
      if (!caption) continue;
      const { data: asset } = await admin.from("dm_assets").insert({
        outlet_id: outletId,
        kind: "copy",
        title: String(v?.title ?? "Konten Promosi").slice(0, 120),
        content: caption,
        caption,
        hashtags: String(v?.hashtags ?? "").slice(0, 300),
        source: productIds.length ? "product" : "brief",
        status: "draft",
        meta: { channel: String(v?.channel ?? channels[0] ?? ""), tone, goal, generated_by: "dm_creative" },
      }).select("id, title, caption, hashtags, kind, status").maybeSingle();
      if (asset) saved.push(asset);
    }

    const assetCount = saved.length || 1;
    await admin.from("dm_usage").upsert({
      outlet_id: outletId,
      day: new Date().toISOString().slice(0, 10),
      assets: usedAssets + assetCount,
      tokens: usedTokens + tokens,
      requests: Number(usage?.requests ?? 0) + 1,
    }, { onConflict: "outlet_id,day" });

    const blocks: Json[] = [];
    if (parsed?.tips) blocks.push({ type: "text", text: sanitize(String(parsed.tips)) });
    blocks.push({
      type: "assets",
      title: `Konten dibuat (${saved.length})`,
      items: saved.map((a) => ({ id: a.id, title: a.title, caption: a.caption, hashtags: a.hashtags, kind: a.kind, status: a.status })),
    });

    return json({ success: true, assets: saved, blocks, tokens, disclaimer: DISCLAIMER });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});
