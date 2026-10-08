// Edge Function doctor_observe (ST14-11, BAGIAN 13.15 + 13.21B).
// Dijalankan manual oleh superadmin (tombol admin) atau dijadwalkan via
// Supabase Dashboard (Scheduled functions). Bukan pg_cron (ekstensi tak terpasang).
//
// Tugas per outlet:
// 1. Evaluasi resep open yang melewati due_at: achieved bila langkah done >= 80%,
//    selainnya failed (kind=result + lesson). Recompute dari content JSON.
// 2. Teguran bertingkat bila resep open lewat tenggat / aksi belum done:
//    H-1/H = pengingat halus, >H = teguran, >H+2 atau overdue berulang = teguran keras.
//    Anti-spam: maks 1 teguran/hari/outlet (last_reminded_at di doctor_action_logs).
// 3. Simpan teguran sebagai doctor_memory kind='reprimand'.
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

type Json = Record<string, any>;

const DAY = 86400000;

function dayKey(iso: string) {
  return String(iso ?? "").slice(0, 10);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";

    // Otorisasi: superadmin, ATAU Scheduled Function (service_role).
    let isSuperadmin = false;
    if (authHeader.startsWith("Bearer ")) {
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData } = await userClient.auth.getUser().catch(() => ({ data: null }));
      if (userData?.user) {
        const { data: isAdmin } = await userClient.rpc("is_platform_admin");
        isSuperadmin = !!isAdmin;
      }
    }
    const isScheduler = authHeader.includes("service_role") ||
      (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "") !== "" && authHeader === "";

    // Scheduled functions memanggil dengan service_role key; owner/user lain ditolak.
    if (!isSuperadmin && !isScheduler) return json({ success: false, message: "Forbidden" }, 403);

    const admin = createClient(supabaseUrl, serviceKey);
    const body = await req.json().catch(() => ({})) as Json;
    const onlyOutlet = body.outlet_id ? String(body.outlet_id) : null;

    const { data: outlets } = await admin
      .from("outlets").select("id, name").order("created_at", { ascending: true }).limit(200);
    const results: Json[] = [];

    for (const o of outlets ?? []) {
      const outletId = String(o.id);
      if (onlyOutlet && outletId !== onlyOutlet) continue;

      // --- 1. Resep open yang lewat due_at -> evaluasi.
      const { data: openRx } = await admin
        .from("doctor_memory")
        .select("id, title, content, due_at, created_at")
        .eq("outlet_id", outletId).eq("kind", "prescription").eq("status", "open")
        .order("created_at", { ascending: false }).limit(5);
      for (const rx of openRx ?? []) {
        const due = rx.due_at ? new Date(String(rx.due_at)).getTime() : 0;
        if (!due || Date.now() < due) continue;
        let steps: Json[] = [];
        try {
          steps = (JSON.parse(String(rx.content ?? "")).steps ?? []) as Json[];
        } catch { steps = []; }
        const doneCount = steps.filter((s) => s?.done === true).length;
        const achieved = steps.length > 0 && doneCount / steps.length >= 0.8;
        await admin.from("doctor_memory")
          .update({ status: achieved ? "achieved" : "failed", resolved_at: new Date().toISOString() })
          .eq("id", rx.id);
        await admin.from("doctor_memory").insert({
          outlet_id: outletId,
          conversation_id: null,
          kind: "result",
          title: `${achieved ? "Resep tercapai" : "Resep gagal"}: ${String(rx.title ?? "").slice(0, 120)}`,
          content: `${doneCount}/${steps.length} langkah selesai hingga tenggat.`,
          status: "open",
          data: { prescription_id: rx.id, done: doneCount, total: steps.length },
        });
        results.push({
          outlet: o.name, rx: String(rx.title ?? "").slice(0, 60),
          status: achieved ? "achieved" : "failed",
        });
      }

      // --- 2. Teguran bertingkat untuk resep open yang mendekati/lewat tenggat.
      const { data: actives } = await admin
        .from("doctor_memory")
        .select("id, title, content, due_at, created_at")
        .eq("outlet_id", outletId).eq("kind", "prescription").eq("status", "open")
        .order("created_at", { ascending: false }).limit(1);
      const rx = (actives ?? [])[0];
      if (!rx) continue;

      // Anti-spam: cek teguran hari ini (satu per hari per outlet).
      const today = new Date().toISOString().slice(0, 10);
      const { count: todayCount } = await admin
        .from("doctor_memory")
        .select("id", { count: "exact", head: true })
        .eq("outlet_id", outletId).eq("kind", "reprimand")
        .gte("created_at", `${today}T00:00:00Z`);
      if ((todayCount ?? 0) > 0) continue;

      // Pemakaian hari ini / terakhir teguran.
      const due = rx.due_at ? new Date(String(rx.due_at)).getTime() : 0;
      if (!due) continue;
      const daysToDue = Math.round((due - Date.now()) / DAY);
      const overdueDays = -daysToDue;

      let steps: Json[] = [];
      try {
        steps = (JSON.parse(String(rx.content ?? "")).steps ?? []) as Json[];
      } catch { steps = []; }
      const doneCount = steps.filter((s) => s?.done === true).length;
      const progress = steps.length ? doneCount / steps.length : 0;

      let level: 0 | 1 | 2 | 3 = 0;
      if (daysToDue === 0 || daysToDue === 1) level = progress < 0.5 ? 1 : 0;
      else if (overdueDays >= 1) level = progress < 0.5 ? 2 : 1;
      if (overdueDays >= 3 && progress < 0.3) level = 3;
      if (level === 0) continue;

      const titles: Record<number, string> = {
        1: "Pengingat halus dari Dokter Bisnis",
        2: "TEGURAN: resep Anda belum jalan",
        3: "TEGURAN KERAS + SIDAK BOS",
      };
      const bodies: Record<number, string> = {
        1: `Resep "${String(rx.title ?? "").slice(0, 80)}" harus selesai ${overdueDays >= 0 ? "hari ini" : `besok`}. Sudah ${doneCount}/${steps.length} langkah dikerjakan. Yuk rampungkan!`,
        2: `Resep "${String(rx.title ?? "").slice(0, 80)}" sudah lewat tenggat ${overdueDays} hari, baru ${doneCount}/${steps.length} langkah selesai. Omzet tidak akan naik kalau resep hanya dibaca. Kerjakan sekarang!`,
        3: `${overdueDays} hari lewat tenggat, hanya ${doneCount}/${steps.length} langkah selesai. Ini sudah TEGURAN KERAS. Bila langkah terlalu berat, buka chat Dokter Bisnis dan minta dipecah lebih kecil.`,
      };

      await admin.from("doctor_memory").insert({
        outlet_id: outletId,
        kind: "reprimand",
        title: titles[level],
        content: bodies[level],
        status: "open",
        data: {
          prescription_id: rx.id, level,
          done: doneCount, total: steps.length,
          overdue_days: overdueDays,
        },
      });
      await admin.from("doctor_action_logs")
        .update({ last_reminded_at: new Date().toISOString(), reminder_count: 1 })
        .eq("outlet_id", outletId).eq("status", "running")
        .lt("last_reminded_at", new Date().toISOString().slice(0, 10));
      results.push({
        outlet: o.name, reprimand: level,
        rx: String(rx.title ?? "").slice(0, 60),
      });
    }

    return json({
      success: true,
      evaluated_outlets: results.length,
      results,
      disclaimer: "Observasi otomatis Dokter Bisnis (saran AI).",
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
