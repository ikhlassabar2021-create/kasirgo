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
    if (!outletId) return json({ success: false, message: "outlet_id wajib." }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: outlet } = await admin
      .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
    if (!outlet) return json({ success: false, message: "Forbidden" }, 403);

    const { data: cfg } = await admin
      .from("outlet_pg_configs")
      .select("merchant_id, client_key, server_key_secret_id, is_production")
      .eq("outlet_id", outletId)
      .maybeSingle();

    if (!cfg || !cfg.merchant_id || !cfg.client_key || !cfg.server_key_secret_id) {
      return json({ success: false, valid: false, message: "Kredensial belum lengkap." }, 400);
    }

    const { data: serverKey, error: vaultErr } = await admin.rpc("vault_read_secret", {
      p_secret_id: cfg.server_key_secret_id,
    });
    if (vaultErr || !serverKey) {
      return json({ success: false, valid: false, message: "Gagal membaca server key." }, 500);
    }

    const baseUrl = cfg.is_production
      ? "https://api.midtrans.com"
      : "https://api.sandbox.midtrans.com";

    // Validasi kredensial tanpa efek samping: cek status order dummy.
    // 401 => kredensial salah; 404/200 => kredensial valid.
    const probeOrderId = `KASIRGO-CONN-${Date.now()}`;
    const resp = await fetch(
      `${baseUrl}/v2/${encodeURIComponent(probeOrderId)}/status`,
      {
        method: "GET",
        headers: {
          Accept: "application/json",
          Authorization: `Basic ${btoa(`${serverKey}:`)}`,
        },
      },
    );

    const valid = resp.status !== 401;
    const result = valid
      ? `Kredensial valid (HTTP ${resp.status}).`
      : "Server key ditolak Midtrans (401).";

    await admin
      .from("outlet_pg_configs")
      .update({
        status: valid ? "verified" : "pending",
        last_tested_at: new Date().toISOString(),
        last_test_result: result,
      })
      .eq("outlet_id", outletId);

    return json({
      success: true,
      valid,
      http_status: resp.status,
      is_production: cfg.is_production,
      message: result,
    });
  } catch (e) {
    return json({ success: false, valid: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
