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
      name: "get_action_history",
      description: "Riwayat promosi/aksi yang pernah dicatat beserta biaya dan hasil ROI-nya.",
      parameters: { type: "object", properties: {} },
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
  {
    type: "function",
    function: {
      name: "save_prescription",
      description: "Simpan vonis + resep (langkah perbaikan) ke memori outlet dan majukan fase ke B. Panggil ini SETIAP kali menyusun atau memperbarui resep, termasuk setelah resep lama gagal.",
      parameters: {
        type: "object",
        properties: {
          verdict: { type: "string", description: "Vonis singkat masalah utama." },
          verdict_body: { type: "string", description: "Penjelasan vonis 2-3 kalimat bahasa awam untuk layar hasil." },
          score: { type: "integer", description: "Skor Kesehatan Usaha 0-100 (perkiraan dari data)." },
          score_hint: { type: "string", description: "Penjelasan singkat arti skor." },
          target_days: { type: "integer", description: "Masa target menjalankan resep (hari), default 7." },
          steps: {
            type: "array",
            description: "Maksimal 8 langkah perbaikan berurutan.",
            items: {
              type: "object",
              properties: {
                text: { type: "string" },
                action_key: {
                  type: "string",
                  enum: ["sidak_bos", "progress_tracker", "dynamic_pricing", "bundling", "cross_sell", "wa_marketing", "catat_promosi", "health_score", "online_catalog", "qr_table", "multi_outlet", "recipe", "referral"],
                },
              },
              required: ["text"],
            },
          },
        },
        required: ["verdict", "steps"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_active_prescription",
      description: "Baca resep yang sedang berjalan (status open) beserta langkah dan masa targetnya.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "observe_progress",
      description: "Bandingkan resep terbuka vs data nyata (omzet 7 hari terakhir vs 7 hari sebelumnya). Hasil: improving/flat/declining.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "get_targets",
      description: "Baca target omzet aktif outlet (harian/bulanan) beserta capaian sebenarnya hari ini / bulan ini.",
      parameters: { type: "object", properties: {} },
    },
  },
  {
    type: "function",
    function: {
      name: "save_target",
      description: "Simpan/ubah target omzet outlet. HANYA setelah owner MENYETUJUI usulan target (guardrail persetujuan).",
      parameters: {
        type: "object",
        properties: {
          period: { type: "string", enum: ["day", "month"] },
          target_amount: { type: "number", description: "Nominal target dalam Rupiah." },
          note: { type: "string", description: "Catatan cara target dihitung (mis. moving average 14 hari)." },
        },
        required: ["period", "target_amount"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "save_scaling_plan",
      description: "Simpan rencana ekspansi (Business Scaling): tujuan, checklist kesiapan, roadmap 30/60/90 hari. HANYA setelah owner setuju.",
      parameters: {
        type: "object",
        properties: {
          goal: { type: "string" },
          readiness: { type: "array", items: { type: "object", properties: { text: { type: "string" }, ok: { type: "boolean" } } } },
          roadmap: { type: "array", items: { type: "object", properties: { phase: { type: "string", enum: ["30", "60", "90"] }, text: { type: "string" } } } },
        },
        required: ["goal", "roadmap"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_cross_sell",
      description: "Hitung peluang cross-selling: produk apa yang paling sering dibeli bersama produk tertentu (association rule dari riwayat transaksi).",
      parameters: {
        type: "object",
        properties: {
          product_id: { type: "string", description: "Opsional. Produk acuan; kosong = semua peluang teratas." },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "save_bundle",
      description: "Simpan paket bundling (produk margin tinggi + slow-moving dijual 1 harga). HANYA setelah owner menyetujui harga paket.",
      parameters: {
        type: "object",
        properties: {
          name: { type: "string" },
          description: { type: "string" },
          bundle_price: { type: "number" },
          items: {
            type: "array",
            items: {
              type: "object",
              properties: {
                product_id: { type: "string", description: "ID produk (UUID) bila diketahui." },
                product_name: { type: "string", description: "Nama produk persis seperti di katalog bila ID tidak diketahui." },
                quantity: { type: "number" },
              },
            },
          },
        },
        required: ["name", "bundle_price", "items"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "save_referral",
      description: "Buat kode referral berjenjang (pembawa + diajak dapat hadiah). HANYA setelah owner setuju.",
      parameters: {
        type: "object",
        properties: {
          code: { type: "string", description: "Kode unik, mis. HEMAT10." },
          title: { type: "string" },
          reward_amount: { type: "number", description: "Hadiah untuk pembawa (Rp)." },
          friend_reward_amount: { type: "number", description: "Hadiah untuk teman yang diajak (Rp)." },
          min_spend: { type: "number" },
          max_redemptions: { type: "integer" },
        },
        required: ["code"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "propose_action",
      description: "Ajukan aksi yang MENGUBAH data/harga/promosi (mis. terapkan flash sale, ubah harga, pasang promo). WAJIB lewat tool ini: owner harus MENYETUJUI dulu sebelum dieksekusi. Jangan pernah bilang aksi sudah dijalankan sebelum disetujui.",
      parameters: {
        type: "object",
        properties: {
          action_type: { type: "string", description: "mis. flash_sale | price_change | promotion | bundling | referral." },
          title: { type: "string" },
          body: { type: "string", description: "Penjelasan singkat dampak & alasan." },
          payload: { type: "object", description: "Data teknis aksi (produk, harga, diskon, dsb)." },
        },
        required: ["action_type", "title"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "benchmark_hyperlocal",
      description: "Bandingkan performa outlet vs outlet sejenis (agregat ANONIM wilayah). Bila data tipis, tandai 'perlu verifikasi'.",
      parameters: {
        type: "object",
        properties: {
          region: { type: "string", description: "Nama wilayah (default dari alamat outlet)." },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "escalate_case",
      description: "Naikkan tingkat penanganan kasus saat resep gagal/berulang. level 1=evaluasi ulang (cari akar masalah), 2=lini kedua (ganti pendekatan), 3=kasus bandel (butuh bantuan manusia).",
      parameters: {
        type: "object",
        properties: {
          level: { type: "integer", enum: [1, 2, 3] },
          root_cause: { type: "string", description: "Dugaan akar masalah dari kegagalan sebelumnya." },
          reason: { type: "string", description: "Alasan singkat mengapa naik tingkat." },
        },
        required: ["level", "root_cause"],
      },
    },
  },
];
function privateHost(host: string) {
  const h = host.toLowerCase();
  return h === "localhost" || h === "0.0.0.0" || h === "::1" ||
    h.endsWith(".internal") || h.endsWith(".local") ||
    /^(127\.|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.)/.test(h);
}

// ST15-3 (13.17): association rule sederhana (support/confidence/lift).
function crossSellRules(
  baskets: string[][],
  minSupport = 2,
  topN = 20,
): Json[] {
  const n = baskets.length;
  if (n < 2) return [];
  const itemCount = new Map<string, number>();
  for (const b of baskets) for (const id of new Set(b)) itemCount.set(id, (itemCount.get(id) ?? 0) + 1);
  const pairCount = new Map<string, number>();
  const pairItems = new Map<string, string[]>();
  for (const b of baskets) {
    const ids = Array.from(new Set(b)).sort();
    for (let i = 0; i < ids.length; i++) {
      for (let j = i + 1; j < ids.length; j++) {
        const key = ids[i] + "|" + ids[j];
        pairCount.set(key, (pairCount.get(key) ?? 0) + 1);
        pairItems.set(key, [ids[i], ids[j]]);
      }
    }
  }
  const rules: Json[] = [];
  for (const [key, count] of pairCount) {
    if (count < minSupport) continue;
    const [a, b] = pairItems.get(key)!;
    const sa = itemCount.get(a) ?? 0;
    const sb = itemCount.get(b) ?? 0;
    const confAB = sa > 0 ? count / sa : 0;
    const confBA = sb > 0 ? count / sb : 0;
    const support = count / n;
    const liftAB = sb > 0 ? confAB / (sb / n) : 0;
    const liftBA = sa > 0 ? confBA / (sa / n) : 0;
    if (confAB >= confBA) {
      rules.push({ antecedent: a, consequent: b, count, support: Math.round(support * 1000) / 1000, confidence: Math.round(confAB * 1000) / 1000, lift: Math.round(liftAB * 100) / 100 });
    } else {
      rules.push({ antecedent: b, consequent: a, count, support: Math.round(support * 1000) / 1000, confidence: Math.round(confBA * 1000) / 1000, lift: Math.round(liftBA * 100) / 100 });
    }
  }
  rules.sort((x, y) => Number(y.confidence) - Number(x.confidence));
  return rules.slice(0, topN);
}

async function toolFetchUrl(url: string, admin: any) {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return { error: "url_tidak_valid" };
  }
  if (u.protocol !== "http:" && u.protocol !== "https:") return { error: "protokol_ditolak" };
  if (privateHost(u.hostname)) return { error: "host_ditolak" };

  // Cache: bila entri masih segar (fetched_at + ttl), pakai tanpa fetch ulang.
  try {
    const { data: cached } = await admin
      .from("web_cache")
      .select("content, fetched_at, ttl_seconds")
      .eq("url", u.toString())
      .maybeSingle();
    if (cached?.content) {
      const age = Date.now() - new Date(String(cached.fetched_at ?? 0)).getTime();
      const ttl = Number(cached.ttl_seconds ?? 3600) * 1000;
      if (age < ttl) return { url: u.toString(), cached: true, text: String(cached.content).slice(0, 2000) };
    }
  } catch { /* cache gagal -> lanjut fetch langsung */ }

  try {
    const resp = await fetch(u.toString(), { headers: { "User-Agent": "KasirGo-Doctor/1.0" } });
    const html = await resp.text();
    const text = html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, 2000);
    // Simpan cache (abaikan kegagalan).
    try {
      await admin.from("web_cache").upsert({
        url: u.toString(), content: text, source_label: u.hostname,
        fetched_at: new Date().toISOString(), ttl_seconds: 3600,
      }, { onConflict: "url" });
    } catch { /* ignore */ }
    return { url: u.toString(), status: resp.status, text };
  } catch (e) {
    return { error: String((e as Error)?.message ?? e).slice(0, 200) };
  }
}

async function execTool(admin: any, outletId: string, name: string, args: Json, internetActive: boolean, conversationId: string | null, sink: Json) {
  switch (name) {
    case "get_business_snapshot":
      return await toolGetSnapshot(admin, outletId);
    case "get_action_history": {
      const { data } = await admin
        .from("doctor_action_logs")
        .select("action_type, channel, cost, description, action_date, result, outcome")
        .eq("outlet_id", outletId)
        .order("created_at", { ascending: false })
        .limit(20);
      return data ?? [];
    }
    case "fetch_url":
      return internetActive ? await toolFetchUrl(String(args?.url ?? ""), admin) : { error: "internet_nonaktif" };
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
    case "get_active_prescription": {
      const { data } = await admin
        .from("doctor_memory")
        .select("id, title, content, status, due_at, created_at")
        .eq("outlet_id", outletId).eq("kind", "prescription").eq("status", "open")
        .order("created_at", { ascending: false }).limit(1).maybeSingle();
      return data ?? { none: true };
    }
    case "get_targets": {
      const { data: targets } = await admin
        .from("outlet_targets")
        .select("period, target_amount, set_by, source, note, effective_from")
        .eq("outlet_id", outletId)
        .order("effective_from", { ascending: false })
        .limit(4);
      // Capaian hari ini / bulan ini.
      const { data: todayTrx } = await admin
        .from("transactions")
        .select("final_amount")
        .eq("outlet_id", outletId).eq("payment_status", "paid")
        .gte("created_at", new Date(new Date().toISOString().slice(0, 10)).toISOString());
      const { data: monthTrx } = await admin
        .from("transactions")
        .select("final_amount")
        .eq("outlet_id", outletId).eq("payment_status", "paid")
        .gte("created_at", new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString());
      const sum = (rows: Json[] | null) =>
        (rows ?? []).reduce((s: number, r: Json) => s + Number(r.final_amount ?? 0), 0);
      return {
        targets: targets ?? [],
        today_revenue: sum(todayTrx),
        month_revenue: sum(monthTrx),
      };
    }
    case "save_target": {
      const period = args?.period === "month" ? "month" : "day";
      const amount = Number(args?.target_amount ?? 0);
      if (!(amount > 0)) return { error: "nominal_tidak_valid" };
      const today = new Date().toISOString().slice(0, 10);
      const { error } = await admin.from("outlet_targets").upsert({
        outlet_id: outletId,
        period,
        target_amount: amount,
        set_by: "ai",
        source: "business_doctor",
        note: String(args?.note ?? "").slice(0, 300),
        effective_from: today,
      }, { onConflict: "outlet_id,period,effective_from" });
      if (error) return { error: String(error.message).slice(0, 200) };
      sink.target = { type: "action", label: `Target ${period === "day" ? "harian" : "bulanan"} tersimpan: Rp${Math.round(amount).toLocaleString("id-ID")}`, action_key: "progress_tracker" };
      return { saved: true, period, target_amount: amount };
    }
    case "save_scaling_plan": {
      const goal = String(args?.goal ?? "").slice(0, 300);
      const roadmap = (Array.isArray(args?.roadmap) ? args.roadmap : []).slice(0, 12).map((r: Json) => ({
        phase: ["30", "60", "90"].includes(String(r?.phase)) ? String(r.phase) : "30",
        text: String(r?.text ?? "").slice(0, 300),
      })).filter((r: Json) => r.text);
      if (!goal || !roadmap.length) return { error: "goal_dan_roadmap_wajib" };
      const readiness = (Array.isArray(args?.readiness) ? args.readiness : []).slice(0, 10).map((r: Json) => ({
        text: String(r?.text ?? "").slice(0, 200),
        ok: r?.ok === true,
      }));
      const { data, error } = await admin.from("doctor_scaling_plans").insert({
        outlet_id: outletId,
        conversation_id: conversationId,
        goal,
        readiness,
        roadmap,
      }).select("id").maybeSingle();
      if (error) return { error: String(error.message).slice(0, 200) };
      sink.scaling = { type: "card", tone: "info", title: "Peta Ekspansi tersimpan", body: `Tujuan: ${goal}. Roadmap ${roadmap.length} langkah (30/60/90 hari).` };
      return { saved: true, id: data?.id ?? null, phases: roadmap.length };
    }
    case "get_cross_sell": {
      // Association rule sederhana dari 200 transaksi terakhir.
      const { data: trx } = await admin
        .from("transactions")
        .select("id")
        .eq("outlet_id", outletId).eq("payment_status", "paid")
        .order("created_at", { ascending: false }).limit(200);
      const txIds = (trx ?? []).map((t: Json) => t.id);
      if (!txIds.length) return { rules: [], note: "Belum ada transaksi." };
      const { data: items } = await admin
        .from("transaction_items")
        .select("transaction_id, product_id, product_name")
        .in("transaction_id", txIds);
      const baskets = new Map<string, Set<string>>();
      const nameOf = new Map<string, string>();
      for (const it of (items ?? []) as Json[]) {
        const txId = String(it.transaction_id);
        if (!baskets.has(txId)) baskets.set(txId, new Set());
        baskets.get(txId)!.add(String(it.product_id));
        if (it.product_name) nameOf.set(String(it.product_id), String(it.product_name));
      }
      const list = Array.from(baskets.values()).map((s) => Array.from(s));
      const rules = crossSellRules(list, 2, 10).map((r: Json) => ({
        from: nameOf.get(String(r.antecedent)) ?? r.antecedent,
        to: nameOf.get(String(r.consequent)) ?? r.consequent,
        confidence: r.confidence,
        lift: r.lift,
        count: r.count,
      }));
      const focus = String(args?.product_id ?? "");
      return { rules, focus: focus || null };
    }
    case "save_bundle": {
      const name = String(args?.name ?? "").slice(0, 200);
      const bundlePrice = Number(args?.bundle_price ?? 0);
      const rawItems = (Array.isArray(args?.items) ? args.items : [])
        .slice(0, 10)
        .map((it: Json) => ({
          product_id: it?.product_id ? String(it.product_id) : "",
          product_name: it?.product_name ? String(it.product_name) : "",
          quantity: Number(it?.quantity ?? 1),
        }))
        .filter((it: Json) => it.product_id || it.product_name);
      if (!name || !(bundlePrice > 0) || !rawItems.length) return { error: "nama_harga_item_wajib" };

      // Resolve item -> product UUID (AI mungkin kirim nama, bukan UUID).
      const { data: outletProds } = await admin
        .from("products").select("id, name, base_price").eq("outlet_id", outletId);
      const prods = (outletProds ?? []) as Json[];
      const byId = new Map<string, Json>(prods.map((p: Json) => [String(p.id), p]));
      const byName = new Map<string, Json>(prods.map((p: Json) => [String(p.name).toLowerCase(), p]));
      const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);

      const items: Json[] = [];
      let originalPrice = 0;
      for (const it of rawItems) {
        let prod: Json | undefined;
        if (it.product_id && isUuid(it.product_id)) prod = byId.get(it.product_id);
        if (!prod && it.product_name) prod = byName.get(it.product_name.toLowerCase());
        if (!prod && it.product_id && !isUuid(it.product_id)) prod = byName.get(it.product_id.toLowerCase());
        if (!prod) continue;
        items.push({ product_id: prod.id, quantity: it.quantity });
        originalPrice += Number(prod.base_price ?? 0) * it.quantity;
      }
      if (!items.length) return { error: "produk_tidak_ditemukan", hint: "Sebutkan nama produk persis seperti di katalog." };

      const { data: bundle, error } = await admin.from("product_bundles").insert({
        outlet_id: outletId,
        name,
        description: String(args?.description ?? "").slice(0, 500),
        bundle_price: bundlePrice,
        original_price: originalPrice,
        is_active: true,
      }).select("id").maybeSingle();
      if (error || !bundle) return { error: String(error?.message ?? "gagal_simpan").slice(0, 200) };
      const { error: itemErr } = await admin.from("product_bundle_items").insert(
        items.map((it: Json) => ({ bundle_id: bundle.id, product_id: it.product_id, quantity: it.quantity })),
      );
      if (itemErr) {
        await admin.from("product_bundles").delete().eq("id", bundle.id);
        return { error: String(itemErr.message).slice(0, 200) };
      }
      const saving = Math.max(0, originalPrice - bundlePrice);
      sink.bundle = { type: "card", tone: "success", title: "Paket Bundling dibuat", body: `${name} — Rp${Math.round(bundlePrice).toLocaleString("id-ID")} (hemat Rp${Math.round(saving).toLocaleString("id-ID")} dari Rp${Math.round(originalPrice).toLocaleString("id-ID")}).` };
      return { saved: true, id: bundle.id, original_price: originalPrice, saving, items: items.length };
    }
    case "save_referral": {
      const code = String(args?.code ?? "").trim().toUpperCase().slice(0, 24);
      if (!code) return { error: "kode_wajib" };
      const { data, error } = await admin.from("referral_codes").upsert({
        outlet_id: outletId,
        code,
        title: String(args?.title ?? "").slice(0, 200),
        reward_amount: Number(args?.reward_amount ?? 0),
        friend_reward_amount: Number(args?.friend_reward_amount ?? 0),
        min_spend: Number(args?.min_spend ?? 0),
        max_redemptions: Number(args?.max_redemptions ?? 0),
        is_active: true,
        updated_at: new Date().toISOString(),
      }, { onConflict: "code" }).select("id, code").maybeSingle();
      if (error) return { error: String(error.message).slice(0, 200) };
      sink.referral = { type: "card", tone: "success", title: "Kode Referral dibuat", body: `Kode ${code} aktif. Pembawa dapat Rp${Number(args?.reward_amount ?? 0).toLocaleString("id-ID")}, teman dapat Rp${Number(args?.friend_reward_amount ?? 0).toLocaleString("id-ID")}.` };
      return { saved: true, code };
    }
    case "propose_action": {
      // ST15-4 (M): guardrail — aksi pengubah data TIDAK dieksekusi; hanya diusulkan.
      const actionType = String(args?.action_type ?? "").slice(0, 60);
      const title = String(args?.title ?? "").slice(0, 200);
      if (!actionType || !title) return { error: "action_type_dan_title_wajib" };
      const payload = (args?.payload && typeof args.payload === "object") ? args.payload : {};
      const { data, error } = await admin.from("doctor_pending_actions").insert({
        outlet_id: outletId,
        conversation_id: conversationId,
        action_type: actionType,
        title,
        body: String(args?.body ?? "").slice(0, 800),
        payload,
        status: "pending",
      }).select("id").maybeSingle();
      if (error) return { error: String(error.message).slice(0, 200) };
      sink.pending = {
        type: "pending_action",
        id: data?.id ?? null,
        action_type: actionType,
        title,
        body: String(args?.body ?? "").slice(0, 400),
        status: "pending",
      };
      return { proposed: true, id: data?.id ?? null, note: "Menunggu persetujuan owner. JANGAN bilang sudah dijalankan." };
    }
    case "benchmark_hyperlocal": {
      // ST15-4 (N): benchmark agregat anonim wilayah.
      let region = String(args?.region ?? "").trim();
      if (!region) {
        const { data: o } = await admin.from("outlets").select("address").eq("id", outletId).maybeSingle();
        region = String(o?.address ?? "").trim();
      }
      if (!region) return { error: "region_kosong", note: "Wilayah tidak diketahui; minta owner isi alamat/wilayah." };
      const { data: rows } = await admin
        .from("hyperlocal_reports")
        .select("period, payload")
        .ilike("region", region).eq("is_anonymous", true)
        .order("created_at", { ascending: false }).limit(50);
      const list = (rows ?? []) as Json[];
      const n = list.length;
      const sumBasket = list.reduce((s: number, r: Json) => s + Number(r?.payload?.avg_basket ?? 0), 0);
      const sumTx = list.reduce((s: number, r: Json) => s + Number(r?.payload?.tx_count ?? 0), 0);
      const needVerify = n < 3;
      const snapLocal = await toolGetSnapshot(admin, outletId);
      return {
        region,
        participants: n,
        avg_basket: n ? Math.round(sumBasket / n) : 0,
        avg_tx: n ? Math.round(sumTx / n) : 0,
        outlet_basket: Number(snapLocal?.avg_ticket ?? 0),
        need_verification: needVerify,
        note: needVerify
          ? "Data wilayah terlalu tipis (<3 outlet) — tandai 'perlu verifikasi' dan jangan jadikan dasar utama."
          : "Data agregat anonim wilayah; gunakan sebagai konteks, bukan kepastian.",
      };
    }
    case "observe_progress": {
      const { data: openRx } = await admin
        .from("doctor_memory")
        .select("id, title, content, due_at, created_at")
        .eq("outlet_id", outletId).eq("kind", "prescription").eq("status", "open")
        .order("created_at", { ascending: false }).limit(1).maybeSingle();
      if (!openRx) return { none: true };
      const since = new Date(Date.now() - 14 * 86400000).toISOString();
      const { data: trx } = await admin
        .from("transactions")
        .select("final_amount, payment_status, created_at")
        .eq("outlet_id", outletId)
        .eq("payment_status", "paid")
        .gte("created_at", since);
      let last7 = 0;
      let prev7 = 0;
      const now = Date.now();
      for (const t of trx ?? []) {
        const ts = new Date(String(t.created_at ?? 0)).getTime();
        if (!Number.isFinite(ts)) continue;
        const amt = Number(t.final_amount ?? 0);
        if (ts >= now - 7 * 86400000) last7 += amt;
        else prev7 += amt;
      }
      const outcome = last7 > prev7 ? "improving" : last7 === prev7 ? "flat" : "declining";
      // Contoh penggunaan: bandingkan dgn baseline resep.
      return {
        prescription_id: openRx.id,
        title: openRx.title,
        due_at: openRx.due_at,
        last7_revenue: last7,
        prev7_revenue: prev7,
        outcome,
      };
    }
    case "save_prescription": {
      const verdict = String(args?.verdict ?? "").slice(0, 300);
      const targetDays = Math.max(1, Math.min(90, Number(args?.target_days) || 7));
      const steps = (Array.isArray(args?.steps) ? args.steps : []).slice(0, 8).map((s: Json) => ({
        text: String(s?.text ?? "").slice(0, 300),
        action_key: s?.action_key ? String(s.action_key) : null,
        done: false,
      })).filter((s: Json) => s.text);
      const startedAt = new Date();
      const dueAt = new Date(startedAt.getTime() + targetDays * 86400000).toISOString();
      // Tutup resep lama yang belum selesai agar hanya satu resep aktif.
      await admin.from("doctor_memory")
        .update({ status: "failed" })
        .eq("outlet_id", outletId).eq("kind", "prescription").eq("status", "open");
      const { data } = await admin
        .from("doctor_memory")
        .insert({
          outlet_id: outletId, conversation_id: conversationId,
          kind: "prescription",
          title: verdict || "Resep perbaikan",
          content: JSON.stringify({ verdict, target_days: targetDays, started_at: startedAt.toISOString(), steps }),
          status: "open",
          due_at: dueAt,
        })
        .select("id")
        .maybeSingle();
      const memoryId = data?.id ?? null;
      sink.prescription = {
        type: "prescription", memory_id: memoryId, title: verdict || "Resep perbaikan",
        verdict: verdict || "Resep perbaikan",
        verdict_body: String(args?.verdict_body ?? "").slice(0, 600),
        score: Number.isFinite(Number(args?.score)) ? Number(args?.score) : null,
        score_hint: String(args?.score_hint ?? "").slice(0, 300),
        target_days: targetDays, due_at: dueAt, items: steps,
      };
      return { saved: true, id: memoryId, target_days: targetDays, due_at: dueAt, steps: steps.length };
    }
    case "escalate_case": {
      const level = Math.max(1, Math.min(3, Number(args?.level) || 1));
      const rootCause = String(args?.root_cause ?? "").slice(0, 500);
      const status = level >= 3 ? "kasus_bandel" : "evaluasi_ulang";
      if (conversationId) {
        await admin.from("doctor_conversations")
          .update({ status, escalation_level: level, updated_at: new Date().toISOString() })
          .eq("id", conversationId);
      }
      await admin.from("doctor_memory").insert({
        outlet_id: outletId, conversation_id: conversationId,
        kind: "lesson", title: `Akar masalah (naik tingkat ${level})`,
        content: rootCause, status: "open",
      });
      return { escalated: true, level, status };
    }
    default:
      return { error: `unknown_tool:${name}` };
  }
}

function buildSystem(cfg: Json, snap: Json, profile: Json | null, openCases: Json[], history: Json[], actionLogs: Json[], internetActive: boolean) {
  const roleMap = cfg.role_outlet ?? {};
  const roleText = roleMap?.[snap.outlet_type] ?? "Fokus pada perbaikan omzet dan arus kas UMKM.";
  const guard = Array.isArray(cfg.guardrails) ? cfg.guardrails.join("\n- ") : "";
  const openText = openCases.length
    ? openCases.map((m) => `- [${m.kind}/${m.status}] ${m.title}: ${m.content ?? ""}`).join("\n")
    : "(belum ada kasus terbuka)";
  const histText = history.length
    ? history.map((m) => `${m.role}: ${String(m.content ?? "").slice(0, 300)}`).join("\n")
    : "(sesi baru)";
  const roiText = actionLogs.length
    ? actionLogs.map((a) => `- ${a.action_date ?? "?"} ${a.action_type ?? "aksi"}${a.channel ? ` (${a.channel})` : ""}: biaya Rp${a.cost ?? 0}, hasil ${a.outcome ?? "belum diukur"} ${a.result ? JSON.stringify(a.result).slice(0, 200) : ""}`).join("\n")
    : "(belum ada aksi promosi dicatat)";
  const netLine = internetActive
    ? "- Anda BISA memakai tool fetch_url untuk membaca halaman web bila perlu info pasar/referensi. Jangan mengarang sumber."
    : "- Internet tidak aktif; jangan mengarang data dari luar.";
  const sk = skillList(cfg);
  const skillLine = sk.length
    ? `\nSKILL AKTIF (hanya fitur/tool ini yang tersedia untuk Anda): ${sk.join(", ")}. Jangan menjanjikan fitur di luar daftar ini.`
    : "";
  return `${cfg.prompt_utama ?? "Kamu adalah Dokter Bisnis KasirGo."}
${skillLine}

PERAN UNTUK TIPE OUTLET (${snap.outlet_type ?? "umum"}):
${roleText}

GUARDRAILS:
- ${guard}
FASE SAAT INI: ${profile?.phase ?? "A"} | Umur usaha: ${snap.business_age_days ?? "?"} hari
ALUR FASE (pindah otomatis saat progres tercapai):
- A = Diagnosa: kumpulkan fakta (cek fisik + data penjualan), tentukan masalah utama & skor kesehatan. Setelah vonis jelas -> fase B.
- B = Resep: susun langkah perbaikan konkret dalam checklist. Setelah resep dijalankan -> fase C.
- C = Evaluasi: bandingkan hasil dengan target. WAJIB pakai tool get_action_history untuk melihat biaya & hasil promosi, hitung ROI tiap aksi (omzet tambahan vs biaya), lalu putuskan: lanjut, selesai, atau ubah resep (kembali fase B).
ESCALATION LADDER (saat resep gagal / hasil tak membaik):
- Level 0 = normal. Selama perbaikan berjalan, tetap di fase B/C.
- Level 1 = evaluasi_ulang: hasil tidak membaik setelah resep dijalankan. Panggil tool escalate_case level 1 + root_cause (dugaan akar masalah), lalu susun ulang resep dengan pendekatan berbeda (kembali fase B).
- Level 2 = lini kedua: resep kedua juga gagal. Panggil escalate_case level 2 + root_cause, cari faktor lain (harga, lokasi, jam, kompetitor) dan tawarkan pendekatan alternatif.
- Level 3 = kasus_bandel: sudah 2+ kali gagal. Panggil escalate_case level 3 + root_cause, jelaskan terus terang bahwa kasus ini bandel & sarankan minta bantuan manusia (pendamping/komunitas), tampilkan block card tone danger "Kasus Bandel".
GUARDRAIL AKSI OTOMATIS: Untuk SEMUA aksi yang mengubah data/harga/promo (flash sale, ubah harga, pasang promo, dll), WAJIB panggil tool propose_action. JANGAN bilang aksi sudah dijalankan — aksi berstatus pending sampai owner menyetujui.
BENCHMARK HYPERLOCAL: Bila owner bertanya pembanding wilayah, panggil benchmark_hyperlocal. Bila hasil need_verification=true (data tipis), WAJIB tulis "perlu verifikasi" dan jangan jadikan dasar utama.
MEMORI JANGKA PANJANG:
${profile?.memory_digest ?? "(belum ada)"}
KASUS TERBUKA:
${openText}
RIWAYAT AKSI PROMOSI (biaya & hasil):
${roiText}

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
  {"type":"action","label":"...","action_key":"sidak_bos|progress_tracker|dynamic_pricing|bundling|cross_sell|wa_marketing|catat_promosi|health_score|online_catalog|qr_table|multi_outlet|recipe|referral"}
- Bahasa Indonesia sederhana, minim istilah teknis, langkah kecil yang bisa dikerjakan.
- Isi "phase" dengan fase saat ini sesuai ALUR FASE di atas.
- Saat menyusun ATAU memperbarui resep (fase B, atau setiap resep lama gagal), WAJIB panggil tool save_prescription dengan verdict, target_days (mis. 7), dan steps (maks 8). Sistem otomatis menampilkan kartu resep yang bisa diklik "Jalankan". Jangan menulis langkah hanya sebagai teks biasa.
- Setiap langkah resep WAJIB diisi action_key bila cocok dengan fitur aplikasi, agar owner bisa langsung menekan "Jalankan". Pilih HANYA dari daftar action_key di atas.
- Dasar resep = data LOKAL (snapshot/tren/stok/kas). Bila internet aktif, boleh pakai fetch_url untuk referensi pasar/ide promosi, lalu gabungkan; jangan mengarang sumber.
- Saat fase C, tampilkan hasil evaluasi sebagai card (tone success bila berhasil) + gauge skor, sebutkan ROI ringkas per aksi, dan beri block action "Catat Hasil Promosi" bila owner belum mencatat.
- Bila owner menyatakan resep BELUM berhasil: panggil observe_progress untuk melihat tren (improving/flat/declining), lalu escalate_case, lalu WAJIB buat resep BARU (save_prescription) dengan pendekatan berbeda dan target_days baru. JANGAN ulangi resep yang sudah gagal.
- Saat owner bertanya "apakah resep sudah membuahkan hasil" / meminta evaluasi progres: WAJIB panggil observe_progress dulu sebelum menjawab.
${netLine}
- Selalu akhiri dengan disclaimer singkat "saran AI".`;
}

function extractJson(text: string): Json | null {
  const t = String(text ?? "").trim();
  const cleaned = t.replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    /* fallthrough */
  }
  // Ambil objek JSON pertama yang seimbang (model kadang menambah teks setelahnya).
  const start = cleaned.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < cleaned.length; i++) {
    const ch = cleaned[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === "\\") esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') inStr = true;
    else if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) {
        try {
          return JSON.parse(cleaned.slice(start, i + 1));
        } catch {
          return null;
        }
      }
    }
  }
  return null;
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

const FETCH_TOOL = {
  type: "function",
  function: {
    name: "fetch_url",
    description: "Ambil isi sebuah halaman web (http/https) untuk mencari info bisnis. Hasil berupa teks ringkas.",
    parameters: {
      type: "object",
      properties: { url: { type: "string", description: "URL lengkap yang ingin dibaca." } },
      required: ["url"],
    },
  },
};

// ST15-1: peta skill -> tool (BAGIAN 13.26). Tool yang tidak dipetakan selalu aktif.
const SKILL_TOOLS: Record<string, string[]> = {
  snapshot: ["get_business_snapshot"],
  trend: ["get_sales_trend"],
  low_stock: ["get_low_stock"],
  slow_products: ["list_slow_products"],
  cashflow: ["get_cashflow", "get_action_history"],
  memory: ["recall_memory", "save_memory", "save_prescription", "get_active_prescription", "observe_progress"],
  internet: ["fetch_url"],
  target: ["get_targets", "save_target"],
  scaling: ["save_scaling_plan"],
  cross_sell: ["get_cross_sell"],
  bundling: ["save_bundle"],
  referral: ["save_referral"],
  market_intel: ["fetch_url", "benchmark_hyperlocal"],
  weekly_report: ["propose_action"],
};

function skillList(cfg: Json): string[] {
  const s = cfg?.skills;
  return Array.isArray(s) ? s.map((x) => String(x)) : [];
}

function toolAllowed(name: string, skills: string[]): boolean {
  if (!skills.length) return true; // belum diatur -> semua aktif (kompatibilitas)
  const owner = Object.keys(SKILL_TOOLS).find((k) => SKILL_TOOLS[k].includes(name));
  if (!owner) return true; // tool inti (mis. escalate_case) selalu aktif
  return skills.includes(owner);
}

function toolsFor(internetActive: boolean, skills: string[]) {
  const base = TOOLS.filter((t: Json) => toolAllowed(String(t?.function?.name ?? ""), skills));
  if (internetActive && toolAllowed("fetch_url", skills)) return [...base, FETCH_TOOL];
  return base;
}

async function callLlm(cfg: Json, messages: Json[], tools: Json[] | null) {
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

    const { data: isAdminFlag } = await userClient.rpc("is_platform_admin");
    const isPlatformAdmin = !!isAdminFlag;

    // Superadmin: uji koneksi provider tanpa outlet (dari form Control Plane).
    if (mode === "test_provider") {
      if (!isPlatformAdmin) return json({ success: false, message: "Forbidden" }, 403);
      const p = (body.provider ?? {}) as Json;
      if (!p.base_url || !p.api_key || !p.model) {
        return json({ success: true, ok: false, message: "Lengkapi Base URL, API Key, dan Model." });
      }
      try {
        const data = await callLlm({ ...p, max_tokens: 16, temperature: 0 }, [
          { role: "user", content: "Balas satu kata: ok" },
        ], null);
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

    // Gating: butuh Program Pendukung/trial aktif sebelum memanggil LLM.
    // Superadmin dikecualikan (mode uji/chat uji Control Plane).
    const { data: active } = isPlatformAdmin
      ? { data: true }
      : await admin.rpc("outlet_supporter_active", { target_outlet: outletId });
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
      .select("provider, base_url, api_key_enc, model, temperature, max_tokens, is_active, unlimited_tokens, token_quota")
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

    // Rate limit / kuota token harian (superadmin dikecualikan).
    // Unlimited: outlet unlimited_tokens ON -> kuota dilewati (tetap dicatat).
    if (!isPlatformAdmin && !override?.unlimited_tokens) {
      const rl = (globalCfg?.rate_limit ?? {}) as Json;
      const maxMsgs = Number(rl.messages_per_day ?? 60);
      const quota = Number(override?.token_quota ?? 0);
      const maxTokens = quota > 0 ? quota : Number(rl.tokens_per_day ?? 200000);
      const { data: usage } = await admin.rpc("doctor_daily_usage", { target_outlet: outletId });
      const usedMsgs = Number(usage?.messages ?? 0);
      const usedTokens = Number(usage?.tokens ?? 0);
      if (usedMsgs >= maxMsgs || usedTokens >= maxTokens) {
        return json({
          success: true,
          conversation_id: conversationId,
          blocks: [
            { type: "card", tone: "warning", title: "Batas harian tercapai", body: `Kuota Dokter Bisnis hari ini habis (${usedMsgs}/${maxMsgs} pesan). Coba lagi besok ya.` },
          ],
          disclaimer: DISCLAIMER,
        });
      }
    }

    const snap = await loadSnapshot(admin, outletId);
    const { data: profile } = await admin
      .from("doctor_outlet_profile").select("*").eq("outlet_id", outletId).maybeSingle();
    const { data: openCases } = await admin
      .from("doctor_memory").select("kind, title, content, status")
      .eq("outlet_id", outletId).eq("status", "open").limit(10);
    const { data: actionLogs } = await admin
      .from("doctor_action_logs")
      .select("action_type, channel, cost, description, action_date, result, outcome")
      .eq("outlet_id", outletId).order("created_at", { ascending: false }).limit(10);
    const internetActive = globalCfg?.internet_tool?.aktif === true;

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
      { role: "system", content: buildSystem(globalCfg, snap, profile, openCases ?? [], history ?? [], actionLogs ?? [], internetActive) },
      { role: "user", content: message || "Mulai diagnosa usaha saya." },
    ];

    let parsed: Json | null = null;
    let fallbackReason = "";
    let tokens = 0;
    const sink: Json = {};

    if (!provider.base_url || !provider.api_key || !provider.model) {
      fallbackReason = "Provider AI belum diatur superadmin. Sementara pakai analisa lokal.";
    } else {
      try {
        let data: Json;
        const tools = toolsFor(internetActive, skillList(globalCfg));
        try {
          data = await callLlm(provider, messages, tools);
        } catch (_e) {
          data = await callLlm(provider, messages, null);
        }
        // Tool loop (maks 3 putaran).
        for (let round = 0; round < 3; round++) {
          const choice = data?.choices?.[0];
          tokens += Number(data?.usage?.total_tokens ?? 0);
          const toolCalls = choice?.message?.tool_calls ?? [];
          if (!toolCalls.length) break;
          messages.push({
            role: "assistant",
            content: choice?.message?.content ?? null,
            tool_calls: toolCalls,
          });
          for (const tc of toolCalls) {
            let args: Json = {};
            try { args = JSON.parse(tc?.function?.arguments ?? "{}"); } catch { args = {}; }
            const result = await execTool(admin, outletId, tc?.function?.name, args, internetActive, conversationId, sink);
            messages.push({ role: "tool", tool_call_id: tc.id, content: JSON.stringify(result) });
          }
          // Panggil lanjutan tanpa tool_choice agar model berhenti memanggil tool
          // dan menulis jawaban final.
          data = await callLlm(provider, messages, tools);
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
    // Pastikan kartu resep / target / peta ekspansi tampil walau model lupa menyertakannya.
    for (const key of ["prescription", "target", "scaling", "bundle", "referral", "pending"] as const) {
      const s = sink[key];
      if (!fallbackReason && s && !blocks.some((b: Json) => b?.type === s.type && b?.title === s.title)) {
        blocks.push(s);
      }
    }

    // Simpan jawaban assistant.
    await admin.from("doctor_messages").insert({
      conversation_id: conversationId, outlet_id: outletId, role: "assistant",
      content: replyText || "(blok terstruktur)", blocks, tokens,
    });
    await admin.from("doctor_conversations")
      .update({ updated_at: new Date().toISOString(), phase: String(parsed?.phase ?? profile?.phase ?? "A") })
      .eq("id", conversationId);
    const { data: convState } = await admin
      .from("doctor_conversations").select("status, escalation_level").eq("id", conversationId).maybeSingle();

    // ST15-4 (O): Kartu Identitas Bisnis.
    const openList = (openCases ?? []) as Json[];
    const activeDisease = openList.find((c: Json) => String(c.kind ?? "") === "diagnosis") ?? null;
    const activePresc = openList.find((c: Json) => String(c.kind ?? "") === "prescription") ?? null;
    const { data: prescRow } = await admin
      .from("doctor_memory").select("title, due_at")
      .eq("outlet_id", outletId).eq("kind", "prescription").eq("status", "open")
      .order("created_at", { ascending: false }).maybeSingle();
    // Health score sederhana: bonus aktivitas & stok sehat, penalti stok kritis & kasus terbuka.
    const lowRatio = Number(snap.product_count ?? 0) > 0
      ? Number(snap.low_stock_count ?? 0) / Number(snap.product_count) : 0;
    let healthScore = 70 + Math.min(20, Number(snap.trx_30d ?? 0)) - Math.round(lowRatio * 40) - openList.length * 3;
    healthScore = Math.max(5, Math.min(100, healthScore));
    const identity = {
      phase: String(parsed?.phase ?? profile?.phase ?? "A"),
      active_disease: activeDisease ? String(activeDisease.title ?? "") : null,
      active_prescription: prescRow?.title ? String(prescRow.title) : (activePresc ? String(activePresc.title) : null),
      deadline: prescRow?.due_at ?? null,
      health_score: healthScore,
      business_age_days: snap.business_age_days ?? null,
      revenue_today: snap.revenue_today ?? 0,
    };
    await admin.from("doctor_outlet_profile").update({
      health_score: healthScore,
      active_disease: activeDisease ? String(activeDisease.title ?? "").slice(0, 200) : null,
      active_disease_since: activeDisease ? new Date().toISOString() : null,
    }).eq("outlet_id", outletId);

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
      status: String(convState?.status ?? "aktif"),
      escalation_level: Number(convState?.escalation_level ?? 0),
      identity,
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
