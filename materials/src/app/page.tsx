import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { AreaBar } from "@/components/AreaPicker";
import { BannerSlider } from "@/components/BannerSlider";
import { CategoryIcon } from "@/components/CategoryIcon";
import { PriceTicker } from "@/components/PriceTicker";
import { ProductCard } from "@/components/ProductCard";
import { SectionHead } from "@/components/Section";
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

      <section className="wrap py-12 sm:py-16">
        <SectionHead title={t("categories")} />
        <div className="grid grid-cols-2 gap-px border border-line bg-line sm:grid-cols-3 lg:grid-cols-5">
          {cats.map((c) => (
            <Link key={c.id} href={`/category/${c.slug}`} className="flex flex-col gap-3 bg-white p-4 no-underline transition-colors hover:bg-black hover:text-white sm:p-5">
              <CategoryIcon name={c.icon} />
              <span className="font-medium leading-tight">{c.name}</span>
              <span className="text-xs opacity-60">{count(c.id)} items</span>
            </Link>
          ))}
        </div>
      </section>

      <section className="border-y border-line bg-paper-2">
        <div className="wrap py-6">
          <h2 className="sr-only">{t("brands")}</h2>
          <ul className="no-scrollbar m-0 flex list-none gap-3 overflow-x-auto p-0">
            {usedBrands.map((b) => (
              <li key={b.id} className="shrink-0 border border-line bg-white px-5 py-3 text-sm font-semibold tracking-wide text-[#333]">{b.name}</li>
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

      <section className="bg-black text-white">
        <div className="wrap grid gap-6 py-12 sm:grid-cols-[1fr_auto] sm:items-center sm:py-16">
          <div>
            <h2 className="m-0 text-[clamp(26px,3.6vw,40px)] font-light tracking-[-0.02em]">{t("rfqTitle")}</h2>
            <p className="mb-0 mt-3 max-w-[52ch] text-on-dark-muted">{t("rfqText")}</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link href="/quote" className="btn btn-white">{t("rfqCta")}</Link>
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
