"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { egp, num, UNIT_LABEL } from "@/lib/format";
import { track } from "@/lib/track";
import type { Product, Review } from "@/lib/types";
import { openWhatsApp } from "@/lib/whatsapp";
import { AreaBar } from "./AreaPicker";
import { ProductCard, ProductImage } from "./ProductCard";
import { SectionHead } from "./Section";
import { StockBadge } from "./StockBadge";
import { useStore } from "./StoreProvider";

const round = (n: number) => Math.round(n * 1000) / 1000;

export function ProductView({ product, related, reviews }: { product: Product; related: Product[]; reviews: Review[] }) {
  const t = useTranslations("product");
  const { area, priceOf, stockOf, live, addToCart, openPicker } = useStore();
  const min = Number(product.min_order_qty), step = Number(product.qty_step);
  const [qty, setQty] = useState(min);
  const [added, setAdded] = useState(false);
  const price = priceOf(product);
  const stock = stockOf(product.id);
  const ap = live?.[product.id]?.ap;
  const dMin = ap?.delivery_days_min ?? area.delivery_days_min, dMax = ap?.delivery_days_max ?? area.delivery_days_max;
  const unit = UNIT_LABEL[product.unit];
  const out = stock === "out_of_stock";

  useEffect(() => {
    track("view_item", { currency: "EGP", value: product.base_price, items: [{ item_id: product.id, item_name: product.name }] });
  }, [product.id, product.name, product.base_price]);

  const change = (v: number) => setQty(Math.max(min, round(v)));
  const add = () => {
    addToCart({ product_id: product.id, qty }, { name: product.name, price });
    setAdded(true); setTimeout(() => setAdded(false), 2500);
  };
  const avg = reviews.length ? reviews.reduce((s, r) => s + r.rating, 0) / reviews.length : 0;

  return (
    <>
      <AreaBar />
      <div className="wrap py-6 sm:py-10">
        <nav className="mb-4 text-sm text-muted">
          <Link href="/" className="no-underline hover:underline">Materials</Link> / <Link href={`/category/${product.category.slug}`} className="no-underline hover:underline">{product.category.name}</Link>
        </nav>
        <div className="grid gap-8 md:grid-cols-2 md:gap-12">
          <div className="aspect-[4/3] overflow-hidden border border-line"><ProductImage product={product} /></div>
          <div>
            {product.brand && <p className="m-0 text-sm text-muted">{product.brand.name}</p>}
            <h1 className="mb-3 mt-1 text-[clamp(24px,3.4vw,34px)] font-normal leading-tight tracking-[-0.02em]">{product.name}</h1>
            {reviews.length > 0 && <p className="m-0 mb-3 text-sm">{"★".repeat(Math.round(avg))}<span className="text-line">{"★".repeat(5 - Math.round(avg))}</span> <span className="text-muted">({reviews.length})</span></p>}
            <div className="flex items-baseline gap-2">
              <span className={`text-3xl font-semibold tabular-nums ${live ? "" : "opacity-60"}`}>{egp(price)}</span>
              <span className="text-muted">{t("from")} {unit}</span>
            </div>
            <p className="mb-5 mt-1 text-xs text-muted">{t("priceNote", { area: area.name })}{product.is_sample ? " · SAMPLE price" : ""}</p>

            <dl className="m-0 mb-6 grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 border-y border-line py-4 text-sm">
              <dt className="text-muted">{t("stock")}</dt><dd className="m-0"><StockBadge status={stock} /></dd>
              <dt className="text-muted">{t("delivery", { area: area.name })}</dt>
              <dd className="m-0">{t("deliveryDays", { min: dMin, max: dMax })} · <button type="button" className="underline" onClick={() => openPicker(true)}>change</button></dd>
              <dt className="text-muted">{t("minOrder")}</dt><dd className="m-0">{num(min)} {unit}</dd>
            </dl>

            {out ? (
              <p className="border border-down px-4 py-3 text-sm text-down">{t("outOfStock", { area: area.name })}</p>
            ) : (
              <>
                <label htmlFor="qty" className="mb-2 block text-sm text-muted">{t("qty")} ({unit})</label>
                <div className="mb-4 flex items-stretch gap-3">
                  <div className="flex border border-black">
                    <button type="button" className="w-11 text-xl" aria-label="Decrease" onClick={() => change(qty - step)} disabled={qty <= min}>−</button>
                    <input id="qty" inputMode="decimal" className="w-20 border-x border-black text-center text-lg tabular-nums outline-none"
                      value={qty} onChange={(e) => { const v = Number(e.target.value.replace(/[^\d.]/g, "")); if (!Number.isNaN(v)) setQty(v); }}
                      onBlur={() => change(qty)} />
                    <button type="button" className="w-11 text-xl" aria-label="Increase" onClick={() => change(qty + step)}>+</button>
                  </div>
                  <div className="flex flex-col justify-center">
                    <span className="text-xs text-muted">{t("total")}</span>
                    <span className="text-xl font-semibold tabular-nums">{egp(price * qty)}</span>
                  </div>
                </div>
                <div className="grid gap-3">
                  <button type="button" className="btn btn-ink w-full" onClick={add} disabled={qty < min}>{added ? `✓ ${t("added")}` : t("addToCart")}</button>
                  <div className="grid grid-cols-2 gap-3">
                    <Link href={`/quote?product=${encodeURIComponent(product.name)}&qty=${qty}`} className="btn btn-line px-3 text-sm">{t("requestQuote")}</Link>
                    <button type="button" className="btn btn-line px-3 text-sm"
                      onClick={() => openWhatsApp(t("waOrder", { qty: num(qty), unit, name: product.name, area: `${area.name}, ${area.governorate}` }), "product")}>
                      {t("orderWhatsapp")}
                    </button>
                  </div>
                </div>
                {added && <p className="mt-3 text-sm"><Link href="/cart" className="font-medium underline">View cart →</Link></p>}
              </>
            )}
            {product.description && <p className="mt-8 text-[15px] leading-relaxed text-[#333]">{product.description}</p>}
          </div>
        </div>

        {Object.keys(product.specs ?? {}).length > 0 && (
          <section className="mt-12 max-w-2xl">
            <SectionHead title={t("specs")} />
            <table className="w-full border-collapse text-sm">
              <tbody>
                {product.brand && <tr className="border-t border-line"><th className="w-1/3 py-2.5 text-start font-normal text-muted">{t("brand")}</th><td>{product.brand.name}</td></tr>}
                <tr className="border-t border-line"><th className="py-2.5 text-start font-normal text-muted">{t("unit")}</th><td>{unit}</td></tr>
                {Object.entries(product.specs).map(([k, v]) => (
                  <tr key={k} className="border-t border-line"><th className="py-2.5 text-start font-normal text-muted">{k}</th><td>{v}</td></tr>
                ))}
                {product.sku && <tr className="border-y border-line"><th className="py-2.5 text-start font-normal text-muted">{t("sku")}</th><td>{product.sku}</td></tr>}
              </tbody>
            </table>
          </section>
        )}

        <section className="mt-12 max-w-2xl">
          <SectionHead title={t("reviews")} />
          {reviews.length ? (
            <ul className="m-0 list-none p-0">
              {reviews.map((r) => (
                <li key={r.id} className="border-t border-line py-4">
                  <div className="text-sm">{"★".repeat(r.rating)}<span className="text-line">{"★".repeat(5 - r.rating)}</span> <b className="ms-2 font-medium">{r.author_name}</b></div>
                  {r.body && <p className="mb-0 mt-1 text-[15px]">{r.body}</p>}
                </li>
              ))}
            </ul>
          ) : <p className="text-sm text-muted">{t("noReviews")}</p>}
        </section>

        {related.length > 0 && (
          <section className="mt-12">
            <SectionHead title={t("related")} href={`/category/${product.category.slug}`} linkLabel="View all" />
            <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-4">{related.map((p) => <ProductCard key={p.id} product={p} />)}</div>
          </section>
        )}
      </div>
    </>
  );
}
