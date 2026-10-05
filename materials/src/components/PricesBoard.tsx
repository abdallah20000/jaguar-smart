"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { getCurrentPrices, getPriceHistory } from "@/lib/data";
import { dateTime, num, pct } from "@/lib/format";
import type { CurrentPrice } from "@/lib/types";
import { Sparkline } from "./Sparkline";
import { useStore } from "./StoreProvider";

type Props = { initialArea: string; initialPrices: CurrentPrice[]; initialHistory: Record<string, number[]> };

export function PricesBoard({ initialArea, initialPrices, initialHistory }: Props) {
  const t = useTranslations("prices");
  const { areas, area: storeArea, areaChosen } = useStore();
  const [slug, setSlug] = useState(initialArea);
  const [data, setData] = useState({ prices: initialPrices, history: initialHistory, slug: initialArea });
  const area = areas.find((a) => a.slug === slug)!;

  // open on the visitor's saved area
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- follow the area picked in the store header
    if (areaChosen) setSlug(storeArea.slug);
  }, [areaChosen, storeArea.slug]);

  useEffect(() => {
    let alive = true;
    Promise.all([getCurrentPrices(area.id), getPriceHistory(area.id)])
      .then(([prices, history]) => alive && setData({ prices, history, slug: area.slug }))
      .catch(() => {});
    return () => { alive = false; };
  }, [area.id, area.slug]);

  const groups = useMemo(() => {
    const g: Record<string, CurrentPrice[]> = {};
    for (const r of data.prices) (g[`${r.kind}|${r.manufacturer}`] ??= []).push(r);
    return Object.entries(g);
  }, [data.prices]);
  const loading = data.slug !== slug;
  const sample = data.prices.some((r) => r.is_sample);
  const latest = data.prices.reduce((m, r) => (r.recorded_at > m ? r.recorded_at : m), "");

  return (
    <div className="wrap py-10 sm:py-14">
      <h1 className="m-0 text-[clamp(28px,4vw,44px)] font-light tracking-[-0.03em]">{t("title")}</h1>
      <p className="mb-6 mt-3 max-w-[60ch] text-muted">{t("intro", { area: area.name })}</p>
      {sample && <p className="mb-6 border-s-4 border-black bg-paper-2 px-4 py-3 text-sm">{t("sampleNotice")}</p>}

      <div role="tablist" aria-label="Area" className="no-scrollbar -mx-4 mb-8 flex gap-2 overflow-x-auto px-4 sm:mx-0 sm:px-0">
        {areas.map((a) => (
          <button key={a.slug} role="tab" aria-selected={a.slug === slug} onClick={() => setSlug(a.slug)}
            className={`shrink-0 border px-4 py-2 text-sm ${a.slug === slug ? "border-black bg-black text-white" : "border-line bg-white text-muted hover:border-black hover:text-black"}`}>
            {a.name.replace(/ \(.*\)/, "")}
          </button>
        ))}
      </div>

      <div className={`grid gap-8 lg:grid-cols-2 ${loading ? "opacity-50" : ""}`} aria-busy={loading}>
        {groups.map(([key, rows]) => {
          const [kind, maker] = key.split("|");
          return (
            <section key={key} className="min-w-0 border border-line">
              <header className="flex items-baseline justify-between gap-3 border-b border-line bg-paper-2 px-4 py-3">
                <h2 className="m-0 text-lg font-medium">{maker}</h2>
                <span className="text-xs text-muted">{kind === "steel" ? t("steel") : t("cement")}</span>
              </header>
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-sm">
                  <thead>
                    <tr className="text-start text-xs text-muted">
                      <th className="px-3 py-2 sm:px-4 text-start font-medium">{kind === "steel" ? t("size") : t("product")}</th>
                      <th className="px-3 py-2 sm:px-4 text-end font-medium">{t("pricePerTon")}</th>
                      <th className="px-3 py-2 sm:px-4 text-end font-medium">{t("change")}</th>
                      <th className="px-3 py-2 sm:px-4 text-end font-medium">{t("trend")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((r) => (
                      <tr key={r.item_id} className="border-t border-line">
                        <td className="px-3 py-2.5 sm:px-4">{kind === "steel" ? `${r.size_mm} mm` : r.label}</td>
                        <td className="px-3 py-2.5 sm:px-4 text-end font-semibold tabular-nums">{num(r.price)}</td>
                        <td className={`px-3 py-2.5 sm:px-4 text-end tabular-nums ${!r.change_pct ? "text-muted" : r.change_pct > 0 ? "up-ink" : "down-ink"}`}>
                          {r.change_pct ? (r.change_pct > 0 ? "▲ " : "▼ ") : ""}{pct(r.change_pct)}
                        </td>
                        <td className="px-3 py-2.5 sm:px-4"><div className="flex justify-end">
                          <Sparkline width={64} values={data.history[r.item_id] ?? []} label={`${maker} ${r.label}, last 30 days`} />
                        </div></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          );
        })}
      </div>
      {latest && <p className="mt-6 text-sm text-muted">{t("updated")}: {dateTime(latest)}</p>}
      <p className="mt-2"><Link href="/quote" className="font-medium underline underline-offset-4">{t("askPrice")}</Link></p>
    </div>
  );
}
