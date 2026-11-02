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

const ABIS = ["arm64", "armeabi_v7a", "x86_64"] as const;

function toBase64(buf: Uint8Array): string {
  let binary = "";
  const CHUNK = 0x8000;
  for (let i = 0; i < buf.length; i += CHUNK) {
    binary += String.fromCharCode(...buf.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ success: false, message: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  const token = Deno.env.get("GITHUB_TOKEN") ?? "";
  const owner = Deno.env.get("GITHUB_OWNER") ?? "ikhlassabar2021-create";
  const repo = Deno.env.get("GITHUB_REPO") ?? "kasirgo";
  const branch = "gh-pages";
  const pagesDomain = Deno.env.get("PAGES_DOMAIN") ?? "https://dokterbisnis.web.id";

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
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

    const body = await req.json();
    const abi = String(body?.abi ?? "");
    if (!ABIS.includes(abi as (typeof ABIS)[number])) {
      return json({ success: false, message: "abi tidak valid (arm64|armeabi_v7a|x86_64)" }, 400);
    }
    if (!token) {
      return json({ success: false, message: "GITHUB_TOKEN secret belum diatur." }, 503);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const storagePath = `kasirgo-${abi}.apk`;
    const { data: fileData, error: dlErr } = await admin.storage
      .from("app-updates")
      .download(storagePath);
    if (dlErr || !fileData) {
      return json({
        success: false,
        message: `Gagal membaca file dari Storage: ${dlErr?.message ?? "file tidak ada"}`,
      }, 404);
    }
    const bytes = new Uint8Array(await fileData.arrayBuffer());
    if (bytes.length === 0) return json({ success: false, message: "File kosong." }, 400);
    if (bytes.length > 99 * 1024 * 1024) {
      return json({ success: false, message: "APK terlalu besar (>99 MB)." }, 413);
    }

    const content = toBase64(bytes);
    const ghPath = `updates/kasirgo-${abi}.apk`;

    const gh = (path: string, opts: RequestInit = {}) =>
      fetch(`https://api.github.com/repos/${owner}/${repo}${path}`, {
        ...opts,
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
          "Content-Type": "application/json",
          ...(opts.headers ?? {}),
        },
      });

    const readJson = async (r: Response) => {
      const t = await r.text();
      try {
        return JSON.parse(t);
      } catch {
        return {};
      }
    };

    const refResp = await gh(`/git/ref/heads/${branch}`);
    if (!refResp.ok) {
      const j = await readJson(refResp);
      throw new Error(`GitHub ref ${refResp.status}: ${(j?.message ?? "").slice(0, 200)}`);
    }
    const headSha = ((await readJson(refResp)).object?.sha) as string;

    const commitResp = await gh(`/git/commits/${headSha}`);
    if (!commitResp.ok) throw new Error(`GitHub commit ${commitResp.status}`);
    const baseTreeSha = ((await readJson(commitResp)).tree?.sha) as string;

    const blobResp = await gh(`/git/blobs`, {
      method: "POST",
      body: JSON.stringify({ content, encoding: "base64" }),
    });
    if (!blobResp.ok) {
      const j = await readJson(blobResp);
      throw new Error(`GitHub blob ${blobResp.status}: ${(j?.message ?? "").slice(0, 200)}`);
    }
    const blobSha = ((await readJson(blobResp)).sha) as string;

    const treeResp = await gh(`/git/trees`, {
      method: "POST",
      body: JSON.stringify({
        base_tree: baseTreeSha,
        tree: [{ path: ghPath, mode: "100644", type: "blob", sha: blobSha }],
      }),
    });
    if (!treeResp.ok) throw new Error(`GitHub tree ${treeResp.status}`);
    const newTreeSha = ((await readJson(treeResp)).sha) as string;

    const newCommitResp = await gh(`/git/commits`, {
      method: "POST",
      body: JSON.stringify({
        message: `chore(updates): upload APK ${abi}`,
        tree: newTreeSha,
        parents: [headSha],
      }),
    });
    if (!newCommitResp.ok) throw new Error(`GitHub commit create ${newCommitResp.status}`);
    const newCommitSha = ((await readJson(newCommitResp)).sha) as string;

    const patchResp = await gh(`/git/refs/heads/${branch}`, {
      method: "PATCH",
      body: JSON.stringify({ sha: newCommitSha, force: false }),
    });
    if (!patchResp.ok) throw new Error(`GitHub ref update ${patchResp.status}`);

    return json({
      success: true,
      path: ghPath,
      url: `${pagesDomain}/${ghPath}`,
      sha: newCommitSha,
      bytes: bytes.length,
    });
  } catch (e) {
    return json({ success: false, message: String((e as Error)?.message ?? e).slice(0, 300) }, 500);
  }
});