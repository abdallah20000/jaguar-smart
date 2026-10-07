"use client";

import Link from "next/link";
import { egp, UNIT_LABEL } from "@/lib/format";
import type { Product } from "@/lib/types";
import { CategoryIcon } from "./CategoryIcon";
import { StockBadge } from "./StockBadge";
import { useStore } from "./StoreProvider";

export function ProductImage({ product, className = "" }: { product: Pick<Product, "images" | "name" | "category">; className?: string }) {
  if (product.images?.[0]) {
    // eslint-disable-next-line @next/next/no-img-element -- static export: images are served as uploaded
    return <img src={product.images[0]} alt={product.name} className={`h-full w-full object-cover ${className}`} loading="lazy" />;
  }
  return (
    <div className={`grid h-full w-full place-items-center bg-paper-2 text-[#9a9a9a] ${className}`}>
      <CategoryIcon name={product.category.icon} className="h-10 w-10" />
    </div>
  );
}

export function ProductCard({ product }: { product: Product }) {
  const { priceOf, stockOf, live } = useStore();
  const stock = stockOf(product.id);
  return (
    <Link href={`/product/${product.slug}`} className="group flex flex-col overflow-hidden rounded-2xl border border-[#eee6d8] bg-white no-underline shadow-[0_2px_10px_rgba(0,0,0,.05)] transition hover:-translate-y-0.5 hover:shadow-[0_10px_28px_rgba(0,0,0,.12)]">
      <div className="relative aspect-[4/3] overflow-hidden"><ProductImage product={product} className="transition duration-500 group-hover:scale-105" /></div>
      <div className="flex flex-1 flex-col gap-1 p-3 sm:p-4">
        {product.brand && <span className="text-[11px] font-semibold uppercase tracking-wider text-gold-dark">{product.brand.name}</span>}
        <h3 className="m-0 line-clamp-2 text-[15px] font-medium leading-snug">{product.name}</h3>
        <div className="mt-auto pt-2">
          <div className={`text-lg font-bold tabular-nums ${live ? "" : "opacity-60"}`}>
            {egp(priceOf(product))}<span className="text-xs font-normal text-muted"> / {UNIT_LABEL[product.unit]}</span>
          </div>
          <div className="mt-1 flex items-center justify-between gap-2">
            <StockBadge status={stock} />
            {product.is_sample && <span className="text-[10px] uppercase tracking-wider text-muted">Sample</span>}
          </div>
        </div>
      </div>
    </Link>
  );
}
