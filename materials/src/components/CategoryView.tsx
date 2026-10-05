"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { categoryImage } from "@/lib/category-images";
import type { Category, Product } from "@/lib/types";
import { AreaBar } from "./AreaPicker";
import { ProductCard } from "./ProductCard";
import { useStore } from "./StoreProvider";

type Sort = "popular" | "priceAsc" | "priceDesc";

export function CategoryView({ category, products, others }: { category: Category; products: Product[]; others: Category[] }) {
  const t = useTranslations("category");
  const { priceOf, stockOf } = useStore();
  const [brands, setBrands] = useState<string[]>([]);
  const [min, setMin] = useState("");
  const [max, setMax] = useState("");
  const [inArea, setInArea] = useState(false);
  const [sort, setSort] = useState<Sort>("popular");
  const [showFilters, setShowFilters] = useState(false);

  const brandList = useMemo(() => [...new Map(products.filter((p) => p.brand).map((p) => [p.brand!.id, p.brand!])).values()], [products]);
  const list = useMemo(() => {
    const lo = min ? Number(min) : -Infinity, hi = max ? Number(max) : Infinity;
    const out = products.filter((p) => {
      const price = priceOf(p);
      return (!brands.length || (p.brand && brands.includes(p.brand.id))) && price >= lo && price <= hi &&
        (!inArea || stockOf(p.id) !== "out_of_stock");
    });
    if (sort === "priceAsc") out.sort((a, b) => priceOf(a) - priceOf(b));
    else if (sort === "priceDesc") out.sort((a, b) => priceOf(b) - priceOf(a));
    else out.sort((a, b) => b.popularity - a.popularity);
    return out;
  }, [products, brands, min, max, inArea, sort, priceOf, stockOf]);
  const filtered = brands.length > 0 || !!min || !!max || inArea;
  const reset = () => { setBrands([]); setMin(""); setMax(""); setInArea(false); };
  const img = categoryImage(category.icon);

  const filters = (
    <div className="grid gap-6">
      {brandList.length > 1 && (
        <fieldset className="m-0 border-0 p-0">
          <legend className="mb-2 text-sm font-semibold">{t("brand")}</legend>
          {brandList.map((b) => (
            <label key={b.id} className="flex items-center gap-2 py-1 text-sm">
              <input type="checkbox" className="h-4 w-4 accent-black" checked={brands.includes(b.id)}
                onChange={(e) => setBrands((x) => (e.target.checked ? [...x, b.id] : x.filter((y) => y !== b.id)))} />
              {b.name}
            </label>
          ))}
        </fieldset>
      )}
      <fieldset className="m-0 border-0 p-0">
        <legend className="mb-2 text-sm font-semibold">{t("price")} (EGP)</legend>
        <div className="flex gap-2">
          <div className="field flex-1"><input inputMode="numeric" placeholder={t("min")} aria-label={t("min")} value={min} onChange={(e) => setMin(e.target.value.replace(/\D/g, ""))} /></div>
          <div className="field flex-1"><input inputMode="numeric" placeholder={t("max")} aria-label={t("max")} value={max} onChange={(e) => setMax(e.target.value.replace(/\D/g, ""))} /></div>
        </div>
      </fieldset>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" className="h-4 w-4 accent-black" checked={inArea} onChange={(e) => setInArea(e.target.checked)} />
        {t("inMyArea")}
      </label>
      {filtered && <button type="button" onClick={reset} className="justify-self-start text-sm underline">{t("reset")}</button>}
    </div>
  );

  return (
    <>
      <AreaBar />
      <section className="relative overflow-hidden bg-black text-white">
        {img && (
          // eslint-disable-next-line @next/next/no-img-element -- static export
          <img src={img} alt="" className="absolute inset-0 h-full w-full object-cover opacity-40" />
        )}
        <div className="wrap relative py-10 sm:py-14">
          <nav className="mb-3 text-sm text-white/70"><Link href="/" className="no-underline hover:underline">Materials</Link> / {category.name}</nav>
          <h1 className="m-0 text-[clamp(30px,5vw,48px)] font-light tracking-[-0.03em]">{category.name}</h1>
          <p className="mb-0 mt-2 text-white/80">{t("products", { count: products.length })}</p>
        </div>
      </section>

      <div className="wrap py-6 sm:py-10">
        <div className="no-scrollbar -mx-4 mb-6 flex gap-2 overflow-x-auto px-4 sm:mx-0 sm:px-0">
          {others.map((c) => (
            <Link key={c.id} href={`/category/${c.slug}`} aria-current={c.id === category.id ? "page" : undefined}
              className={`shrink-0 border px-3 py-1.5 text-sm no-underline ${c.id === category.id ? "border-black bg-black text-white" : "border-line text-muted hover:border-black hover:text-black"}`}>
              {c.name}
            </Link>
          ))}
        </div>

        <div className="grid gap-8 lg:grid-cols-[220px_1fr]">
          <aside className="hidden lg:block">{filters}</aside>
          <div>
            <div className="mb-4 flex items-center justify-between gap-3">
              <button type="button" className="btn btn-line px-4 py-2 text-sm lg:hidden" aria-expanded={showFilters} onClick={() => setShowFilters(!showFilters)}>
                {t("filters")}{filtered ? " •" : ""}
              </button>
              <span className="hidden text-sm text-muted lg:inline">{t("products", { count: list.length })}</span>
              <div className="field">
                <select aria-label={t("sort")} value={sort} onChange={(e) => setSort(e.target.value as Sort)} className="!py-2 text-sm">
                  <option value="popular">{t("popular")}</option>
                  <option value="priceAsc">{t("priceAsc")}</option>
                  <option value="priceDesc">{t("priceDesc")}</option>
                </select>
              </div>
            </div>
            {showFilters && <div className="mb-6 border border-line p-4 lg:hidden">{filters}</div>}
            {list.length ? (
              <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3">
                {list.map((p) => <ProductCard key={p.id} product={p} />)}
              </div>
            ) : (
              <div className="border border-line p-10 text-center text-muted">
                {t("empty")} <button type="button" onClick={reset} className="underline">{t("reset")}</button>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
