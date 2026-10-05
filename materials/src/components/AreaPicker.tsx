"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useStore } from "./StoreProvider";

/** Bar under the header + Governorate → City/Area dialog. Always shows a readable area name. */
export function AreaBar() {
  const t = useTranslations("store");
  const { area, openPicker } = useStore();
  return (
    <div className="border-b border-line bg-paper-2">
      <div className="wrap flex h-11 items-center gap-2 text-sm">
        <svg viewBox="0 0 24 24" className="h-4 w-4 shrink-0" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
          <path d="M12 21s-7-6.1-7-11.5a7 7 0 0 1 14 0C19 14.9 12 21 12 21z" /><circle cx="12" cy="9.5" r="2.5" />
        </svg>
        <span className="text-muted">{t("deliverTo")}</span>
        <button type="button" onClick={() => openPicker(true)} className="flex min-w-0 items-center gap-1 font-semibold underline-offset-4 hover:underline">
          <span className="truncate">{area.name}, {area.governorate}</span>
          <span aria-hidden="true">▾</span>
        </button>
      </div>
    </div>
  );
}

export function AreaDialog() {
  const t = useTranslations("store");
  const { areas, area, areaChosen, setArea, pickerOpen, openPicker } = useStore();
  const governorates = useMemo(() => [...new Set(areas.map((a) => a.governorate))], [areas]);
  const [gov, setGov] = useState(area.governorate);
  const [slug, setSlug] = useState(area.slug);

  // first visit: ask once for the delivery area
  useEffect(() => {
    if (areaChosen) return;
    const id = setTimeout(() => { if (!document.cookie.includes("mat_area=")) openPicker(true); }, 1200);
    return () => clearTimeout(id);
  }, [areaChosen, openPicker]);

  useEffect(() => {
    if (!pickerOpen) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset the form to the current area each time the dialog opens
    setGov(area.governorate); setSlug(area.slug);
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && openPicker(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [pickerOpen, area, openPicker]);

  if (!pickerOpen) return null;
  const inGov = areas.filter((a) => a.governorate === gov);
  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center bg-black/50 sm:items-center" onClick={() => openPicker(false)}>
      <div role="dialog" aria-modal="true" aria-labelledby="area-title" onClick={(e) => e.stopPropagation()}
        className="w-full max-w-md bg-white p-6 pb-[calc(24px+env(safe-area-inset-bottom))]">
        <div className="mb-1 flex items-start justify-between gap-4">
          <h2 id="area-title" className="m-0 text-xl font-medium">{t("chooseArea")}</h2>
          <button type="button" onClick={() => openPicker(false)} aria-label={t("close")} className="-mt-1 text-2xl leading-none">×</button>
        </div>
        <p className="mb-5 mt-0 text-sm text-muted">{t("chooseAreaHint")}</p>
        <div className="grid gap-4">
          <div className="field">
            <label htmlFor="gov">{t("governorate")}</label>
            <select id="gov" value={gov} onChange={(e) => { setGov(e.target.value); setSlug(areas.find((a) => a.governorate === e.target.value)!.slug); }}>
              {governorates.map((g) => <option key={g}>{g}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="area">{t("area")}</label>
            <select id="area" value={slug} onChange={(e) => setSlug(e.target.value)}>
              {inGov.map((a) => <option key={a.slug} value={a.slug}>{a.name}</option>)}
            </select>
          </div>
          <button type="button" className="btn btn-ink w-full" onClick={() => setArea(slug)}>{t("confirm")}</button>
        </div>
      </div>
    </div>
  );
}
