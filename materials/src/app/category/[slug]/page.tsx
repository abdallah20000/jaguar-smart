import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { CategoryView } from "@/components/CategoryView";
import { getCategories, getProducts, nonEmptyCategories } from "@/lib/data";

type Props = { params: Promise<{ slug: string }> };

export async function generateStaticParams() {
  const [categories, products] = await Promise.all([getCategories(), getProducts()]);
  return nonEmptyCategories(categories, products).map((c) => ({ slug: c.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const c = (await getCategories()).find((x) => x.slug === slug);
  return c ? { title: `${c.name} prices & delivery in Cairo and Giza`, description: `Buy ${c.name.toLowerCase()} online from Jaguar Smart Construction. Prices by area, stock and delivery to your site.`,
    alternates: { canonical: `/materials/category/${slug}/` } } : {};
}

export default async function CategoryPage({ params }: Props) {
  const { slug } = await params;
  const [categories, products] = await Promise.all([getCategories(), getProducts()]);
  const category = categories.find((c) => c.slug === slug);
  if (!category) notFound();
  const list = products.filter((p) => p.category.id === category.id);
  if (!list.length) notFound();
  return <CategoryView category={category} products={list} others={nonEmptyCategories(categories, products)} />;
}
