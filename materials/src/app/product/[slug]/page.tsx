import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ProductView } from "@/components/ProductView";
import { SITE_URL } from "@/lib/config";
import { getProduct, getProducts, getReviews } from "@/lib/data";

type Props = { params: Promise<{ slug: string }> };

export async function generateStaticParams() {
  return (await getProducts()).map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const p = await getProduct(slug);
  if (!p) return {};
  const desc = `${p.name}${p.brand ? ` by ${p.brand.name}` : ""}. ${p.description ?? ""} Order online with delivery in Cairo & Giza.`.trim();
  return {
    title: p.name, description: desc, alternates: { canonical: `/materials/product/${p.slug}/` },
    openGraph: { title: p.name, description: desc, images: p.images.length ? p.images : ["/materials/jaguar-logo.png"], type: "website" },
  };
}

export default async function ProductPage({ params }: Props) {
  const { slug } = await params;
  const [product, all] = await Promise.all([getProduct(slug), getProducts()]);
  if (!product) notFound();
  const reviews = await getReviews(product.id);
  const related = all.filter((p) => p.category.id === product.category.id && p.id !== product.id).slice(0, 4);
  const avg = reviews.length ? reviews.reduce((s, r) => s + r.rating, 0) / reviews.length : null;
  const jsonLd = {
    "@context": "https://schema.org", "@type": "Product", name: product.name, sku: product.sku ?? undefined,
    image: product.images.map((i) => SITE_URL + i), description: product.description ?? undefined,
    brand: product.brand ? { "@type": "Brand", name: product.brand.name } : undefined,
    offers: { "@type": "Offer", priceCurrency: "EGP", price: product.base_price, availability: "https://schema.org/InStock",
      url: `${SITE_URL}/materials/product/${product.slug}/`, seller: { "@type": "Organization", name: "Jaguar Smart Construction" } },
    aggregateRating: avg ? { "@type": "AggregateRating", ratingValue: avg.toFixed(1), reviewCount: reviews.length } : undefined,
  };
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }} />
      <ProductView product={product} related={related} reviews={reviews} />
    </>
  );
}
