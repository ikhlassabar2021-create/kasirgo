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

type SmtpSettings = {
  host: string;
  port: number;
  secure: boolean;
  username: string;
  password: string;
  fromEmail: string;
  fromName: string;
};

type SmtpReply = { code: number; lines: string[] };

class SmtpSession {
  #conn: Deno.Conn;
  #reader: ReadableStreamDefaultReader<Uint8Array>;
  #writer: WritableStreamDefaultWriter<Uint8Array>;
  #decoder = new TextDecoder();
  #buffer = "";

  constructor(conn: Deno.Conn) {
    this.#conn = conn;
    this.#reader = (conn.readable as ReadableStream<Uint8Array>).getReader();
    this.#writer = (conn.writable as WritableStream<Uint8Array>).getWriter();
  }

  async readLine(timeoutMs = 15000): Promise<string> {
    const deadline = Date.now() + timeoutMs;
    while (true) {
      const nl = this.#buffer.indexOf("\r\n");
      if (nl >= 0) {
        const line = this.#buffer.slice(0, nl);
        this.#buffer = this.#buffer.slice(nl + 2);
        return line;
      }
      const remaining = deadline - Date.now();
      if (remaining <= 0) throw new Error("SMTP timeout menunggu balasan server.");
      const chunk = await Promise.race([
        this.#reader.read(),
        new Promise<never>((_, rej) => setTimeout(() => rej(new Error("SMTP timeout.")), remaining)),
      ]);
      if (chunk.done) throw new Error("Koneksi SMTP ditutup server.");
      this.#buffer += this.#decoder.decode(chunk.value, { stream: true });
    }
  }

  async readReply(timeoutMs = 15000): Promise<SmtpReply> {
    const lines: string[] = [];
    let code = 0;
    while (true) {
      const line = await this.readLine(timeoutMs);
      lines.push(line);
      const m = line.match(/^(\d{3})([\s-]?)/);
      if (!m) continue;
      code = Number(m[1]);
      if (m[2] !== "-") break;
    }
    return { code, lines };
  }

  async expect(commands: string[], allowed: number[], timeoutMs = 15000): Promise<SmtpReply> {
    const text = commands.join("\r\n") + "\r\n";
    await this.#writer.write(new TextEncoder().encode(text));
    const reply = await this.readReply(timeoutMs);
    if (!allowed.includes(reply.code)) {
      throw new Error(`SMTP ${reply.code}: ${reply.lines.join(" ").slice(0, 200)}`);
    }
    return reply;
  }

  async startTls(hostname: string) {
    await this.expect(["STARTTLS"], [220]);
    this.#reader.releaseLock();
    this.#writer.releaseLock();
    const tlsConn = await Deno.startTls(this.#conn as Deno.TcpConn, { hostname });
    this.#conn = tlsConn;
    this.#reader = (tlsConn.readable as ReadableStream<Uint8Array>).getReader();
    this.#writer = (tlsConn.writable as WritableStream<Uint8Array>).getWriter();
    this.#buffer = "";
  }

  close() {
    try {
      this.#writer.close();
    } catch (_) { /* ignore */ }
    try {
      this.#conn.close();
    } catch (_) { /* ignore */ }
  }
}

const b64 = (s: string) => btoa(String.fromCharCode(...new TextEncoder().encode(s)));

function buildMessage(cfg: SmtpSettings, to: string, subject: string, html: string): string {
  const subjectEncoded = `=?UTF-8?B?${b64(subject)}?=`;
  const bodyB64 = b64(html).replace(/(.{76})/g, "$1\r\n");
  return [
    `From: ${cfg.fromName} <${cfg.fromEmail}>`,
    `To: <${to}>`,
    `Subject: ${subjectEncoded}`,
    "MIME-Version: 1.0",
    "Content-Type: text/html; charset=UTF-8",
    "Content-Transfer-Encoding: base64",
    "",
    bodyB64,
  ].join("\r\n");
}

async function sendTestEmail(cfg: SmtpSettings, to: string) {
  const conn = cfg.secure
    ? await Deno.connectTls({ hostname: cfg.host, port: cfg.port })
    : await Deno.connect({ hostname: cfg.host, port: cfg.port });
  const session = new SmtpSession(conn as Deno.Conn);
  try {
    const greeting = await session.readReply();
    if (greeting.code !== 220) {
      throw new Error(`SMTP greeting ${greeting.code}: ${greeting.lines.join(" ").slice(0, 160)}`);
    }
    await session.expect(["EHLO kasirgo.local"], [250]);
    if (!cfg.secure) {
      await session.startTls(cfg.host);
      await session.expect(["EHLO kasirgo.local"], [250]);
    }
    await session.expect(["AUTH LOGIN"], [334]);
    await session.expect([b64(cfg.username)], [334]);
    await session.expect([b64(cfg.password)], [235]);

    const html = `<div style="font-family:Arial,sans-serif;font-size:14px;color:#0F172A">
      <p><b>Tes Email KasirGo</b></p>
      <p>Jika Anda menerima email ini, konfigurasi SMTP sudah benar dan pengiriman email aktif.</p>
      <p style="color:#64748B;font-size:12px">Dikirim otomatis dari Control Plane KasirGo.</p>
    </div>`;
    const message = buildMessage(cfg, to, "Tes Email KasirGo", html);
    await session.expect([`MAIL FROM:<${cfg.fromEmail}>`], [250]);
    await session.expect([`RCPT TO:<${to}>`], [250, 251]);
    await session.expect(["DATA"], [354]);
    await session.expect([message, "."], [250]);
    try {
      await session.expect(["QUIT"], [221], 5000);
    } catch (_) { /* server may close first */ }
  } finally {
    session.close();
  }
}

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
    const mode = String(body?.mode ?? "apply");

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

    const settings: SmtpSettings = {
      host: String(smtp.host),
      port: Number(smtp.port ?? 587),
      secure: smtp.secure === true,
      username: String(smtp.username),
      password: String(smtp.password),
      fromEmail: String(smtp.from_email ?? smtp.username),
      fromName: String(smtp.from_name ?? "KasirGo"),
    };

    // ---- Mode tes kirim email ----
    if (mode === "test_email") {
      if (smtp.is_active !== true) {
        return json({ success: false, message: "Saklar 'Kirim Email' belum aktif." }, 409);
      }
      const to = String(body?.to ?? "").trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) {
        return json({ success: false, message: "Alamat email tujuan tidak valid." }, 400);
      }
      try {
        await sendTestEmail(settings, to);
        return json({ success: true, message: `Email tes terkirim ke ${to}.`, to });
      } catch (e) {
        return json({ success: false, message: `Gagal kirim: ${String((e as Error)?.message ?? e).slice(0, 250)}` }, 502);
      }
    }

    // ---- Mode terapkan ke Supabase Auth ----
    const pat = Deno.env.get("MGMT_PAT") ?? Deno.env.get("SUPABASE_ACCESS_TOKEN") ?? "";
    if (!pat) {
      return json({
        success: false,
        message: "MGMT_PAT (secret fungsi, PAT Management API) belum diatur untuk apply auth SMTP.",
      }, 503);
    }

    const ref = (supabaseUrl.match(/https:\/\/([a-z0-9]+)\.supabase\.co/) ?? [])[1] ?? "";
    if (!ref) return json({ success: false, message: "SUPABASE_URL tidak valid." }, 500);

    // Tiga toggle:
    //  - is_active: saklar utama kirim email (SMTP aktif)
    //  - email_confirmation_enabled: izinkan konfirmasi email saat pendaftaran
    //    (false => mailer_autoconfirm = true, daftar langsung tanpa verifikasi)
    //  - email_notifications_enabled: izinkan email notifikasi (report_scheduler dll)
    const confirmEnabled = smtp.email_confirmation_enabled === true;
    const sendEnabled = smtp.is_active === true;

    const patchBody: Record<string, unknown> = {
      // Konfirmasi email: bila toggle mati -> otomatis konfirmasi, tanpa email verifikasi.
      mailer_autoconfirm: !confirmEnabled,
    };

    if (sendEnabled) {
      // Supabase Auth memakai field datar smtp_host/smtp_port/smtp_user/smtp_pass
      // (bukan objek bersarang `smtp`).
      patchBody.smtp_host = settings.host;
      patchBody.smtp_port = String(settings.port);
      patchBody.smtp_user = settings.username;
      patchBody.smtp_pass = settings.password;
      patchBody.smtp_admin_email = settings.fromEmail;
      patchBody.smtp_sender_name = settings.fromName;
    }

    const resp = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${pat}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(patchBody),
    });

    const text = await resp.text();
    if (!resp.ok) {
      return json({ success: false, message: `Management API ${resp.status}: ${text.slice(0, 200)}` }, 502);
    }
    return json({
      success: true,
      status: resp.status,
      message: "Pengaturan email Supabase diperbarui.",
      applied: {
        mailer_autoconfirm: !confirmEnabled,
        confirmation_enabled: confirmEnabled,
        notifications_enabled: smtp.email_notifications_enabled === true,
        send_email_enabled: sendEnabled,
        smtp_applied: sendEnabled,
      },
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});