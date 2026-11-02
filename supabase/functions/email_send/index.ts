import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.15";

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

type Json = Record<string, any>;

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

    const body = await req.json().catch(() => ({}));
    const to = String(body.to ?? "").trim();
    const subject = String(body.subject ?? "").trim();
    const html = String(body.html ?? body.text ?? "").trim();
    if (!to || !subject || !html) {
      return json({ success: false, message: "to, subject, dan html/text wajib diisi." }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: smtp } = await admin
      .from("system_smtp_config")
      .select("*")
      .eq("is_active", true)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!smtp || !smtp.host || !smtp.username || !smtp.password) {
      return json({ success: false, message: "Konfigurasi SMTP belum lengkap / belum aktif." }, 503);
    }

    const transporter = nodemailer.createTransport({
      host: String(smtp.host),
      port: Number(smtp.port ?? 587),
      secure: Boolean(smtp.secure),
      auth: { user: String(smtp.username), pass: String(smtp.password) },
    });

    const info = await transporter.sendMail({
      from: `"${String(smtp.from_name ?? "KasirGo")}" <${String(smtp.from_email ?? smtp.username)}>`,
      to,
      subject,
      html,
    });

    return json({ success: true, message_id: info.messageId, accepted: info.accepted });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});