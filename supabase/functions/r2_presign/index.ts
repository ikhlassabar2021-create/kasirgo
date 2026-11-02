import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { S3Client, PutObjectCommand } from "npm:@aws-sdk/client-s3@3.637.0";
import { getSignedUrl } from "npm:@aws-sdk/s3-request-presigner@3.637.0";

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
    const key = String(body.key ?? "").trim();
    const contentType = String(body.content_type ?? "application/octet-stream");
    if (!key) return json({ success: false, message: "key wajib diisi." }, 400);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: integration } = await admin
      .from("platform_integrations")
      .select("*")
      .eq("key", "cloudflare_r2")
      .maybeSingle();

    const pub = (integration?.public_config ?? {}) as Json;
    const secret = (integration?.secret_config ?? {}) as Json;
    const accountId = String(pub.account_id ?? "").trim();
    const bucket = String(pub.bucket ?? "").trim();
    const publicUrl = String(pub.public_url ?? "").replace(/\/+$/, "");
    const accessKeyId = String(secret.access_key_id ?? "").trim();
    const secretAccessKey = String(secret.secret_access_key ?? "").trim();

    if (!accountId || !bucket || !accessKeyId || !secretAccessKey) {
      return json({
        success: false,
        message:
          "Konfigurasi Cloudflare R2 belum lengkap (account_id, bucket, access_key_id, secret_access_key).",
      }, 503);
    }

    const client = new S3Client({
      region: "auto",
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      credentials: { accessKeyId, secretAccessKey },
    });

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: contentType,
    });

    const url = await getSignedUrl(client, command, { expiresIn: 900 });

    return json({
      success: true,
      key,
      url,
      public_url: publicUrl ? `${publicUrl}/${key}` : null,
      expires_in: 900,
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});