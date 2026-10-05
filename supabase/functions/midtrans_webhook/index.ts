import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

async function sha512Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-512", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const admin = createClient(supabaseUrl, serviceKey);

    const body = await req.json().catch(() => ({}));
    const orderId = String(body.order_id ?? "");
    const statusCode = String(body.status_code ?? "");
    const grossAmount = String(body.gross_amount ?? "");
    const signature = String(body.signature_key ?? "").toLowerCase();
    const txStatus = String(body.transaction_status ?? "").toLowerCase();
    const fraudStatus = String(body.fraud_status ?? "").toLowerCase();

    if (!orderId || !signature) {
      return json({ success: false, message: "order_id & signature_key wajib." }, 400);
    }

    // Cari order + outlet.
    let outletId: string | null = null;
    let orderRow: Record<string, unknown> | null = null;

    const { data: po } = await admin
      .from("payment_orders")
      .select("id, outlet_id, purpose, supporter_id, transaction_id, status")
      .eq("provider_order_id", orderId)
      .maybeSingle();

    if (po) {
      outletId = String(po.outlet_id);
      orderRow = po;
    } else {
      const { data: trx } = await admin
        .from("transactions")
        .select("id, outlet_id")
        .eq("provider_ref", orderId)
        .maybeSingle();
      if (trx) {
        outletId = String(trx.outlet_id);
        orderRow = { transaction_id: trx.id };
      }
    }

    if (!outletId) return json({ success: false, message: "Order tidak ditemukan." }, 404);

    const { data: cfg } = await admin
      .from("outlet_pg_configs")
      .select("server_key_secret_id")
      .eq("outlet_id", outletId)
      .maybeSingle();

    if (!cfg?.server_key_secret_id) {
      return json({ success: false, message: "Konfigurasi outlet tidak ditemukan." }, 404);
    }

    const { data: serverKey, error: vaultErr } = await admin.rpc("vault_read_secret", {
      p_secret_id: cfg.server_key_secret_id,
    });
    if (vaultErr || !serverKey) {
      return json({ success: false, message: "Gagal membaca server key." }, 500);
    }

    // Signature: SHA512(order_id + status_code + gross_amount + server_key).
    const expected = await sha512Hex(orderId + statusCode + grossAmount + String(serverKey));
    if (expected !== signature) {
      return json({ success: false, message: "Invalid signature" }, 401);
    }

    const paid = (txStatus === "settlement") ||
      (txStatus === "capture" && fraudStatus === "accept");

    let newStatus = "PENDING";
    if (paid) newStatus = "PAID";
    else if (txStatus === "expire") newStatus = "EXPIRED";
    else if (txStatus === "deny" || txStatus === "cancel") newStatus = "FAILED";
    else if (txStatus === "refund" || txStatus === "partial_refund") newStatus = "REFUND";

    // Idempotent: jangan ulang efek samping bila sudah PAID.
    const alreadyPaid = String(orderRow?.status ?? "").toUpperCase() === "PAID";
    if (alreadyPaid && paid) {
      return json({ success: true, order_id: orderId, status: "PAID", idempotent: true });
    }

    if (orderRow?.id) {
      await admin
        .from("payment_orders")
        .update({
          status: newStatus,
          paid_at: paid ? new Date().toISOString() : null,
          updated_at: new Date().toISOString(),
          raw: body,
        })
        .eq("id", orderRow.id);
    }

    if (paid && !alreadyPaid && orderRow?.purpose === "subscription" && orderRow?.supporter_id) {
      const end = new Date();
      end.setDate(end.getDate() + 30);
      await admin
        .from("supporters")
        .update({
          status: "active",
          start_date: new Date().toISOString(),
          end_date: end.toISOString(),
          pg_reference_id: orderId,
          updated_at: new Date().toISOString(),
        })
        .eq("id", orderRow.supporter_id);
    }

    if (paid && orderRow?.transaction_id) {
      await admin
        .from("transactions")
        .update({
          payment_status: "paid",
          paid_at: new Date().toISOString(),
          provider_ref: orderId,
        })
        .eq("id", orderRow.transaction_id);
    }

    return json({ success: true, order_id: orderId, status: newStatus });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
