import type { AreaPrice, Product } from "./types";

export function priceIn(p: Pick<Product, "id" | "base_price">, ap?: AreaPrice | null) {
  if (!ap) return Number(p.base_price);
  return ap.price_override != null ? Number(ap.price_override) : Number(p.base_price) + Number(ap.price_adjustment);
}

export const STOCK_LABEL: Record<AreaPrice["stock_status"], string> = {
  in_stock: "In stock", low_stock: "Low stock", out_of_stock: "Out of stock", on_order: "On order",
};
