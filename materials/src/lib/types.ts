export type Area = {
  id: string; slug: string; governorate: string; name: string;
  delivery_fee: number; delivery_days_min: number; delivery_days_max: number; sort: number;
};
export type Category = { id: string; slug: string; name: string; icon: string | null; sort: number };
export type Brand = { id: string; slug: string; name: string; logo_url: string | null; sort: number };
export type Product = {
  id: string; slug: string; sku: string | null; name: string; unit: string;
  base_price: number; min_order_qty: number; qty_step: number;
  description: string | null; specs: Record<string, string>; images: string[];
  is_featured: boolean; is_best_seller: boolean; popularity: number; is_sample: boolean;
  category: Pick<Category, "id" | "slug" | "name" | "icon">;
  brand: Pick<Brand, "id" | "slug" | "name"> | null;
};
export type AreaPrice = {
  product_id: string; price_adjustment: number; price_override: number | null;
  stock_status: "in_stock" | "low_stock" | "out_of_stock" | "on_order";
  delivery_days_min: number | null; delivery_days_max: number | null;
};
export type CurrentPrice = {
  item_id: string; area_id: string; kind: "steel" | "cement"; manufacturer: string; label: string;
  size_mm: number | null; unit: string; show_in_ticker: boolean; sort: number; is_sample: boolean;
  price: number; recorded_on: string; recorded_at: string; prev_price: number | null; change_pct: number | null;
};
export type Banner = { id: string; title: string; subtitle: string | null; image_url: string | null; link_url: string | null; cta_label: string | null };
export type Review = { id: string; rating: number; body: string | null; author_name: string; created_at: string };
