import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (_req: Request) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: products, error: productsError } = await supabase
      .from("products")
      .select("id, outlet_id, name, stock, min_stock_alert, expired_date")
      .eq("is_active", true);

    if (productsError) {
      return new Response(JSON.stringify({ error: productsError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const now = new Date();
    const sevenDaysFromNow = new Date();
    sevenDaysFromNow.setDate(now.getDate() + 7);

    const alerts: Array<{
      outlet_id: string;
      insight_type: string;
      title: string;
      content: string;
      metadata: Record<string, unknown>;
    }> = [];

    for (const product of products ?? []) {
      const minStock = product.min_stock_alert ?? 5;
      if (product.stock <= minStock) {
        alerts.push({
          outlet_id: product.outlet_id,
          insight_type: "low_stock",
          title: "Peringatan Stok Menipis",
          content: `Stok produk ${product.name} tersisa ${product.stock}. Segera lakukan restock.`,
          metadata: {
            product_id: product.id,
            product_name: product.name,
            current_stock: product.stock,
            min_stock_alert: minStock,
          },
        });
      }

      if (product.expired_date) {
        const expDate = new Date(product.expired_date);
        if (expDate <= sevenDaysFromNow) {
          const daysLeft = Math.ceil((expDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
          alerts.push({
            outlet_id: product.outlet_id,
            insight_type: "expiring",
            title: "Peringatan Produk Kedaluwarsa",
            content: daysLeft <= 0
              ? `Produk ${product.name} sudah kedaluwarsa (${product.expired_date}).`
              : `Produk ${product.name} kedaluwarsa dalam ${daysLeft} hari (${product.expired_date}).`,
            metadata: {
              product_id: product.id,
              product_name: product.name,
              expired_date: product.expired_date,
              days_left: daysLeft,
            },
          });
        }
      }
    }

    if (alerts.length > 0) {
      const { error: insertError } = await supabase
        .from("ai_insights")
        .insert(alerts);

      if (insertError) {
        return new Response(JSON.stringify({ error: insertError.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
    }

    return new Response(
      JSON.stringify({ alerts_count: alerts.length }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
