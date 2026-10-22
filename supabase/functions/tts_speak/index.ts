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

/// Suara neural Microsoft Edge (gratis, tanpa API key).
/// id-ID-ArdiNeural = pria, id-ID-GadisNeural = wanita.
const EDGE_TOKEN = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";

type PersonaVoice = {
  voice: string;
  rate: string;
  pitch: string;
  volume: string;
  /// Kecepatan putar audio di klien (1.0 = normal). Google Translate TTS
  /// hanya menyediakan satu warna suara, jadi tempo inilah pembeda persona.
  playback_rate: number;
};

const PERSONA_VOICES: Record<string, PersonaVoice> = {
  bos_tegas: {
    voice: "id-ID-ArdiNeural",
    rate: "+2%",
    pitch: "-2Hz",
    volume: "+0%",
    playback_rate: 0.93,
  },
  partner_santai: {
    voice: "id-ID-GadisNeural",
    rate: "+0%",
    pitch: "+3Hz",
    volume: "+0%",
    playback_rate: 1.06,
  },
  analis_taktis: {
    voice: "id-ID-ArdiNeural",
    rate: "-8%",
    pitch: "-5Hz",
    volume: "+0%",
    playback_rate: 0.98,
  },
};

const MAX_CHARS = 1200;

/// Cache audio dalam memori instance (kalimat sapaan/teguran sering diulang).
const CACHE = new Map<string, Uint8Array>();

function pickVoice(persona: string): PersonaVoice {
  return PERSONA_VOICES[persona] ?? PERSONA_VOICES.bos_tegas;
}

function xmlEscape(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function base64(bytes: Uint8Array): string {
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}

/// Sec-MS-GEC wajib sejak 2024: SHA256(ticks + token), ticks dibulatkan 5 menit.
async function secMsGec(): Promise<string> {
  let ticks = (Math.floor(Date.now() / 1000) + 11644473600) * 10000000;
  ticks -= ticks % 3000000000;
  const data = new TextEncoder().encode(`${ticks}${EDGE_TOKEN}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

/// Sintesis MP3 lewat WebSocket Edge Read-Aloud. Null bila gagal.
async function edgeTts(text: string, v: PersonaVoice): Promise<Uint8Array | null> {
  const gec = await secMsGec();
  const connId = crypto.randomUUID().replace(/-/g, "");
  const url =
    `wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1` +
    `?TrustedClientToken=${EDGE_TOKEN}&Sec-MS-GEC=${gec}` +
    `&Sec-MS-GEC-Version=1-130.0.2849.68&ConnectionId=${connId}`;

  return await new Promise<Uint8Array | null>((resolve) => {
    let settled = false;
    const chunks: Uint8Array[] = [];
    let total = 0;
    let ws: WebSocket | null = null;

    const finish = (value: Uint8Array | null) => {
      if (settled) return;
      settled = true;
      try {
        ws?.close();
      } catch (_) { /* ignore */ }
      resolve(value);
    };

    const timer = setTimeout(() => finish(null), 12000);

    try {
      ws = new WebSocket(url);
    } catch (_) {
      clearTimeout(timer);
      return resolve(null);
    }
    ws.binaryType = "arraybuffer";

    ws.onopen = () => {
      const stamp = new Date().toString();
      ws?.send(
        `X-Timestamp:${stamp}\r\nContent-Type:application/json; charset=utf-8\r\n` +
          `Path:speech.config\r\n\r\n` +
          JSON.stringify({
            context: {
              synthesis: {
                audio: {
                  metadataoptions: {
                    sentenceBoundaryEnabled: "false",
                    wordBoundaryEnabled: "false",
                  },
                  outputFormat: "audio-24khz-48kbitrate-mono-mp3",
                },
              },
            },
          }),
      );
      const ssml =
        `<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='id-ID'>` +
        `<voice name='${v.voice}'><prosody rate='${v.rate}' pitch='${v.pitch}' volume='${v.volume}'>` +
        `${xmlEscape(text)}</prosody></voice></speak>`;
      ws?.send(
        `X-RequestId:${connId}\r\nContent-Type:application/ssml+xml\r\n` +
          `X-Timestamp:${stamp}Z\r\nPath:ssml\r\n\r\n${ssml}`,
      );
    };

    ws.onmessage = (ev: MessageEvent) => {
      const data = ev.data;
      if (typeof data === "string") {
        if (data.includes("Path:turn.end")) {
          clearTimeout(timer);
          if (total === 0) return finish(null);
          const out = new Uint8Array(total);
          let at = 0;
          for (const c of chunks) {
            out.set(c, at);
            at += c.length;
          }
          return finish(out);
        }
        return;
      }
      const buf = new Uint8Array(data as ArrayBuffer);
      if (buf.length < 2) return;
      const headerLen = (buf[0] << 8) | buf[1];
      const header = new TextDecoder().decode(buf.subarray(2, 2 + headerLen));
      if (!header.includes("Path:audio")) return;
      const audio = buf.subarray(2 + headerLen);
      chunks.push(audio);
      total += audio.length;
    };

    ws.onerror = () => {
      clearTimeout(timer);
      finish(null);
    };
    ws.onclose = () => {
      clearTimeout(timer);
      finish(null);
    };
  });
}

/// Google Translate TTS (gratis, tanpa key). Maks ~190 karakter/req.
async function googleTts(text: string): Promise<Uint8Array | null> {
  const parts: string[] = [];
  let rest = text.trim();
  while (rest.length > 0) {
    if (rest.length <= 180) {
      parts.push(rest);
      break;
    }
    let cut = rest.lastIndexOf(". ", 180);
    if (cut < 60) cut = rest.lastIndexOf(", ", 180);
    if (cut < 60) cut = rest.lastIndexOf(" ", 180);
    if (cut < 40) cut = 180;
    parts.push(rest.slice(0, cut + 1).trim());
    rest = rest.slice(cut + 1).trim();
  }
  const bufs: Uint8Array[] = [];
  for (const part of parts) {
    if (!part) continue;
    const q = encodeURIComponent(part);
    const url =
      `https://translate.google.com/translate_tts?ie=UTF-8&q=${q}&tl=id&client=tw-ob`;
    try {
      const res = await fetch(url, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36",
          Referer: "https://translate.google.com/",
        },
      });
      if (!res.ok) return null;
      const bytes = new Uint8Array(await res.arrayBuffer());
      if (bytes.length < 500) return null;
      bufs.push(bytes);
    } catch (_) {
      return null;
    }
  }
  if (bufs.length === 0) return null;
  const total = bufs.reduce((s, b) => s + b.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const b of bufs) {
    out.set(b, at);
    at += b.length;
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const started = Date.now();
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.toLowerCase().startsWith("bearer ")) {
    return json({ error: "Unauthorized" }, 401);
  }
  try {
    const client = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: auth } } },
    );
    const { data: userRes } = await client.auth.getUser();
    if (!userRes?.user) return json({ error: "Unauthorized" }, 401);
  } catch (_) {
    return json({ error: "Unauthorized" }, 401);
  }

  let body: Json = {};
  try {
    body = await req.json();
  } catch (_) {
    return json({ error: "Body tidak valid" }, 400);
  }

  const raw = String(body.text ?? "").replace(/\s+/g, " ").trim();
  if (!raw) return json({ error: "Teks kosong" }, 400);
  const text = raw.length > MAX_CHARS ? raw.slice(0, MAX_CHARS) : raw;
  const persona = String(body.persona ?? "bos_tegas");
  const v = pickVoice(persona);
  const engine = String(body.engine ?? "google");

  let audio: Uint8Array | null = null;
  let provider = "google";
  let voice = "id-ID-google";

  // Mesin utama: Google Translate TTS (gratis, tanpa key, reachable).
  const cacheKey = `${persona}|${text}`;
  const cached = CACHE.get(cacheKey);
  if (cached) {
    return json({
      ok: true,
      provider: "cache",
      voice,
      persona,
      playback_rate: v.playback_rate,
      mime: "audio/mpeg",
      ms: Date.now() - started,
      audio: base64(cached),
    });
  }

  audio = await googleTts(text);

  // Edge neural (pria/wanita) hanya bila diminta eksplisit; jaringan keluar
  // Supabase saat ini memblokir WebSocket-nya, jadi bukan jalur default.
  if (!audio && engine === "edge") {
    audio = await edgeTts(text, v);
    if (audio) {
      provider = "edge";
      voice = v.voice;
    }
  }

  if (!audio) {
    return json({ error: "Gagal membuat suara. Coba lagi." }, 502);
  }

  if (CACHE.size >= 40) {
    const first = CACHE.keys().next();
    if (!first.done) CACHE.delete(first.value);
  }
  CACHE.set(cacheKey, audio);

  return json({
    ok: true,
    provider,
    voice,
    persona,
    playback_rate: v.playback_rate,
    mime: "audio/mpeg",
    ms: Date.now() - started,
    audio: base64(audio),
  });
});
