// Read-only catalog queries. Used at build time (static pages) and in the browser for live data.
import { supabase } from "./supabase";
import type { Area, Banner, Brand, Category, CurrentPrice, Product, Review } from "./types";

export const PRODUCT_COLS =
  "id,slug,sku,name,unit,base_price,min_order_qty,qty_step,description,specs,images,is_featured,is_best_seller,popularity,is_sample," +
  "category:mat_categories!inner(id,slug,name,icon),brand:mat_brands(id,slug,name)";

// rows are typed by our own types (the column list is built at runtime, so PostgREST can't infer it)
async function must<T>(p: PromiseLike<{ data: unknown; error: unknown }>): Promise<T> {
  const { data, error } = await p;
  if (error) throw error;
  return data as T;
}

export const getAreas = () =>
  must<Area[]>(supabase.from("mat_areas").select("id,slug,governorate,name,delivery_fee,delivery_days_min,delivery_days_max,sort").order("sort"));
export const getCategories = () =>
  must<Category[]>(supabase.from("mat_categories").select("id,slug,name,icon,sort").order("sort"));
export const getBrands = () =>
  must<Brand[]>(supabase.from("mat_brands").select("id,slug,name,logo_url,sort").order("sort"));
export const getProducts = () =>
  must<Product[]>(supabase.from("mat_products").select(PRODUCT_COLS).order("popularity", { ascending: false }));
export const getProduct = (slug: string) =>
  must<Product | null>(supabase.from("mat_products").select(PRODUCT_COLS).eq("slug", slug).maybeSingle());
export const getBanners = () =>
  must<Banner[]>(supabase.from("mat_banners").select("id,title,subtitle,image_url,link_url,cta_label").order("sort"));
export const getReviews = (productId: string) =>
  must<Review[]>(supabase.from("mat_reviews").select("id,rating,body,author_name,created_at").eq("product_id", productId).order("created_at", { ascending: false }).limit(20));

export const getCurrentPrices = (areaId: string) =>
  must<CurrentPrice[]>(supabase.from("mat_current_prices").select("*").eq("area_id", areaId).order("sort"));

export async function getPriceHistory(areaId: string, days = 30) {
  const since = new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
  // one request per kind keeps each response under the API's 1,000-row page size
  const [steel, cement] = await Promise.all(
    ["steel", "cement"].map((kind) =>
      must<{ item_id: string; price: number; recorded_on: string }[]>(
        supabase.from("mat_price_history").select("item_id,price,recorded_on,item:mat_daily_price_items!inner(kind)")
          .eq("area_id", areaId).eq("item.kind", kind).gte("recorded_on", since).order("recorded_on"),
      ),
    ),
  );
  const byItem: Record<string, number[]> = {};
  for (const r of [...steel, ...cement]) (byItem[r.item_id] ??= []).push(Number(r.price));
  return byItem;
}

/** Categories that actually have products (empty ones are never shown). */
export function nonEmptyCategories(categories: Category[], products: Product[]) {
  const used = new Set(products.map((p) => p.category.id));
  return categories.filter((c) => used.has(c.id));
}
