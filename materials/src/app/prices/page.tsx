import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { PricesBoard } from "@/components/PricesBoard";
import { DEFAULT_AREA } from "@/lib/config";
import { getAreas, getCurrentPrices, getPriceHistory } from "@/lib/data";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("prices");
  return { title: t("title"), description: "Daily rebar prices for Ezz, Beshay, Al Garhy, El Marakby and Suez Steel, plus grey and white cement, per area in Cairo and Giza.",
    alternates: { canonical: "/materials/prices/" } };
}

export default async function PricesPage() {
  const areas = await getAreas();
  const first = areas.find((a) => a.slug === DEFAULT_AREA)!;
  const [prices, history] = await Promise.all([getCurrentPrices(first.id), getPriceHistory(first.id)]);
  return <PricesBoard initialArea={first.slug} initialPrices={prices} initialHistory={history} />;
}
