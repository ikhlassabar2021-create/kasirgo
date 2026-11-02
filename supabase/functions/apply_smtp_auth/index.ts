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

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const isService = authHeader === `Bearer ${serviceKey}` && !!serviceKey;

    if (!isService) {
      if (!authHeader.startsWith("Bearer ")) {
        return json({ success: false, message: "Unauthorized" }, 401);
      }
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userErr } = await userClient.auth.getUser();
      if (userErr || !userData?.user) return json({ success: false, message: "Unauthorized" }, 401);
      const { data: adminFlag } = await userClient.rpc("is_platform_admin");
      if (!adminFlag) return json({ success: false, message: "Forbidden" }, 403);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: smtp } = await admin
      .from("system_smtp_config")
      .select("*")
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!smtp || !smtp.host || !smtp.username || !smtp.password) {
      return json({ success: false, message: "Konfigurasi SMTP belum lengkap." }, 503);
    }

    const pat = Deno.env.get("MGMT_PAT") ?? Deno.env.get("SUPABASE_ACCESS_TOKEN") ?? "";
    if (!pat) {
      return json({
        success: false,
        message: "MGMT_PAT (secret fungsi, PAT Management API) belum diatur untuk apply auth SMTP.",
      }, 503);
    }

    // Derive project ref dari SUPABASE_URL: https://<ref>.supabase.co
    const ref = (supabaseUrl.match(/https:\/\/([a-z0-9]+)\.supabase\.co/) ?? [])[1] ?? "";

    const resp = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${pat}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        smtp: {
          host: String(smtp.host),
          port: Number(smtp.port ?? 587),
          user: String(smtp.username),
          pass: String(smtp.password),
          sender_name: String(smtp.from_name ?? "KasirGo"),
          admin_email: String(smtp.from_email ?? smtp.username),
        },
      }),
    });

    const text = await resp.text();
    if (!resp.ok) {
      return json({ success: false, message: `Management API ${resp.status}: ${text.slice(0, 200)}` }, 502);
    }
    return json({ success: true, status: resp.status, message: "SMTP auth Supabase diperbarui." });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});