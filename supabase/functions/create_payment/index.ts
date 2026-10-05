import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ success: false, message: "Unauthorized" }, 401);
    }

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
    const purpose = String(body.purpose ?? "pos");
    const supporterId = body.supporter_id ? String(body.supporter_id) : null;
    const transactionId = body.transaction_id ? String(body.transaction_id) : null;
    const externalId = body.external_id
      ? String(body.external_id)
      : `KGO-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    if (!outletId || amount < 1000) {
      return json({ success: false, message: "outlet_id dan amount (min 1000) wajib." }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    // Verifikasi user adalah anggota outlet (owner atau staf terdaftar).
    const { data: owned } = await admin
      .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
    let isMember = !!owned;
    if (!isMember) {
      const { data: role } = await admin
        .from("user_roles").select("id").eq("outlet_id", outletId).eq("user_id", userId).maybeSingle();
      isMember = !!role;
    }
    if (!isMember) return json({ success: false, message: "Forbidden" }, 403);

    const { data: cfg } = await admin
      .from("outlet_pg_configs")
      .select("merchant_id, client_key, server_key_secret_id, is_production, status")
      .eq("outlet_id", outletId)
      .maybeSingle();

    if (!cfg || !cfg.merchant_id || !cfg.client_key || !cfg.server_key_secret_id) {
      return json({ success: false, message: "Payment gateway outlet belum dikonfigurasi." }, 400);
    }

    const { data: serverKey, error: vaultErr } = await admin.rpc("vault_read_secret", {
      p_secret_id: cfg.server_key_secret_id,
    });
    if (vaultErr || !serverKey) {
      return json({ success: false, message: "Gagal membaca server key." }, 500);
    }

    const baseUrl = cfg.is_production
      ? "https://api.midtrans.com"
      : "https://api.sandbox.midtrans.com";

    const payload = {
      payment_type: "qris",
      transaction_details: { order_id: externalId, gross_amount: amount },
      item_details: [{ id: "item", price: amount, quantity: 1, name: itemName }],
    };

    const resp = await fetch(`${baseUrl}/v2/charge`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        Authorization: `Basic ${btoa(`${serverKey}:`)}`,
      },
      body: JSON.stringify(payload),
    });
    const mt = await resp.json().catch(() => ({}));

    if (!resp.ok) {
      return json(
        {
          success: false,
          message: mt?.status_message ?? `Midtrans error ${resp.status}`,
          http_status: resp.status,
        },
        502,
      );
    }

    const qrString = String(mt?.qr_string ?? "");
    const actions = Array.isArray(mt?.actions) ? mt.actions : [];
    const qrAction = actions.find((a: Record<string, unknown>) => a?.name === "generate-qr-code");
    const status = String(mt?.transaction_status ?? "pending").toUpperCase();

    await admin.from("payment_orders").insert({
      outlet_id: outletId,
      created_by: userId,
      purpose,
      provider: "midtrans",
      provider_order_id: externalId,
      external_id: externalId,
      amount,
      total_amount: Number(mt?.gross_amount ?? amount),
      status: status === "PENDING" ? "PENDING" : status,
      qris_url: qrAction?.url ?? null,
      qris_string: qrString || null,
      payment_type: String(mt?.payment_type ?? "qris"),
      transaction_id: transactionId,
      supporter_id: supporterId,
      expired_at: mt?.expiry_time ?? null,
      raw: mt,
    });

    return json({
      success: true,
      order_id: externalId,
      provider_ref: externalId,
      transaction_id: mt?.transaction_id ?? null,
      amount: Number(mt?.gross_amount ?? amount),
      status,
      qris_string: qrString,
      qris_url: qrAction?.url ?? null,
      payment_type: String(mt?.payment_type ?? "qris"),
      expiry_time: mt?.expiry_time ?? null,
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
