import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
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
    const orderId = String(body.order_id ?? body.external_id ?? "");
    const status = String(body.status ?? "").toUpperCase();
    const signature = String(
      body.signature ?? body.signature_key ?? req.headers.get("x-signature") ?? body.hash ?? "",
    ).toLowerCase();

    if (!orderId || !status) return json({ success: false, message: "order_id & status wajib." }, 400);

    const { data: integ } = await admin
      .from("platform_integrations")
      .select("secret_config")
      .eq("key", "payment_gateway")
      .maybeSingle();
    const apiKey = ((integ?.secret_config ?? {}) as Record<string, string>).api_key ?? "";

    // Verifikasi signature: SHA256(order_id + status + api_key).
    if (apiKey && signature) {
      const expected = await sha256Hex(orderId + status + apiKey);
      if (expected !== signature) {
        return json({ success: false, message: "Invalid signature" }, 401);
      }
    }

    const { data: order } = await admin
      .from("payment_orders")
      .select("id, outlet_id, purpose, supporter_id")
      .eq("rcb_order_id", orderId)
      .maybeSingle();

    if (!order) return json({ success: false, message: "Order tidak ditemukan." }, 404);

    const paid = ["PAID", "SUCCESS", "SETTLEMENT"].includes(status);
    await admin
      .from("payment_orders")
      .update({
        status: paid ? "PAID" : status,
        paid_at: paid ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
        raw: body,
      })
      .eq("id", order.id);

    if (paid && order.purpose === "subscription" && order.supporter_id) {
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
        .eq("id", order.supporter_id);
    }

    return json({ success: true, order_id: orderId, status: paid ? "PAID" : status });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
