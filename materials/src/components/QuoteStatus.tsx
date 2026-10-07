"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { egp } from "@/lib/format";
import { supabase } from "@/lib/supabase";

type Q = { quote_number: string; status: string; created_at: string; area_name: string | null; project_type: string | null;
  needed_by: string | null; materials_text: string | null; notes: string | null; quoted_amount: number | null; quote_note: string | null; files: number };
const STEPS = ["new", "priced", "sent", "won"];

export function QuoteStatus() {
  const t = useTranslations("quote");
  const token = useSearchParams().get("t") ?? "";
  const [q, setQ] = useState<Q | null | undefined>(undefined);
  useEffect(() => {
    supabase.rpc("mat_get_quote", { p_token: token }).then(({ data }) => setQ((data as Q) ?? null));
  }, [token]);
  if (q === undefined) return <div className="wrap py-16 text-muted">…</div>;
  if (q === null) return <div className="wrap py-16">{t("notFound")}</div>;
  const at = STEPS.indexOf(q.status);
  return (
    <div className="wrap max-w-2xl py-10 sm:py-14">
      <h1 className="m-0 text-3xl font-semibold">{t("trackTitle", { number: q.quote_number })}</h1>
      <p className="text-sm text-muted">{new Date(q.created_at).toLocaleString("en-GB", { timeZone: "Africa/Cairo" })}</p>
      <ol className="my-8 grid list-none grid-cols-4 gap-2 p-0">
        {STEPS.map((s, i) => (
          <li key={s} className={`border-t-4 pt-2 text-xs sm:text-sm ${q.status === "lost" ? "border-line text-muted" : i <= at ? "border-black" : "border-line text-muted"}`}>
            {t(`status.${s}`)}
          </li>
        ))}
      </ol>
      {q.status === "lost" && <p className="text-muted">{t("status.lost")}</p>}
      {q.quoted_amount != null && <p className="text-2xl font-semibold">{egp(q.quoted_amount)}</p>}
      {q.quote_note && <p className="whitespace-pre-wrap">{q.quote_note}</p>}
      <dl className="mt-6 grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 border-t border-line pt-4 text-sm">
        {q.area_name && <><dt className="text-muted">{t("area")}</dt><dd className="m-0">{q.area_name}</dd></>}
        {q.project_type && <><dt className="text-muted">{t("projectType")}</dt><dd className="m-0">{q.project_type}</dd></>}
        {q.needed_by && <><dt className="text-muted">{t("neededBy")}</dt><dd className="m-0">{q.needed_by}</dd></>}
        {q.files > 0 && <><dt className="text-muted">Files</dt><dd className="m-0">{q.files}</dd></>}
      </dl>
      {q.materials_text && <pre className="mt-4 whitespace-pre-wrap border border-line bg-paper-2 p-4 font-sans text-sm">{q.materials_text}</pre>}
    </div>
  );
}
