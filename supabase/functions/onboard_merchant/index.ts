import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
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
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Authorization header is required" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    const userId = userData?.user?.id ?? null;
    if (userErr || !userId) {
      return json({ error: "Sesi tidak valid" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const rawName = typeof body.store_name === "string" ? body.store_name.trim() : "";
    const name = rawName || "Warung Saya";
    const type = typeof body.outlet_type === "string" && body.outlet_type
      ? body.outlet_type
      : "kelontong";

    let { data: outlet, error: outletLookupErr } = await supabase
      .from("outlets")
      .select("id, name, type, owner_id")
      .eq("owner_id", userId)
      .order("created_at", { ascending: true })
      .limit(1)
      .maybeSingle();

    if (outletLookupErr) {
      return json({ error: outletLookupErr.message }, 500);
    }

    if (!outlet) {
      const { data: newOutlet, error: outletErr } = await supabase
        .from("outlets")
        .insert({
          owner_id: userId,
          name,
          type,
        })
        .select("id, name, type, owner_id")
        .single();

      if (outletErr) {
        return json({ error: outletErr.message }, 500);
      }
      outlet = newOutlet;
    }

    const { data: existingRole, error: roleLookupErr } = await supabase
      .from("user_roles")
      .select("id, role, outlet_id")
      .eq("user_id", userId)
      .limit(1)
      .maybeSingle();

    if (roleLookupErr) {
      return json({ error: roleLookupErr.message }, 500);
    }

    if (!existingRole) {
      const { error: roleErr } = await supabase.from("user_roles").insert({
        user_id: userId,
        outlet_id: outlet.id,
        role: "owner",
        display_name: name,
      });
      if (roleErr) {
        return json({ error: roleErr.message }, 500);
      }
    }

    return json({
      success: true,
      outlet: {
        id: outlet.id,
        name: outlet.name ?? name,
        type: outlet.type ?? type,
      },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return json({ error: errorMsg }, 500);
  }
});
