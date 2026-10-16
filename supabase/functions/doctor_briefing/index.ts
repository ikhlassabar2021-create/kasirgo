// Edge Function doctor_briefing (Dokter Bisnis 3.0 - Briefing "Apel Pagi").
//
// Menghasilkan briefing pagi server-side untuk satu outlet (1 baris / outlet /
// hari, disimpan di tabel doctor_briefings):
//   1. Cuaca hari ini dari BMKG open data (tanpa API key) -> fallback Open-Meteo
//      memakai koordinat outlet bila BMKG tidak tersedia.
//   2. Catatan kalender: libur nasional (config `briefing.holidays` atau bawaan),
//      akhir pekan, dan jendela "tanggal gajian" (insight omzet UMKM).
//   3. Stok menipis (stok <= max(min_stock_alert, briefing.stok_minimum)).
//
// Sumber publik & legal; hasil fetch di-cache di tabel web_cache (hemat kuota).
// WAJIB mencantumkan sumber (URL) + tanggal; bila data tak tersedia -> tandai
// "perlu verifikasi", jangan mengarang.
//
// Pemanggil: owner outlet (Authorization Bearer user JWT) ATAU scheduler
// (service_role). Superadmin boleh untuk outlet mana pun.
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

const WIB_OFFSET_MS = 7 * 3600000;
const DAY = 86400000;

// Tanggal (YYYY-MM-DD) menurut zona WIB (UTC+7).
function wibDate(ts: number = Date.now()): string {
  return new Date(ts + WIB_OFFSET_MS).toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// Pemetaan alamat -> kode adm4 BMKG (kecamatan). Kode dipakai untuk prakiraan
// cuaca BMKG. Bila alamat tidak dikenali -> pakai default (Jakarta Pusat).
// ---------------------------------------------------------------------------
const CITY_ADM4: Record<string, { adm4: string; label: string }> = {
  jakarta: { adm4: "31.71.03.1001", label: "Jakarta Pusat" },
  bandung: { adm4: "32.73.05.1001", label: "Bandung" },
  surabaya: { adm4: "35.78.10.1001", label: "Surabaya" },
  semarang: { adm4: "33.74.06.1001", label: "Semarang" },
  yogyakarta: { adm4: "34.71.05.1001", label: "Yogyakarta" },
  jogja: { adm4: "34.71.05.1001", label: "Yogyakarta" },
  medan: { adm4: "12.71.05.1001", label: "Medan" },
  makassar: { adm4: "73.71.03.1001", label: "Makassar" },
  palembang: { adm4: "16.71.03.1001", label: "Palembang" },
  denpasar: { adm4: "51.71.02.1001", label: "Denpasar" },
  malang: { adm4: "35.73.09.1001", label: "Malang" },
  bekasi: { adm4: "32.75.04.1001", label: "Bekasi" },
  tangerang: { adm4: "36.71.05.1001", label: "Tangerang" },
  depok: { adm4: "32.76.05.1001", label: "Depok" },
  bogor: { adm4: "32.01.11.1001", label: "Bogor" },
  solo: { adm4: "33.72.04.1001", label: "Surakarta" },
  surakarta: { adm4: "33.72.04.1001", label: "Surakarta" },
  padang: { adm4: "13.71.05.1001", label: "Padang" },
  balikpapan: { adm4: "64.71.04.1001", label: "Balikpapan" },
  pontianak: { adm4: "61.71.04.1001", label: "Pontianak" },
  manado: { adm4: "71.71.04.1001", label: "Manado" },
  batam: { adm4: "21.71.06.1001", label: "Batam" },
  pekanbaru: { adm4: "14.71.05.1001", label: "Pekanbaru" },
  banjarmasin: { adm4: "63.71.03.1001", label: "Banjarmasin" },
};

function resolveLocation(address: string | null, cfg: Json): { adm4: string; label: string } {
  const def = {
    adm4: String(cfg?.default_adm4 ?? "31.71.03.1001"),
    label: String(cfg?.default_city ?? "Jakarta Pusat"),
  };
  const addr = String(address ?? "").toLowerCase();
  if (!addr) return def;
  for (const key of Object.keys(CITY_ADM4)) {
    if (addr.includes(key)) return CITY_ADM4[key];
  }
  return def;
}

// ---------------------------------------------------------------------------
// web_cache: baca bila belum kedaluwarsa, simpan bila kosong.
// ---------------------------------------------------------------------------
async function cacheGet(admin: any, url: string): Promise<string | null> {
  const { data } = await admin
    .from("web_cache").select("content, fetched_at, ttl_seconds")
    .eq("url", url).maybeSingle();
  if (!data?.content) return null;
  const fetched = new Date(String(data.fetched_at)).getTime();
  const ttl = Number(data.ttl_seconds ?? 3600) * 1000;
  if (Date.now() - fetched > ttl) return null;
  return String(data.content);
}

async function cachePut(admin: any, url: string, content: string, label: string, ttl: number) {
  await admin.from("web_cache").upsert({
    url, content, source_label: label,
    fetched_at: new Date().toISOString(), ttl_seconds: ttl,
  }, { onConflict: "url" });
}

// ---------------------------------------------------------------------------
// Cuaca: BMKG (utama) -> Open-Meteo (fallback koordinat).
// ---------------------------------------------------------------------------
async function fetchBmkg(admin: any, adm4: string, label: string) {
  const url = `https://api.bmkg.go.id/publik/prakiraan-cuaca?adm4=${adm4}`;
  let raw = await cacheGet(admin, url);
  if (!raw) {
    const res = await fetch(url, { headers: { "User-Agent": "KasirGo/3.0" } });
    if (!res.ok) return null;
    raw = await res.text();
    await cachePut(admin, url, raw, `BMKG ${label}`, 3600);
  }
  let j: Json;
  try { j = JSON.parse(raw); } catch { return null; }
  const flat: Json[] = (j?.data?.[0]?.cuaca ?? []).flat();
  if (!flat.length) return null;
  const now = Date.now();
  const upcoming = flat.filter((s) => {
    const t = new Date(String(s.local_datetime ?? s.datetime ?? "")).getTime();
    return !isNaN(t) && t >= now - 3600000;
  });
  const slots = (upcoming.length ? upcoming : flat).slice(0, 4);
  if (!slots.length) return null;
  const descs = Array.from(new Set(slots.map((s) => String(s.weather_desc ?? "")).filter(Boolean)));
  const temps = slots.map((s) => Number(s.t)).filter((n) => !isNaN(n));
  const hum = slots.map((s) => Number(s.hu)).filter((n) => !isNaN(n));
  const rain = slots.map((s) => Number(s.tp)).filter((n) => !isNaN(n));
  return {
    available: true,
    source: "BMKG",
    source_url: url,
    location: `${j?.lokasi?.kotkab ?? label}${j?.lokasi?.provinsi ? ", " + j.lokasi.provinsi : ""}`,
    desc: descs.join(" / "),
    temp_c: temps.length ? `${Math.min(...temps)}-${Math.max(...temps)}` : null,
    humidity: hum.length ? Math.round(hum.reduce((a, b) => a + b, 0) / hum.length) : null,
    rain_mm: rain.length ? Math.max(...rain) : null,
    wind: slots[0]?.wd ? String(slots[0].wd) : null,
    fetched_at: new Date().toISOString(),
  };
}

async function fetchOpenMeteo(admin: any, lat: number, lon: number) {
  const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
    `&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m&timezone=Asia%2FJakarta`;
  let raw = await cacheGet(admin, url);
  if (!raw) {
    const res = await fetch(url, { headers: { "User-Agent": "KasirGo/3.0" } });
    if (!res.ok) return null;
    raw = await res.text();
    await cachePut(admin, url, raw, "Open-Meteo", 3600);
  }
  let j: Json;
  try { j = JSON.parse(raw); } catch { return null; }
  const cur = j?.current;
  if (!cur) return null;
  const codeMap: Record<number, string> = {
    0: "Cerah", 1: "Cerah berawan", 2: "Berawan", 3: "Mendung",
    45: "Berkabut", 48: "Berkabut", 51: "Gerimis", 53: "Gerimis", 55: "Gerimis",
    61: "Hujan ringan", 63: "Hujan", 65: "Hujan lebat",
    80: "Hujan lokal", 81: "Hujan lokal", 82: "Hujan lebat",
    95: "Hujan petir", 96: "Hujan petir", 99: "Hujan petir",
  };
  const code = Number(cur.weather_code);
  return {
    available: true,
    source: "Open-Meteo",
    source_url: url,
    location: "Koordinat outlet",
    desc: codeMap[code] ?? "Cuaca terkini",
    temp_c: cur.temperature_2m != null ? String(cur.temperature_2m) : null,
    humidity: cur.relative_humidity_2m != null ? Number(cur.relative_humidity_2m) : null,
    rain_mm: cur.precipitation != null ? Number(cur.precipitation) : null,
    wind: null,
    fetched_at: new Date().toISOString(),
  };
}

// ---------------------------------------------------------------------------
// Kalender: libur nasional (bawaan, bisa di-override via config) + weekend +
// jendela gajian. Tanggal hari raya keagamaan bisa bergeser -> tandai verifikasi.
// ---------------------------------------------------------------------------
const DEFAULT_HOLIDAYS: Record<string, string> = {
  "2026-01-01": "Tahun Baru Masehi",
  "2026-02-17": "Tahun Baru Imlek",
  "2026-03-19": "Hari Suci Nyepi",
  "2026-04-03": "Wafat Isa Almasih",
  "2026-05-01": "Hari Buruh Internasional",
  "2026-05-14": "Kenaikan Isa Almasih",
  "2026-06-01": "Hari Lahir Pancasila",
  "2026-08-17": "Hari Kemerdekaan RI",
  "2026-12-25": "Hari Raya Natal",
  "2027-01-01": "Tahun Baru Masehi",
  "2027-08-17": "Hari Kemerdekaan RI",
  "2027-12-25": "Hari Raya Natal",
};

function calendarNote(dateKey: string, cfg: Json) {
  const holidays: Record<string, string> = { ...DEFAULT_HOLIDAYS, ...(cfg?.holidays ?? {}) };
  const notes: string[] = [];
  const dow = new Date(`${dateKey}T00:00:00+07:00`).getDay(); // 0 Minggu .. 6 Sabtu
  const dom = Number(dateKey.slice(8, 10));
  const holiday = holidays[dateKey];
  if (holiday) notes.push(`Hari ini libur: ${holiday}. Banyak toko tutup - atur stok & jam buka.`);
  if (dow === 0) notes.push("Hari Minggu - keluarga banyak belanja, siapkan stok camilan & minuman.");
  else if (dow === 6) notes.push("Hari Sabtu - akhir pekan, biasanya ramai sore/malam.");
  if (dom >= 25 || dom <= 5) notes.push("Masa tanggal gajian (25-awal bulan) - daya beli naik, jaga stok cepat laku.");
  if (!notes.length) notes.push("Hari kerja biasa - fokus jaga stok dan layanan cepat.");
  return notes.join(" ");
}

// ---------------------------------------------------------------------------
// Stok menipis.
// ---------------------------------------------------------------------------
async function loadLowStock(admin: any, outletId: string, minStock: number) {
  const { data } = await admin
    .from("products").select("name, stock, unit, min_stock_alert")
    .eq("outlet_id", outletId).order("stock", { ascending: true }).limit(200);
  const rows = (data ?? []) as Json[];
  return rows
    .filter((p) => Number(p.stock ?? 0) <= Math.max(Number(p.min_stock_alert ?? 0), minStock))
    .slice(0, 10)
    .map((p) => ({
      name: String(p.name ?? ""),
      stock: Number(p.stock ?? 0),
      unit: p.unit ? String(p.unit) : null,
    }));
}

// ---------------------------------------------------------------------------
// Generate briefing untuk satu outlet.
// ---------------------------------------------------------------------------
async function buildBriefing(admin: any, outlet: Json, cfg: Json, force: boolean) {
  const outletId = String(outlet.id);
  const dateKey = wibDate();

  if (!force) {
    const { data: existing } = await admin
      .from("doctor_briefings").select("*")
      .eq("outlet_id", outletId).eq("briefing_date", dateKey).maybeSingle();
    if (existing) return { ...existing, cached: true };
  }

  const minStock = Number(cfg?.stok_minimum ?? 5);

  // Cuaca.
  let weather: Json | null = null;
  if (cfg?.cuaca !== false) {
    const loc = resolveLocation(outlet.address, cfg);
    try {
      weather = await fetchBmkg(admin, loc.adm4, loc.label);
    } catch { weather = null; }
    if (!weather && outlet.latitude != null && outlet.longitude != null) {
      try {
        weather = await fetchOpenMeteo(admin, Number(outlet.latitude), Number(outlet.longitude));
      } catch { weather = null; }
    }
    if (!weather) {
      weather = {
        available: false, source: null, source_url: null,
        note: "Data cuaca belum tersedia untuk lokasi ini (perlu verifikasi).",
      };
    }
  }

  const calendarNoteText = cfg?.kalender !== false ? calendarNote(dateKey, cfg) : null;
  const lowStock = await loadLowStock(admin, outletId, minStock);

  // Rangkuman + item terstruktur untuk kartu briefing.
  const parts: string[] = [];
  parts.push(`Selamat pagi, ${String(outlet.name ?? "Pemilik")}!`);
  if (weather?.available) {
    const t = weather.temp_c ? ` (${weather.temp_c}\u00b0C)` : "";
    parts.push(`Cuaca ${weather.location}: ${weather.desc}${t}.`);
  }
  if (calendarNoteText) parts.push(calendarNoteText);
  if (lowStock.length) {
    parts.push(`Ada ${lowStock.length} produk stok menipis - segera kulakan: ${lowStock.slice(0, 3).map((p) => p.name).join(", ")}${lowStock.length > 3 ? ", dll" : ""}.`);
  } else {
    parts.push("Stok terpantau aman hari ini.");
  }

  const items: Json[] = [];
  if (weather) {
    items.push({
      icon: "weather",
      label: "Cuaca Hari Ini",
      text: weather.available
        ? `${weather.desc}${weather.temp_c ? `, ${weather.temp_c}\u00b0C` : ""}${weather.rain_mm ? `, hujan ${weather.rain_mm}mm` : ""} - ${weather.location}`
        : (weather.note ?? "Data cuaca belum tersedia."),
      source: weather.source ?? null,
      source_url: weather.source_url ?? null,
    });
  }
  if (calendarNoteText) items.push({ icon: "calendar", label: "Catatan Hari Ini", text: calendarNoteText });
  items.push({
    icon: "stock",
    label: "Stok Perlu Diisi",
    text: lowStock.length ? lowStock.map((p) => `${p.name} (${p.stock}${p.unit ? " " + p.unit : ""})`).join(", ") : "Semua stok aman.",
  });

  const row = {
    outlet_id: outletId,
    briefing_date: dateKey,
    weather: weather ?? {},
    calendar_note: calendarNoteText,
    low_stock: lowStock,
    summary: parts.join(" "),
    items,
  };

  const { data: saved } = await admin
    .from("doctor_briefings").upsert(row, { onConflict: "outlet_id,briefing_date" })
    .select("*").maybeSingle();

  return { ...(saved ?? row), cached: false };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";

    const admin = createClient(supabaseUrl, serviceKey);
    const body = await req.json().catch(() => ({})) as Json;
    const force = body.force === true;

    // Otorisasi: user (owner/superadmin) ATAU scheduler (service_role).
    // Deteksi service_role dari klaim `role` pada payload JWT (tanpa verifikasi
    // ulang - gateway Supabase sudah memvalidasi JWT karena verify_jwt=true).
    let jwtRole = "";
    if (authHeader.startsWith("Bearer ")) {
      try {
        const payload = authHeader.slice(7).split(".")[1];
        jwtRole = String(JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")))?.role ?? "");
      } catch { jwtRole = ""; }
    }

    let userId: string | null = null;
    let isPlatformAdmin = false;
    if (authHeader.startsWith("Bearer ") && jwtRole !== "service_role") {
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData } = await userClient.auth.getUser().catch(() => ({ data: null }));
      if (userData?.user) {
        userId = userData.user.id;
        const { data: isAdmin } = await userClient.rpc("is_platform_admin");
        isPlatformAdmin = !!isAdmin;
      }
    }
    const isScheduler = jwtRole === "service_role";

    if (!userId && !isScheduler) return json({ success: false, message: "Unauthorized" }, 401);

    const { data: pcfg } = await admin
      .from("platform_configs").select("value").eq("key", "business_doctor").maybeSingle();
    const globalCfg: Json = pcfg?.value ?? {};
    const briefCfg: Json = globalCfg?.briefing ?? {};
    if (briefCfg.aktif === false) {
      return json({ success: true, disabled: true, message: "Briefing dimatikan superadmin." });
    }

    const onlyOutlet = body.outlet_id ? String(body.outlet_id) : null;

    // Scheduler: generate untuk semua outlet (atau satu bila diminta).
    if (isScheduler && (body.all === true || !onlyOutlet)) {
      const { data: outlets } = await admin
        .from("outlets").select("id, name, address, latitude, longitude")
        .order("created_at", { ascending: true }).limit(500);
      const results: Json[] = [];
      for (const o of outlets ?? []) {
        try {
          const b = await buildBriefing(admin, o, briefCfg, force);
          results.push({ outlet_id: o.id, outlet: o.name, briefing_date: b.briefing_date, cached: b.cached });
        } catch (e) {
          results.push({ outlet_id: o.id, outlet: o.name, error: String((e as Error)?.message ?? e).slice(0, 200) });
        }
      }
      return json({ success: true, generated: results.length, results, disclaimer: "Briefing otomatis Dokter Bisnis (saran AI)." });
    }

    if (!onlyOutlet) return json({ success: false, message: "outlet_id wajib." }, 400);

    // Otorisasi outlet: owner outlet sendiri, atau superadmin, atau scheduler.
    if (!isScheduler && !isPlatformAdmin) {
      const { data: owned } = await admin
        .from("outlets").select("id").eq("id", onlyOutlet).eq("owner_id", userId).maybeSingle();
      if (!owned) return json({ success: false, message: "Forbidden" }, 403);
    }

    const { data: outlet } = await admin
      .from("outlets").select("id, name, address, latitude, longitude")
      .eq("id", onlyOutlet).maybeSingle();
    if (!outlet) return json({ success: false, message: "Outlet tidak ditemukan." }, 404);

    const briefing = await buildBriefing(admin, outlet, briefCfg, force);
    return json({ success: true, briefing, disclaimer: "Briefing otomatis Dokter Bisnis (saran AI), bukan jaminan." });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e) }, 500);
  }
});
