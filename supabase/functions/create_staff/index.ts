import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "Server belum dikonfigurasi." }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) return json({ error: "Tidak terautentikasi." }, 401);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: callerData, error: callerErr } = await admin.auth.getUser(
      token,
    );
    const caller = callerData?.user;
    if (callerErr || !caller) {
      return json({ error: "Sesi tidak valid." }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");
    const role = String(body.role ?? "");
    const name = String(body.name ?? "").trim();
    const outletId = String(body.outlet_id ?? "").trim();

    if (!email || !password || !outletId) {
      return json({ error: "email, password, dan outlet_id wajib diisi." }, 400);
    }
    if (password.length < 6) {
      return json({ error: "Password minimal 6 karakter." }, 400);
    }
    if (role !== "admin" && role !== "cashier" && role !== "kitchen") {
      return json({ error: "Role harus admin, cashier, atau kitchen." }, 400);
    }

    const { data: callerRole } = await admin
      .from("user_roles")
      .select("role")
      .eq("user_id", caller.id)
      .eq("outlet_id", outletId)
      .maybeSingle();

    if (!callerRole || !["owner", "admin"].includes(callerRole.role)) {
      return json(
        { error: "Anda tidak berhak menambah staf di outlet ini." },
        403,
      );
    }

    const { data: outlet } = await admin
      .from("outlets")
      .select("id")
      .eq("id", outletId)
      .maybeSingle();
    if (!outlet) return json({ error: "Outlet tidak ditemukan." }, 404);

    const { data: created, error: createErr } = await admin.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          staff_email: email,
          staff_role: role,
          outlet_id: outletId,
          ...(name ? { staff_name: name } : {}),
        },
      });

    if (createErr) {
      const msg = createErr.message.toLowerCase();
      if (msg.includes("already") || msg.includes("registered") || msg.includes("exists")) {
        return json({ error: "Email sudah terdaftar. Gunakan email lain." }, 409);
      }
      return json({ error: createErr.message }, 400);
    }

    const staffId = created.user?.id;
    if (!staffId) return json({ error: "Gagal membuat akun." }, 500);

    // Trigger handle_new_user juga memasang role; upsert untuk memastikan.
    await admin.from("user_roles").upsert(
      { user_id: staffId, outlet_id: outletId, role },
      { onConflict: "user_id,outlet_id" },
    );

    return json({ success: true, user_id: staffId });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return json({ error: errorMsg }, 500);
  }
});
