import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const body = await req.json().catch(() => ({}));
    const { device_uuid, store_name, outlet_type } = body;

    if (!device_uuid || typeof device_uuid !== "string") {
      return new Response(
        JSON.stringify({ error: "device_uuid is required" }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    const authHeader = req.headers.get("Authorization");
    let userId: string | null = null;
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const { data: userData } = await supabase.auth.getUser(token);
      userId = userData?.user?.id ?? null;
    }

    const name = store_name || "Warung Saya";
    const type = outlet_type || "kelontong";

    let { data: merchant } = await supabase
      .from("merchants")
      .select("id, device_uuid, store_name, is_verified")
      .eq("device_uuid", device_uuid)
      .maybeSingle();

    if (!merchant) {
      const { data: newMerchant, error: merchantErr } = await supabase
        .from("merchants")
        .insert({
          device_uuid,
          store_name: name,
          is_verified: false,
        })
        .select("id, device_uuid, store_name, is_verified")
        .single();

      if (merchantErr) {
        return new Response(
          JSON.stringify({ error: merchantErr.message }),
          {
            status: 500,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*",
            },
          },
        );
      }
      merchant = newMerchant;
    }

    let { data: outlet } = await supabase
      .from("outlets")
      .select("id, name, outlet_type, merchant_id, owner_id")
      .eq("merchant_id", merchant.id)
      .maybeSingle();

    if (!outlet) {
      const { data: newOutlet, error: outletErr } = await supabase
        .from("outlets")
        .insert({
          merchant_id: merchant.id,
          device_uuid,
          name,
          outlet_type: type,
          owner_id: userId,
        })
        .select("id, name, outlet_type, merchant_id, owner_id")
        .single();

      if (outletErr) {
        return new Response(
          JSON.stringify({ error: outletErr.message }),
          {
            status: 500,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*",
            },
          },
        );
      }
      outlet = newOutlet;
    } else if (userId && !outlet.owner_id) {
      await supabase
        .from("outlets")
        .update({ owner_id: userId })
        .eq("id", outlet.id);
    }

    if (userId) {
      const { data: existingRole } = await supabase
        .from("user_roles")
        .select("id")
        .eq("user_id", userId)
        .maybeSingle();

      if (!existingRole) {
        await supabase.from("user_roles").insert({
          user_id: userId,
          outlet_id: outlet.id,
          role: "owner",
          name: name,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        merchant,
        outlet,
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: errorMsg }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
