import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { AreaBar } from "@/components/AreaPicker";
import { BannerSlider } from "@/components/BannerSlider";
import { PriceTicker } from "@/components/PriceTicker";
import { ProductCard } from "@/components/ProductCard";
import { SectionHead } from "@/components/Section";
import { categoryImage } from "@/lib/category-images";
import { DEFAULT_AREA } from "@/lib/config";
import { getAreas, getBanners, getBrands, getCategories, getCurrentPrices, getProducts, nonEmptyCategories } from "@/lib/data";

export default async function Home() {
  const t = await getTranslations("store");
  const [areas, banners, brands, categories, products] = await Promise.all([getAreas(), getBanners(), getBrands(), getCategories(), getProducts()]);
  const prices = await getCurrentPrices(areas.find((a) => a.slug === DEFAULT_AREA)!.id);
  const cats = nonEmptyCategories(categories, products);
  const usedBrands = brands.filter((b) => products.some((p) => p.brand?.id === b.id));
  const best = products.filter((p) => p.is_best_seller).slice(0, 8);
  const featured = products.filter((p) => p.is_featured).slice(0, 8);
  const count = (id: string) => products.filter((p) => p.category.id === id).length;

  return (
    <>
      <PriceTicker initial={prices} />
      <AreaBar />
      <BannerSlider banners={banners} />
      <section className="border-b border-[#eee6d8] bg-cream">
        <ul className="wrap m-0 grid list-none grid-cols-2 gap-x-4 gap-y-4 p-0 py-5 sm:grid-cols-4">
          {[
            ["M3 7h11v9H3zM14 10h4l3 3v3h-7M7 19a2 2 0 1 0 0-.1M17 19a2 2 0 1 0 0-.1", "Delivery in 24–48h", "Cairo & Giza"],
            ["M3 6h18v12H3zM3 10h18M7 15h4", "Cash on delivery", "or bank transfer"],
            ["M4 19V9M10 19V5M16 19v-7M22 19H2", "Prices updated daily", "steel & cement"],
            ["M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z", "Original brands", "Ezz, Beshay, Jotun…"],
          ].map(([d, title, sub]) => (
            <li key={title} className="flex items-center gap-3">
              <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-gold-light text-gold-dark">
                <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>
              </span>
              <span className="leading-tight"><b className="block text-sm font-semibold">{title}</b><span className="text-xs text-muted">{sub}</span></span>
            </li>
          ))}
        </ul>
      </section>

      <section className="wrap py-12 sm:py-16">
        <SectionHead title={t("categories")} />
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-5">
          {cats.map((c) => {
            const img = categoryImage(c.icon);
            return (
              <Link key={c.id} href={`/category/${c.slug}`} className="group relative block aspect-[4/3] overflow-hidden rounded-2xl bg-black text-white no-underline shadow-[0_2px_10px_rgba(0,0,0,.08)]">
                {img && (
                  // eslint-disable-next-line @next/next/no-img-element -- static export
                  <img src={img} alt="" loading="lazy" className="absolute inset-0 h-full w-full object-cover opacity-75 transition duration-500 group-hover:scale-105 group-hover:opacity-60" />
                )}
                <span className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/20 to-transparent" aria-hidden="true" />
                <span className="absolute inset-x-0 bottom-0 flex flex-col p-3 sm:p-4">
                  <span className="text-[15px] font-semibold leading-tight sm:text-base">{c.name}</span>
                  <span className="text-xs text-gold">{count(c.id)} items →</span>
                </span>
              </Link>
            );
          })}
        </div>
      </section>

      <section className="border-y border-line bg-paper-2">
        <div className="wrap py-6">
          <h2 className="sr-only">{t("brands")}</h2>
          <ul className="no-scrollbar m-0 flex list-none gap-3 overflow-x-auto p-0">
            {usedBrands.map((b) => (
              <li key={b.id} className="shrink-0 rounded-full border border-[#e7dcc9] bg-white px-5 py-2.5 text-sm font-semibold tracking-wide text-[#333] shadow-[0_1px_4px_rgba(0,0,0,.04)]">{b.name}</li>
            ))}
          </ul>
        </div>
      </section>

      {best.length > 0 && (
        <section className="wrap py-12 sm:py-16">
          <SectionHead title={t("bestSellers")} href="/category/steel-rebar" linkLabel={t("viewAll")} />
          <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3 lg:grid-cols-4">
            {best.map((p) => <ProductCard key={p.id} product={p} />)}
          </div>
        </section>
      )}

      <section className="wrap">
        <div className="relative grid gap-6 overflow-hidden rounded-3xl bg-black px-6 py-10 text-white sm:grid-cols-[1fr_auto] sm:items-center sm:px-12 sm:py-14">
          <span className="pointer-events-none absolute -end-20 -top-20 h-64 w-64 rounded-full bg-gold/25 blur-3xl" aria-hidden="true" />
          <div>
            <h2 className="m-0 text-[clamp(26px,3.6vw,40px)] font-semibold tracking-[-0.02em]">{t("rfqTitle")}</h2>
            <p className="mb-0 mt-3 max-w-[52ch] text-on-dark-muted">{t("rfqText")}</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/quote" className="btn btn-ink">{t("rfqCta")}</Link>
            <Link href="/prices" className="btn btn-ghost">{t("pricesCta")}</Link>
          </div>
        </div>
      </section>

      {featured.length > 0 && (
        <section className="wrap py-12 sm:py-16">
          <SectionHead title={t("featured")} />
          <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3 lg:grid-cols-4">
            {featured.map((p) => <ProductCard key={p.id} product={p} />)}
          </div>
        </section>
      )}
    </>
  );
}
