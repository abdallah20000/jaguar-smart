"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { normalizeEgPhone } from "@/lib/phone";
import { supabase } from "@/lib/supabase";
import { saveToken } from "@/lib/tokens";
import { track } from "@/lib/track";
import { openWhatsApp } from "@/lib/whatsapp";
import { useStore } from "./StoreProvider";

const MAX_FILES = 5, MAX_BYTES = 15 * 1024 * 1024;
const TYPES = ["villa", "apartment", "commercial", "finishing", "contractor", "other"] as const;
const safeName = (n: string) => n.normalize("NFKD").replace(/[^\w.-]+/g, "_").slice(-80) || "file";

export function QuoteForm() {
  const t = useTranslations("quote");
  const params = useSearchParams();
  const { areas, area } = useStore();
  const pre = params.get("product") ? `${params.get("qty") ?? ""} × ${params.get("product")}`.trim() : "";
  const [form, setForm] = useState({ name: "", phone: "", area: "", type: "villa", neededBy: "", materials: pre, notes: "" });
  const [files, setFiles] = useState<File[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<{ number: string; token: string; phone: string } | null>(null);
  const fileRef = useRef<HTMLInputElement>(null), photoRef = useRef<HTMLInputElement>(null);
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => setForm({ ...form, [k]: e.target.value });
  const areaSlug = form.area || area.slug;

  const addFiles = (list: FileList | null) => {
    const next = [...files, ...Array.from(list ?? [])];
    if (next.length > MAX_FILES || next.some((f) => f.size > MAX_BYTES)) { setErrors({ ...errors, files: t("errFiles") }); return; }
    setErrors({ ...errors, files: "" }); setFiles(next);
  };

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const phone = normalizeEgPhone(form.phone);
    const errs: Record<string, string> = {};
    if (!form.name.trim()) errs.name = t("errName");
    if (!phone) errs.phone = t("errPhone");
    if (!form.materials.trim() && !files.length) errs.materials = t("errEmpty");
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setBusy(true);
    try {
      const folder = `incoming/${crypto.randomUUID()}`;
      const uploaded = [];
      for (const f of files) {
        const path = `${folder}/${safeName(f.name)}`;
        const { error } = await supabase.storage.from("mat-quote-files").upload(path, f, { contentType: f.type || undefined });
        if (error) throw error;
        uploaded.push({ path, file_name: f.name, mime: f.type, size: f.size, kind: f.type.startsWith("image/") ? "photo" : "boq" });
      }
      const { data, error } = await supabase.rpc("mat_create_quote", { p: {
        name: form.name, phone, area_id: areas.find((a) => a.slug === areaSlug)?.id, project_type: t(`types.${form.type}`),
        needed_by: form.neededBy || null, materials_text: form.materials, notes: form.notes, files: uploaded } });
      if (error) throw error;
      const r = data as { quote_number: string; token: string };
      saveToken({ kind: "quote", token: r.token, number: r.quote_number, at: new Date().toISOString() });
      track("generate_lead", { currency: "EGP", lead_type: "rfq", files: uploaded.length });
      setDone({ number: r.quote_number, token: r.token, phone: phone! });
      window.scrollTo({ top: 0 });
    } catch (err) {
      console.error(err);
      setErrors({ submit: t("errGeneric") });
    } finally { setBusy(false); }
  }

  if (done) {
    const link = `/quote/status/?t=${done.token}`;
    return (
      <div className="wrap max-w-xl py-14">
        <p className="m-0 text-4xl">✓</p>
        <h1 className="mb-3 mt-2 text-3xl font-semibold">{t("doneTitle", { number: done.number })}</h1>
        <p className="text-muted">{t("doneText", { phone: done.phone })}</p>
        <div className="mt-6 grid gap-3 sm:grid-cols-2">
          <Link href={link} className="btn btn-ink">{t("openLink")}</Link>
          <button type="button" className="btn btn-line" onClick={() => openWhatsApp(t("waAdminText", { number: done.number }), "rfq_done")}>{t("waAdmin")}</button>
        </div>
        <p className="mt-6 break-all border border-line bg-paper-2 p-3 text-xs text-muted">{typeof window !== "undefined" ? window.location.origin : ""}/materials{link}</p>
      </div>
    );
  }

  const err = (k: string) => errors[k] ? <p className="mb-0 mt-1 text-sm text-down" role="alert">{errors[k]}</p> : null;
  return (
    <div className="wrap max-w-3xl py-10 sm:py-14">
      <h1 className="m-0 text-[clamp(28px,4vw,44px)] font-semibold tracking-[-0.03em]">{t("title")}</h1>
      <p className="mb-8 mt-3 max-w-[56ch] text-muted">{t("intro")}</p>
      <form onSubmit={submit} noValidate className="grid gap-5">
        <div className={`field ${errors.materials ? "invalid" : ""}`}>
          <label htmlFor="materials">{t("materials")}</label>
          <textarea id="materials" rows={5} placeholder={t("materialsPh")} value={form.materials} onChange={set("materials")} />
          {err("materials")}
        </div>
        <div>
          <div className="flex flex-wrap gap-3">
            <button type="button" className="btn btn-line px-4 py-3 text-sm" onClick={() => fileRef.current?.click()}>＋ {t("howFile")}</button>
            <button type="button" className="btn btn-line px-4 py-3 text-sm" onClick={() => photoRef.current?.click()}>＋ {t("howPhoto")}</button>
          </div>
          <input ref={fileRef} type="file" hidden multiple accept=".pdf,.xls,.xlsx,.csv" onChange={(e) => { addFiles(e.target.files); e.target.value = ""; }} />
          <input ref={photoRef} type="file" hidden multiple accept="image/*" capture="environment" onChange={(e) => { addFiles(e.target.files); e.target.value = ""; }} />
          <p className="mb-0 mt-2 text-xs text-muted">{t("fileHint")}</p>
          {files.length > 0 && (
            <ul className="m-0 mt-3 list-none p-0">
              {files.map((f, i) => (
                <li key={i} className="flex items-center justify-between gap-3 border-t border-line py-2 text-sm">
                  <span className="truncate">{f.name}</span>
                  <button type="button" aria-label="Remove" className="text-lg" onClick={() => setFiles(files.filter((_, j) => j !== i))}>×</button>
                </li>
              ))}
            </ul>
          )}
          {err("files")}
        </div>
        <div className="grid gap-5 sm:grid-cols-2">
          <div className={`field ${errors.name ? "invalid" : ""}`}>
            <label htmlFor="name">{t("name")}</label>
            <input id="name" autoComplete="name" value={form.name} onChange={set("name")} />{err("name")}
          </div>
          <div className={`field ${errors.phone ? "invalid" : ""}`}>
            <label htmlFor="phone">{t("phone")}</label>
            <input id="phone" type="tel" inputMode="tel" autoComplete="tel" dir="ltr" placeholder="010 1234 5678" value={form.phone} onChange={set("phone")} />
            {err("phone") ?? <p className="mb-0 mt-1 text-xs text-muted">{t("phoneHint")}</p>}
          </div>
          <div className="field">
            <label htmlFor="qarea">{t("area")}</label>
            <select id="qarea" value={areaSlug} onChange={set("area")}>
              {areas.map((a) => <option key={a.slug} value={a.slug}>{a.name}, {a.governorate}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="type">{t("projectType")}</label>
            <select id="type" value={form.type} onChange={set("type")}>
              {TYPES.map((k) => <option key={k} value={k}>{t(`types.${k}`)}</option>)}
            </select>
          </div>
          <div className="field">
            <label htmlFor="needed">{t("neededBy")}</label>
            <input id="needed" type="date" min={new Date().toISOString().slice(0, 10)} value={form.neededBy} onChange={set("neededBy")} />
          </div>
          <div className="field sm:col-span-2">
            <label htmlFor="notes">{t("notes")}</label>
            <textarea id="notes" rows={2} value={form.notes} onChange={set("notes")} />
          </div>
        </div>
        {err("submit")}
        <button type="submit" className="btn btn-ink w-full sm:w-auto sm:justify-self-start" disabled={busy}>{busy ? t("sending") : t("submit")}</button>
      </form>
    </div>
  );
}
