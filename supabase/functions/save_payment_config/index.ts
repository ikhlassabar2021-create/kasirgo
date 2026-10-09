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
    const merchantId = body.merchant_id != null ? String(body.merchant_id).trim() : "";
    const clientKey = body.client_key != null ? String(body.client_key).trim() : "";
    const serverKey = body.server_key != null ? String(body.server_key).trim() : "";
    const isProduction = body.is_production === true || String(body.is_production) === "true";

    if (!outletId) return json({ success: false, message: "outlet_id wajib." }, 400);

    const admin = createClient(supabaseUrl, serviceKey);

    // Hanya owner outlet yang boleh mengubah kredensial.
    const { data: outlet } = await admin
      .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
    if (!outlet) return json({ success: false, message: "Forbidden" }, 403);

    const { data: existing } = await admin
      .from("outlet_pg_configs")
      .select("server_key_secret_id, status, merchant_id, client_key, is_production")
      .eq("outlet_id", outletId)
      .maybeSingle();

    let secretId: string | null = existing?.server_key_secret_id ?? null;
    let secretChanged = false;

    if (serverKey) {
      const { data: sid, error: vaultErr } = await admin.rpc("vault_put_secret", {
        p_secret: serverKey,
        p_name: `midtrans_${outletId}`,
        p_secret_id: secretId,
      });
      if (vaultErr || !sid) {
        return json({ success: false, message: vaultErr?.message ?? "Gagal menyimpan server key." }, 500);
      }
      secretId = String(sid);
      secretChanged = true;
    }

    const row = {
      outlet_id: outletId,
      provider: "midtrans",
      merchant_id: merchantId || existing?.merchant_id || null,
      client_key: clientKey || existing?.client_key || null,
      server_key_secret_id: secretId,
      is_production: isProduction,
      // Setiap perubahan kredensial mengembalikan status ke pending (uji ulang).
      status: secretChanged ? "pending" : (existing?.status ?? "pending"),
      created_by: userId,
      updated_at: new Date().toISOString(),
    };

    const { error: upErr } = await admin
      .from("outlet_pg_configs")
      .upsert(row, { onConflict: "outlet_id" });
    if (upErr) return json({ success: false, message: upErr.message }, 500);

    return json({
      success: true,
      config: {
        provider: "midtrans",
        configured: !!(row.merchant_id && row.client_key && row.server_key_secret_id),
        merchant_id: row.merchant_id,
        client_key: row.client_key,
        has_server_key: !!row.server_key_secret_id,
        is_production: row.is_production,
        status: row.status,
      },
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
