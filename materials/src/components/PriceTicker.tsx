"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { getCurrentPrices } from "@/lib/data";
import { num, pct } from "@/lib/format";
import type { CurrentPrice } from "@/lib/types";
import { useStore } from "./StoreProvider";

export function PriceTicker({ initial }: { initial: CurrentPrice[] }) {
  const t = useTranslations("store");
  const { area } = useStore();
  const [rows, setRows] = useState(initial.filter((r) => r.show_in_ticker));
  useEffect(() => {
    getCurrentPrices(area.id).then((d) => setRows(d.filter((r) => r.show_in_ticker))).catch(() => {});
  }, [area.id]);
  if (!rows.length) return null;
  const items = rows.map((r) => (
    <Link key={r.item_id} href="/prices" className="flex shrink-0 items-center gap-2 px-5 py-2.5 no-underline">
      <span className="text-white">{r.manufacturer}</span>
      <span className="text-on-dark-muted">{r.kind === "steel" ? `${r.size_mm} mm` : r.label.split(" ")[0]}</span>
      <span className="font-semibold tabular-nums text-white">{num(r.price)}</span>
      <span className={`tabular-nums ${r.change_pct == null || r.change_pct === 0 ? "text-on-dark-muted" : r.change_pct > 0 ? "up" : "down"}`}>
        {r.change_pct != null && r.change_pct !== 0 ? (r.change_pct > 0 ? "▲ " : "▼ ") : ""}{pct(r.change_pct)}
      </span>
    </Link>
  ));
  return (
    <div className="ticker" aria-label={t("ticker")}>
      <div className="flex">
        <span className="z-10 flex shrink-0 items-center gap-2 bg-gold px-4 font-bold text-black">
          <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-black" aria-hidden="true" />EGP{t("perTon")}
        </span>
        <div className="ticker-track" aria-hidden="false">{items}{items.map((el) => <span key={`d-${el.key}`} aria-hidden="true">{el}</span>)}</div>
      </div>
    </div>
  );
}
