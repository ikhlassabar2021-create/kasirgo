import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================================
// KASIRGO PHASE 16F - Edge Function "dm_oauth"
// ----------------------------------------------------------------------------
// Koneksi OTOMATIS akun kanal (OAuth resmi platform) sebagai TAMBAHAN atas
// form manual. Alur:
//   1) App (owner)  -> POST {mode:"start", outlet_id, channel, redirect_to}
//      EF membalas {auth_url} (URL consent platform).
//   2) Owner membuka auth_url -> login di platform -> platform redirect ke
//      callback EF ini (GET ?action=callback&code=..&state=..).
//   3) EF menukar code -> access_token, menyimpannya ke dm_channel_accounts
//      (server-side, token tak pernah kembali ke klien), lalu redirect balik
//      ke aplikasi.
//
// Keamanan:
//   - Kredensial aplikasi (App ID/Secret) HANYA di
//     platform_configs.digital_marketing_llm.oauth (service_role only).
//   - dm_channel_accounts.token_enc tidak pernah dikembalikan ke klien.
//   - dm_oauth_states anti-CSRF, sekali pakai, kedaluwarsa 15 menit.
//   - verify_jwt=false (callback browser tanpa header), tetapi "start"
//     memvalidasi JWT owner secara manual.
// ============================================================================

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

type Json = Record<string, any>;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS },
  });

const html = (title: string, message: string, status = 200) =>
  new Response(
    `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
      `<title>${title}</title></head>` +
      `<body style="font-family:system-ui,Segoe UI,Roboto,sans-serif;background:#F8FAFC;color:#0F172A;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center">` +
      `<div style="max-width:420px;margin:24px;padding:24px;background:#fff;border:1px solid #E2E8F0;border-radius:16px;text-align:center">` +
      `<h2 style="color:#0284C7;margin:0 0 8px">${title}</h2>` +
      `<p style="color:#64748B;line-height:1.5;margin:0">${message}</p>` +
      `<p style="color:#94A3B8;font-size:12px;margin-top:16px">Anda boleh menutup halaman ini dan kembali ke aplikasi KasirGo.</p>` +
      `</div></body></html>`,
    { status, headers: { "Content-Type": "text/html; charset=utf-8" } },
  );

// channel -> provider OAuth
const CHANNEL_PROVIDER: Record<string, string> = {
  fb: "facebook",
  fb_group: "facebook",
  meta_ads: "facebook",
  ig: "instagram",
  tiktok: "tiktok",
  tiktok_ads: "tiktok",
  shopee: "shopee",
  shopee_ads: "shopee",
  google_ads: "google",
};

const DEFAULT_SCOPES: Record<string, string[]> = {
  facebook: ["pages_show_list", "pages_manage_posts", "pages_read_engagement", "business_management"],
  instagram: ["instagram_basic", "instagram_content_publish", "pages_show_list", "business_management"],
  tiktok: ["user.info.basic", "video.publish"],
  shopee: ["shopeeproduct.publish"],
  google: ["https://www.googleapis.com/auth/adwords"],
};

const CHANNEL_LABEL: Record<string, string> = {
  fb: "Facebook Page",
  fb_group: "Grup Facebook",
  meta_ads: "Meta Ads",
  ig: "Instagram",
  tiktok: "TikTok",
  tiktok_ads: "TikTok Ads",
  shopee: "Shopee",
  shopee_ads: "Shopee Ads",
  google_ads: "Google Ads",
};

const enc = encodeURIComponent;

async function loadOauthCfg(admin: Json, provider: string): Promise<Json> {
  const { data } = await admin
    .from("platform_configs")
    .select("value")
    .eq("key", "digital_marketing_llm")
    .eq("scope", "global")
    .maybeSingle();
  const oauth = (data?.value?.oauth ?? {}) as Json;
  let pcfg = (oauth[provider] ?? {}) as Json;
  if (provider === "instagram" && !pcfg?.app_id) pcfg = (oauth["facebook"] ?? {}) as Json;
  return pcfg ?? {};
}

function buildAuthorizeUrl(pcfg: Json, redirectUri: string, state: string, provider: string) {
  const authorizeUrl = String(pcfg.authorize_url ?? "");
  const appId = String(pcfg.app_id ?? "");
  const scopes: string[] = Array.isArray(pcfg.scopes) && pcfg.scopes.length
    ? pcfg.scopes.map((s: unknown) => String(s))
    : (DEFAULT_SCOPES[provider] ?? []);
  const u = new URL(authorizeUrl);
  u.searchParams.set("client_id", appId);
  u.searchParams.set("redirect_uri", redirectUri);
  u.searchParams.set("state", state);
  u.searchParams.set("response_type", "code");
  if (scopes.length) u.searchParams.set("scope", scopes.join(" "));
  const extra = (pcfg.extra_auth_params ?? {}) as Json;
  for (const [k, v] of Object.entries(extra)) u.searchParams.set(k, String(v));
  return u.toString();
}

async function exchangeToken(pcfg: Json, provider: string, code: string, redirectUri: string): Promise<Json> {
  const tokenUrl = String(pcfg.token_url ?? "");
  const appId = String(pcfg.app_id ?? "");
  const appSecret = String(pcfg.app_secret ?? "");
  const method = String(pcfg.token_method ?? "GET").toUpperCase();
  const form = new URLSearchParams({
    client_id: appId,
    client_secret: appSecret,
    redirect_uri: redirectUri,
    code,
    grant_type: "authorization_code",
  });
  let resp: Response;
  if (method === "POST") {
    resp = await fetch(tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: form.toString(),
    });
  } else {
    const u = new URL(tokenUrl);
    for (const [k, v] of form.entries()) u.searchParams.set(k, v);
    resp = await fetch(u.toString(), { headers: { Accept: "application/json" } });
  }
  const text = await resp.text();
  let data: Json = {};
  try {
    data = JSON.parse(text);
  } catch {
    // Some providers reply form-encoded; parse best-effort.
    data = Object.fromEntries(new URLSearchParams(text));
  }
  if (!resp.ok || data?.error || (!data?.access_token && !data?.accessToken)) {
    const msg = data?.error_description ?? data?.error?.message ?? data?.error ?? data?.message ?? `HTTP ${resp.status}`;
    throw new Error(String(msg).slice(0, 300));
  }
  return data;
}

async function fetchAccount(pcfg: Json, accessToken: string): Promise<{ name: string; id: string }> {
  const accountUrl = String(pcfg.account_url ?? "");
  if (!accountUrl) return { name: "", id: "" };
  try {
    const u = new URL(accountUrl);
    if (accessToken) u.searchParams.set("access_token", accessToken);
    const resp = await fetch(u.toString(), { headers: { Authorization: `Bearer ${accessToken}` } });
    const data = await resp.json().catch(() => ({}));
    const nameField = String(pcfg.account_name_field ?? "name");
    const idField = String(pcfg.account_id_field ?? "id");
    const node = Array.isArray(data?.data) ? (data.data[0] ?? {}) : data;
    return { name: String(node?.[nameField] ?? ""), id: String(node?.[idField] ?? "") };
  } catch {
    return { name: "", id: "" };
  }
}

function redirectTo(target: string, params: Record<string, string>) {
  const sep = target.includes("?") ? "&" : "?";
  const qs = new URLSearchParams(params).toString();
  return Response.redirect(`${target}${sep}${qs}`, 302);
}

// Allowlist origin redirect balik (cegah open-redirect). Bisa ditimpa via env
// DM_OAUTH_ALLOWED_ORIGINS (dipisah koma). Scheme custom app (kasirgo://) aman.
const ALLOWED_ORIGINS: string[] = (Deno.env.get("DM_OAUTH_ALLOWED_ORIGINS") ??
  "https://ikhlassabar2021-create.github.io,http://localhost:8080,http://localhost:3000")
  .split(",").map((s) => s.trim()).filter(Boolean);

const ALLOWED_SCHEMES = ["kasirgo:", "kasirgo-dev:"];

function sanitizeRedirect(target: string): string {
  if (!target) return "";
  try {
    const u = new URL(target);
    if (ALLOWED_SCHEMES.includes(u.protocol)) return target;
    if ((u.protocol === "https:" || u.protocol === "http:") && ALLOWED_ORIGINS.includes(u.origin)) {
      return target;
    }
  } catch {
    return "";
  }
  return "";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const admin = createClient(supabaseUrl, serviceKey);

  const reqUrl = new URL(req.url);

  // ---------------------------------------------------------------------------
  // CALLBACK (GET, tanpa JWT) - platform mengembalikan ?code=&state=
  // ---------------------------------------------------------------------------
  if (req.method === "GET" && reqUrl.searchParams.get("action") === "callback") {
    const code = reqUrl.searchParams.get("code") ?? "";
    const state = reqUrl.searchParams.get("state") ?? "";
    const oauthError = reqUrl.searchParams.get("error") ?? "";
    const oauthErrorDesc = reqUrl.searchParams.get("error_description") ?? "";

    if (!state) return html("Koneksi gagal", "Parameter state tidak ditemukan. Silakan ulangi dari aplikasi.", 400);

    const { data: st } = await admin
      .from("dm_oauth_states")
      .select("*")
      .eq("state", state)
      .maybeSingle();
    const fallback = sanitizeRedirect((st?.redirect_to as string) ?? "") || `${supabaseUrl}`;

    if (!st) return html("Koneksi gagal", "Sesi koneksi tidak ditemukan atau sudah kedaluwarsa. Silakan ulangi dari aplikasi.", 400);
    if (st.consumed_at) return redirectTo(fallback, { dm_oauth: "error", channel: st.channel, message: "Sesi sudah dipakai." });
    if (new Date(st.expires_at).getTime() < Date.now()) {
      return redirectTo(fallback, { dm_oauth: "error", channel: st.channel, message: "Sesi kedaluwarsa." });
    }

    if (oauthError) {
      await admin.from("dm_oauth_states").update({ consumed_at: new Date().toISOString() }).eq("state", state);
      return redirectTo(fallback, {
        dm_oauth: "error",
        channel: st.channel,
        message: (oauthErrorDesc || oauthError).slice(0, 200),
      });
    }
    if (!code) return redirectTo(fallback, { dm_oauth: "error", channel: st.channel, message: "Kode otorisasi tidak diterima." });

    try {
      const pcfg = await loadOauthCfg(admin, st.provider);
      const redirectUri = String(pcfg.redirect_uri ?? `${supabaseUrl}/functions/v1/dm_oauth?action=callback`);
      const tokenData = await exchangeToken(pcfg, st.provider, code, redirectUri);
      const accessToken = String(tokenData.access_token ?? tokenData.accessToken ?? "");
      const acct = await fetchAccount(pcfg, accessToken);

      // Simpan token TERENKRIPSI (kunci hanya di Vault; fungsi service_role).
      let tokenStored: string | null = accessToken || null;
      if (accessToken) {
        const { data: enc } = await admin.rpc("dm_encrypt_token", { p_token: accessToken });
        if (typeof enc === "string" && enc.length) tokenStored = enc;
      }

      await admin.from("dm_channel_accounts").upsert(
        {
          outlet_id: st.outlet_id,
          channel: st.channel,
          account_name: acct.name || CHANNEL_LABEL[st.channel] || st.channel,
          external_id: acct.id || null,
          token_enc: tokenStored,
          is_connected: true,
          last_sync: new Date().toISOString(),
        },
        { onConflict: "outlet_id,channel" },
      );
      await admin.from("dm_oauth_states").update({ consumed_at: new Date().toISOString() }).eq("state", state);

      return redirectTo(fallback, {
        dm_oauth: "connected",
        channel: st.channel,
        account: acct.name || "",
      });
    } catch (e) {
      await admin.from("dm_oauth_states").update({ consumed_at: new Date().toISOString() }).eq("state", state);
      return redirectTo(fallback, {
        dm_oauth: "error",
        channel: st.channel,
        message: String((e as Error)?.message ?? e).slice(0, 200),
      });
    }
  }

  // ---------------------------------------------------------------------------
  // START (POST, JWT owner) - bangun auth_url
  // ---------------------------------------------------------------------------
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) return json({ success: false, message: "Unauthorized" }, 401);
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) return json({ success: false, message: "Unauthorized" }, 401);
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const mode = String(body.mode ?? "start");
    const outletId = String(body.outlet_id ?? "");
    const channel = String(body.channel ?? "");
    const redirectToApp = sanitizeRedirect(String(body.redirect_to ?? "").slice(0, 500));

    if (mode !== "start") return json({ success: false, message: "mode tidak dikenal" }, 400);
    if (!outletId || !channel) return json({ success: false, message: "outlet_id & channel wajib." }, 400);

    const provider = CHANNEL_PROVIDER[channel];
    if (!provider) return json({ success: false, message: `Kanal ${channel} belum mendukung koneksi otomatis.` }, 400);

    const { data: isAdminFlag } = await userClient.rpc("is_platform_admin");
    const isPlatformAdmin = !!isAdminFlag;
    if (!isPlatformAdmin) {
      const { data: owned } = await admin
        .from("outlets").select("id").eq("id", outletId).eq("owner_id", userId).maybeSingle();
      let isMember = !!owned;
      if (!isMember) {
        const { data: role } = await admin
          .from("user_roles").select("id").eq("outlet_id", outletId).eq("user_id", userId).maybeSingle();
        isMember = !!role;
      }
      if (!isMember) return json({ success: false, message: "Forbidden" }, 403);
    }

    const pcfg = await loadOauthCfg(admin, provider);
    if (!pcfg?.app_id || !pcfg?.app_secret || !pcfg?.authorize_url || !pcfg?.token_url) {
      return json({
        success: true,
        configured: false,
        message:
          `Koneksi otomatis ${CHANNEL_LABEL[channel] ?? channel} belum diaktifkan superadmin. ` +
          `Anda tetap bisa memakai form manual (isi nama akun + token).`,
      });
    }

    const state = `${crypto.randomUUID()}${crypto.randomUUID().replace(/-/g, "")}`.slice(0, 64);
    // Bersihkan state kedaluwarsa (anti-CSRF) agar tabel tidak menumpuk.
    try { await admin.rpc("dm_prune_oauth_states"); } catch { /* non-fatal */ }
    const { error: insErr } = await admin.from("dm_oauth_states").insert({
      state,
      outlet_id: outletId,
      channel,
      provider,
      user_id: userId,
      redirect_to: redirectToApp || null,
    });
    if (insErr) return json({ success: false, message: insErr.message }, 500);

    const redirectUri = String(pcfg.redirect_uri ?? `${supabaseUrl}/functions/v1/dm_oauth?action=callback`);
    const authUrl = buildAuthorizeUrl(pcfg, redirectUri, state, provider);
    return json({ success: true, configured: true, auth_url: authUrl, channel, provider });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});
