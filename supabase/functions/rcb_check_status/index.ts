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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const admin = createClient(supabaseUrl, serviceKey);

    const body = await req.json().catch(() => ({}));
    const orderId = String(body.order_id ?? "");
    if (!orderId) return json({ success: false, message: "order_id wajib." }, 400);

    const { data: integ } = await admin
      .from("platform_integrations")
      .select("secret_config, public_config")
      .eq("key", "payment_gateway")
      .maybeSingle();

    const sc = (integ?.secret_config ?? {}) as Record<string, string>;
    const pc = (integ?.public_config ?? {}) as Record<string, string>;
    const baseUrl = sc.base_url ?? pc.base_url ?? "https://api.ragaciptabersama.web.id/api";
    const apiKey = sc.api_key ?? "";

    const resp = await fetch(
      `${baseUrl.replace(/\/$/, "")}/payment-status/${encodeURIComponent(orderId)}`,
      { headers: { "x-api-key": apiKey } },
    );
    const rcb = await resp.json().catch(() => ({}));
    const d = (rcb?.data ?? rcb) as Record<string, unknown>;
    const status = String(d?.status ?? rcb?.status ?? "PENDING").toUpperCase();

    return json({ success: true, order_id: orderId, status });
  } catch (e) {
    return json({ success: false, status: "PENDING", message: String((e as Error)?.message ?? e) }, 200);
  }
});
