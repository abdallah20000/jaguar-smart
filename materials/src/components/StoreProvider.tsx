"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { getCookie, setCookie } from "@/lib/cookies";
import { DEFAULT_AREA } from "@/lib/config";
import { supabase } from "@/lib/supabase";
import { priceIn } from "@/lib/pricing";
import { track } from "@/lib/track";
import type { Area, AreaPrice } from "@/lib/types";

export type CartLine = { product_id: string; qty: number };

type Store = {
  areas: Area[];
  area: Area;
  areaChosen: boolean;
  setArea: (slug: string) => void;
  pickerOpen: boolean;
  openPicker: (open: boolean) => void;
  /** live per-area data, keyed by product id (null until loaded) */
  live: Record<string, { base: number; ap: AreaPrice | null }> | null;
  priceOf: (p: { id: string; base_price: number }) => number;
  stockOf: (productId: string) => AreaPrice["stock_status"];
  cart: CartLine[];
  addToCart: (line: CartLine, meta?: { name: string; price: number }) => void;
  setQty: (productId: string, qty: number) => void;
  removeFromCart: (productId: string) => void;
  clearCart: () => void;
};

const Ctx = createContext<Store | null>(null);
export const useStore = () => {
  const s = useContext(Ctx);
  if (!s) throw new Error("useStore outside StoreProvider");
  return s;
};

const CART_COOKIE = "mat_cart";
const AREA_COOKIE = "mat_area";

function readCart(): CartLine[] {
  try {
    const raw = JSON.parse(getCookie(CART_COOKIE) || "[]") as [string, number][];
    return raw.filter((x) => Array.isArray(x) && typeof x[0] === "string" && x[1] > 0).map(([product_id, qty]) => ({ product_id, qty }));
  } catch { return []; }
}

export function StoreProvider({ areas, children }: { areas: Area[]; children: React.ReactNode }) {
  const fallback = areas.find((a) => a.slug === DEFAULT_AREA) ?? areas[0];
  const [areaSlug, setAreaSlug] = useState<string | null>(null);
  const [pickerOpen, openPicker] = useState(false);
  const [live, setLive] = useState<Store["live"]>(null);
  const [cart, setCart] = useState<CartLine[]>([]);

  // cookies are read after mount so the static HTML stays identical for every visitor
  useEffect(() => {
    const saved = getCookie(AREA_COOKIE);
    // eslint-disable-next-line react-hooks/set-state-in-effect -- hydrate from cookies once on mount
    setAreaSlug(saved && areas.some((a) => a.slug === saved) ? saved : null);
    setCart(readCart());
  }, [areas]);

  const area = areas.find((a) => a.slug === areaSlug) ?? fallback;

  useEffect(() => {
    let alive = true;
    Promise.all([
      supabase.from("mat_products").select("id,base_price"),
      supabase.from("mat_product_area_prices")
        .select("product_id,price_adjustment,price_override,stock_status,delivery_days_min,delivery_days_max").eq("area_id", area.id),
    ]).then(([prods, aps]) => {
      if (!alive || prods.error || aps.error) return;
      const byId = Object.fromEntries((aps.data as AreaPrice[]).map((x) => [x.product_id, x]));
      setLive(Object.fromEntries(prods.data.map((p) => [p.id, { base: Number(p.base_price), ap: byId[p.id] ?? null }])));
    });
    return () => { alive = false; };
  }, [area.id]);

  const setArea = useCallback((slug: string) => {
    setCookie(AREA_COOKIE, slug);
    setAreaSlug(slug);
    openPicker(false);
  }, []);

  const persist = (next: CartLine[]) => {
    setCookie(CART_COOKIE, JSON.stringify(next.map((l) => [l.product_id, l.qty])), 30);
    return next;
  };

  const value = useMemo<Store>(() => ({
    areas, area, areaChosen: areaSlug != null, setArea, pickerOpen, openPicker, live,
    priceOf: (p) => {
      const l = live?.[p.id];
      return l ? priceIn({ id: p.id, base_price: l.base }, l.ap) : Number(p.base_price);
    },
    stockOf: (id) => live?.[id]?.ap?.stock_status ?? "in_stock",
    cart,
    addToCart: (line, meta) => {
      setCart((c) => {
        const found = c.find((x) => x.product_id === line.product_id);
        return persist(found ? c.map((x) => (x === found ? { ...x, qty: x.qty + line.qty } : x)) : [...c, line]);
      });
      track("add_to_cart", { currency: "EGP", value: meta ? meta.price * line.qty : undefined,
        items: [{ item_id: line.product_id, item_name: meta?.name, quantity: line.qty, price: meta?.price }] });
    },
    setQty: (id, qty) => setCart((c) => persist(c.map((x) => (x.product_id === id ? { ...x, qty } : x)))),
    removeFromCart: (id) => setCart((c) => persist(c.filter((x) => x.product_id !== id))),
    clearCart: () => setCart(persist([])),
  }), [areas, area, areaSlug, setArea, pickerOpen, live, cart]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
