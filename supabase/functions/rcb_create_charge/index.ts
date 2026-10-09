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

// RCB mengirim expiry sebagai Unix epoch (detik). Kolom payment_orders.expired_at
// bertipe timestamptz, jadi konversi ke ISO string (atau null bila tak valid).
const toIsoOrNull = (v: unknown): string | null => {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  if (Number.isFinite(n) && n > 0) {
    const ms = n > 1e12 ? n : n * 1000; // dukung detik maupun milidetik
    return new Date(ms).toISOString();
  }
  const d = new Date(String(v));
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ success: false, message: "Unauthorized" }, 401);
    }

    // Klien dengan JWT user: dipakai untuk verifikasi keanggotaan outlet.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ success: false, message: "Unauthorized" }, 401);
    }
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const outletId = String(body.outlet_id ?? "");
    const amount = Math.round(Number(body.amount ?? 0));
    const itemName = String(body.item_name ?? "Pembayaran KasirGo").slice(0, 50);
    const externalId = String(body.external_id ?? `KGO-${Date.now()}`);
    const purpose = String(body.purpose ?? "pos");
    const supporterId = body.supporter_id ? String(body.supporter_id) : null;
    const transactionId = body.transaction_id ? String(body.transaction_id) : null;
    const callbackUrl = body.callback_url ? String(body.callback_url) : null;

    if (!outletId || amount < 1000) {
      return json({ success: false, message: "outlet_id dan amount (min 1000) wajib." }, 400);
    }

    // Service client: baca secret config + tulis payment_orders.
    const admin = createClient(supabaseUrl, serviceKey);

    // Verifikasi user adalah anggota outlet.
    const { data: owned } = await admin
      .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
    let isMember = !!owned;
    if (!isMember) {
      const { data: role } = await admin
        .from("user_roles").select("id").eq("outlet_id", outletId).eq("user_id", userId).maybeSingle();
      isMember = !!role;
    }
    if (!isMember) return json({ success: false, message: "Forbidden" }, 403);

    const { data: integ } = await admin
      .from("platform_integrations")
      .select("is_active, secret_config, public_config")
      .eq("key", "payment_gateway")
      .maybeSingle();

    if (!integ || integ.is_active !== true) {
      return json({ success: false, message: "Payment gateway tidak aktif." }, 400);
    }

    const sc = (integ.secret_config ?? {}) as Record<string, string>;
    const pc = (integ.public_config ?? {}) as Record<string, string>;
    const baseUrl = sc.base_url ?? pc.base_url ?? "https://api.ragaciptabersama.web.id/api";
    const apiKey = sc.api_key ?? "";
    if (!apiKey) return json({ success: false, message: "API key payment gateway kosong." }, 400);

    const payload: Record<string, unknown> = {
      amount,
      item_name: itemName,
      external_id: externalId,
    };
    if (callbackUrl) payload.callback_url = callbackUrl;

    const resp = await fetch(`${baseUrl.replace(/\/$/, "")}/gateway/create`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": apiKey },
      body: JSON.stringify(payload),
    });
    const rcb = await resp.json().catch(() => ({}));
    if (!resp.ok || rcb?.success !== true) {
      return json({ success: false, message: rcb?.message ?? `RCB error ${resp.status}` }, 502);
    }

    const d = (rcb.data ?? rcb) as Record<string, unknown>;
    const orderId = String(d.order_id ?? "");
    const totalAmount = Number(d.total_amount ?? amount);

    const { error: insertErr } = await admin.from("payment_orders").insert({
      outlet_id: outletId,
      created_by: userId,
      purpose,
      provider: "rcb",
      rcb_order_id: orderId,
      external_id: externalId,
      amount,
      total_amount: totalAmount,
      kode_unik: d.kode_unik ?? null,
      status: String(d.status ?? "PENDING").toUpperCase(),
      payment_url: d.payment_url ?? null,
      qris_url: d.qris_url ?? null,
      qris_string: d.qris_string ?? null,
      payment_type: d.payment_type ?? null,
      transaction_id: transactionId,
      supporter_id: supporterId,
      expired_at: toIsoOrNull(d.expired_time ?? d.expired_at),
      raw: rcb,
    });
    if (insertErr) {
      return json(
        { success: false, message: `Gagal menyimpan order: ${insertErr.message}` },
        500,
      );
    }

    return json({
      success: true,
      order_id: orderId,
      external_id: externalId,
      amount: Number(d.amount ?? amount),
      total_amount: totalAmount,
      kode_unik: d.kode_unik ?? null,
      status: String(d.status ?? "PENDING").toUpperCase(),
      payment_url: d.payment_url ?? null,
      qris_url: d.qris_url ?? null,
      qris_string: d.qris_string ?? null,
      payment_type: d.payment_type ?? null,
      expired_time: d.expired_time ?? d.expired_at ?? null,
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
