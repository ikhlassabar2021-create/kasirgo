import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { PDFDocument, StandardFonts } from "https://esm.sh/pdf-lib@1.17.1";

// Edge Function terjadwal: bangun laporan penjualan + kirim email otomatis.
//
// Deploy:  supabase functions deploy report_scheduler --no-verify-jwt
// Jadwalkan (Supabase Scheduled Functions / pg_cron):
//   select cron.schedule('kasirgo-report', '0 * * * *', $$
//     select net.http_post(
//       url := '<PROJECT_URL>/functions/v1/report_scheduler',
//       headers := jsonb_build_object('x-cron-secret', '<CRON_SECRET>')
//     );
//   $$);
//
// Env yang dipakai: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CRON_SECRET (opsional),
// RESEND_API_KEY + REPORT_FROM_EMAIL (untuk pengiriman email; jika kosong -> dilewati).

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function rupiah(n: number): string {
  return "Rp " + Math.round(n).toLocaleString("id-ID");
}

function rangeFor(period: string): { start: Date; end: Date } {
  const now = new Date();
  const start = new Date(now);
  if (period === "weekly") {
    start.setDate(now.getDate() - 6);
    start.setHours(0, 0, 0, 0);
  } else if (period === "monthly") {
    start.setDate(1);
    start.setHours(0, 0, 0, 0);
  } else {
    start.setHours(0, 0, 0, 0);
  }
  return { start, end: now };
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/// Bangun PDF sederhana dari teks laporan (dipakai sebagai lampiran email).
async function buildReportPdf(text: string): Promise<string> {
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const size = 11;
  let page = pdf.addPage([595, 842]);
  let y = 800;
  for (const rawLine of text.split("\n")) {
    if (y < 50) {
      page = pdf.addPage([595, 842]);
      y = 800;
    }
    const line = rawLine.length > 90 ? rawLine.slice(0, 90) + "..." : rawLine;
    page.drawText(line, { x: 50, y, size, font });
    y -= 16;
  }
  return toBase64(await pdf.save());
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "Server belum dikonfigurasi." }, 500);
  }

  // Autorisasi: cron secret atau bearer service role.
  const cronSecret = Deno.env.get("CRON_SECRET") ?? "";
  const headerSecret = req.headers.get("x-cron-secret") ?? "";
  const bearer = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
  const authorized = (cronSecret && headerSecret === cronSecret) ||
    (bearer && bearer === serviceRoleKey);
  if (!authorized) return json({ error: "Tidak terautentikasi." }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const resendKey = Deno.env.get("RESEND_API_KEY") ?? "";
  const fromEmail = Deno.env.get("REPORT_FROM_EMAIL") ?? "laporan@kasirgo.app";

  const { data: schedules, error } = await admin
    .from("report_schedules")
    .select("*")
    .eq("enabled", true);

  if (error) return json({ error: error.message }, 500);

  const results: unknown[] = [];

  for (const s of schedules ?? []) {
    try {
      const outletId = String(s.outlet_id);
      const flags = (s.content_flags ?? {}) as Record<string, boolean>;
      const channels = (s.channels ?? ["email"]) as string[];
      const recipients = (s.recipients ?? []) as string[];
      const { start, end } = rangeFor(String(s.period ?? "daily"));

      const { data: outlet } = await admin
        .from("outlets").select("name").eq("id", outletId).maybeSingle();
      const name = outlet?.name ?? "Outlet";

      const { data: txs } = await admin
        .from("transactions")
        .select("final_amount, transaction_items(product_name, quantity)")
        .eq("outlet_id", outletId)
        .gte("created_at", start.toISOString())
        .lte("created_at", end.toISOString());

      const rows = txs ?? [];
      const omzet = rows.reduce(
        (sum: number, t: Record<string, unknown>) =>
          sum + Number(t.final_amount ?? 0),
        0,
      );
      const count = rows.length;
      const avg = count > 0 ? omzet / count : 0;

      const qty: Record<string, number> = {};
      for (const t of rows) {
        const items = (t.transaction_items ?? []) as Array<
          Record<string, unknown>
        >;
        for (const it of items) {
          const key = String(it.product_name ?? "-");
          qty[key] = (qty[key] ?? 0) + Number(it.quantity ?? 0);
        }
      }
      const top = Object.entries(qty).sort((a, b) => b[1] - a[1]).slice(0, 5);

      const lines: string[] = [];
      lines.push(`Laporan KasirGo - ${name}`);
      lines.push(
        `Periode: ${start.toLocaleDateString("id-ID")} s/d ${
          end.toLocaleDateString("id-ID")
        }`,
      );
      if (flags.omzet !== false) lines.push(`Total Omzet: ${rupiah(omzet)}`);
      if (flags.transaksi !== false) lines.push(`Jumlah Transaksi: ${count}`);
      if (flags.rata_rata !== false && count > 0) {
        lines.push(`Rata-rata/Transaksi: ${rupiah(avg)}`);
      }
      if (flags.produk_terlaris !== false && top.length > 0) {
        lines.push("");
        lines.push("Produk Terlaris:");
        top.forEach(([k, v], i) => lines.push(`${i + 1}. ${k} (${v}x)`));
      }
      const text = lines.join("\n");
      const html = `<pre style="font-family:Inter,Arial,sans-serif">${
        text.replace(/&/g, "&amp;").replace(/</g, "&lt;")
      }</pre>`;

      const emailRecipients = recipients.filter((r) => r.includes("@"));
      let sent = false;
      if (channels.includes("email") && emailRecipients.length > 0 && resendKey) {
        let attachments: Array<Record<string, string>> = [];
        try {
          attachments = [{
            filename: "Laporan_KasirGo.pdf",
            content: await buildReportPdf(text),
          }];
        } catch (_) {
          attachments = [];
        }
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: fromEmail,
            to: emailRecipients,
            subject: `Laporan KasirGo - ${name}`,
            html,
            attachments,
          }),
        });
        sent = res.ok;
      }

      await admin.from("report_schedules").update({
        last_sent_at: new Date().toISOString(),
      }).eq("id", s.id);

      results.push({ outlet_id: outletId, sent, recipients: emailRecipients });
    } catch (e) {
      results.push({
        outlet_id: s.outlet_id,
        error: e instanceof Error ? e.message : String(e),
      });
    }
  }

  return json({ processed: results.length, results });
});
