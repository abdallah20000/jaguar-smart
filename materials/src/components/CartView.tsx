"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { PRODUCT_COLS } from "@/lib/data";
import { egp, num, UNIT_LABEL } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import { track } from "@/lib/track";
import type { Product } from "@/lib/types";
import { openWhatsApp } from "@/lib/whatsapp";
import { ProductImage } from "./ProductCard";
import { useStore } from "./StoreProvider";

export function CartView() {
  const { cart, setQty, removeFromCart, priceOf, stockOf, area, openPicker } = useStore();
  const [products, setProducts] = useState<Record<string, Product>>({});
  const ids = cart.map((l) => l.product_id).join(",");

  useEffect(() => {
    if (!ids) return;
    supabase.from("mat_products").select(PRODUCT_COLS).in("id", ids.split(",")).then(({ data }) => {
      if (data) setProducts(Object.fromEntries((data as unknown as Product[]).map((p) => [p.id, p])));
    });
  }, [ids]);

  const lines = cart.map((l) => ({ ...l, p: products[l.product_id] })).filter((l) => l.p);
  const subtotal = lines.reduce((s, l) => s + priceOf(l.p) * l.qty, 0);
  const total = subtotal + Number(area.delivery_fee);
  const blocked = lines.some((l) => stockOf(l.product_id) === "out_of_stock");

  const sendOrder = () => {
    track("begin_checkout", { currency: "EGP", value: total });
    openWhatsApp([
      "Hello Jaguar Smart Materials, I'd like to order:",
      ...lines.map((l) => `• ${num(l.qty)} ${UNIT_LABEL[l.p.unit]} × ${l.p.name}`),
      `Delivery area: ${area.name}, ${area.governorate}`,
      `Estimated total: ${egp(total)} (incl. delivery ${egp(area.delivery_fee)})`,
    ].join("\n"), "cart");
  };

  if (!cart.length) {
    return (
      <div className="wrap max-w-xl py-16 text-center">
        <h1 className="m-0 text-3xl font-light">Your cart is empty</h1>
        <p className="text-muted">Browse materials or send us your full list and we&apos;ll price it.</p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Link href="/" className="btn btn-ink">Browse materials</Link>
          <Link href="/quote" className="btn btn-line">Request a quote</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="wrap py-10 sm:py-14">
      <h1 className="m-0 mb-6 text-[clamp(28px,4vw,40px)] font-light tracking-[-0.03em]">Cart</h1>
      <div className="grid gap-10 lg:grid-cols-[1fr_360px]">
        <ul className="m-0 list-none border-t border-line p-0">
          {lines.map(({ p, qty }) => {
            const min = Number(p.min_order_qty), step = Number(p.qty_step), price = priceOf(p);
            const out = stockOf(p.id) === "out_of_stock";
            return (
              <li key={p.id} className="grid grid-cols-[88px_1fr] gap-4 border-b border-line py-4">
                <Link href={`/product/${p.slug}`} className="block aspect-square overflow-hidden"><ProductImage product={p} /></Link>
                <div className="min-w-0">
                  <div className="flex items-start justify-between gap-3">
                    <Link href={`/product/${p.slug}`} className="font-medium leading-snug no-underline">{p.name}</Link>
                    <button type="button" onClick={() => removeFromCart(p.id)} aria-label={`Remove ${p.name}`} className="text-xl leading-none text-muted">×</button>
                  </div>
                  <p className="m-0 mt-1 text-sm text-muted">{egp(price)} / {UNIT_LABEL[p.unit]}</p>
                  {out && <p className="m-0 mt-1 text-sm text-down">Out of stock in {area.name}</p>}
                  <div className="mt-2 flex items-center justify-between gap-3">
                    <div className="flex border border-black text-sm">
                      <button type="button" className="w-9" aria-label="Decrease" disabled={qty <= min} onClick={() => setQty(p.id, Math.max(min, qty - step))}>−</button>
                      <span className="w-14 border-x border-black py-1.5 text-center tabular-nums">{num(qty)}</span>
                      <button type="button" className="w-9" aria-label="Increase" onClick={() => setQty(p.id, qty + step)}>+</button>
                    </div>
                    <b className="tabular-nums">{egp(price * qty)}</b>
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
        <aside className="h-fit border border-line p-5">
          <dl className="m-0 grid grid-cols-[1fr_auto] gap-y-2 text-sm">
            <dt className="text-muted">Subtotal</dt><dd className="m-0 tabular-nums">{egp(subtotal)}</dd>
            <dt className="text-muted">Delivery to {area.name} <button type="button" className="underline" onClick={() => openPicker(true)}>change</button></dt>
            <dd className="m-0 tabular-nums">{egp(area.delivery_fee)}</dd>
            <dt className="border-t border-line pt-3 text-base font-semibold">Total</dt><dd className="m-0 border-t border-line pt-3 text-base font-semibold tabular-nums">{egp(total)}</dd>
          </dl>
          <p className="mb-4 mt-2 text-xs text-muted">Pay cash on delivery or by bank transfer. No online payment needed.</p>
          <button type="button" className="btn btn-ink w-full" disabled={blocked || !lines.length} onClick={sendOrder}>Send order on WhatsApp</button>
          <Link href={`/quote?product=${encodeURIComponent(lines.map((l) => `${num(l.qty)} ${UNIT_LABEL[l.p.unit]} ${l.p.name}`).join("; "))}`}
            className="btn btn-line mt-3 w-full">Request a quote for this list</Link>
        </aside>
      </div>
    </div>
  );
}
