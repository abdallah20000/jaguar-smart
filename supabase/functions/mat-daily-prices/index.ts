// Jaguar Smart Materials — daily steel & cement prices.
// Reads today's price articles found through Google News, extracts each mill's price,
// and keeps the HIGHEST price that is confirmed by the sources (see choose()).
// Triggered by pg_cron twice a day; safe to call again (it only ever raises today's price).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const UA = { "User-Agent": "Mozilla/5.0 (compatible; JaguarSmartPrices/1.0; +https://jaguarsmart.com/materials/prices/)" };
const MAX_ARTICLES = 24;

type Spec = { aliases: string[]; lo: number; hi: number };
const STEEL: Record<string, Spec> = {
  "Ezz Steel": { aliases: ["حديد عز", "عز الدخيلة", "عز"], lo: 30000, hi: 60000 },
  "Beshay Steel": { aliases: ["بشاي", "بشاى"], lo: 30000, hi: 60000 },
  "Al Garhy Steel": { aliases: ["الجارحي", "الجارحى"], lo: 30000, hi: 60000 },
  "El Marakby Steel": { aliases: ["المراكبي", "المراكبى"], lo: 30000, hi: 60000 },
  "Suez Steel": { aliases: ["السويس للصلب", "حديد السويس"], lo: 30000, hi: 60000 },
};
const CEMENT: Record<string, Spec> = {
  "Suez Cement": { aliases: ["أسمنت السويس", "اسمنت السويس"], lo: 2500, hi: 7000 },
  "Arabian Cement": { aliases: ["العربية للأسمنت", "أسمنت العربية", "اسمنت العربية"], lo: 2500, hi: 7000 },
  "Sinai White Cement": { aliases: ["سيناء الأبيض", "سيناء الابيض", "سيناء أبيض"], lo: 4000, hi: 12000 },
};

const AR_DIGITS: Record<string, string> = { "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9" };
const toLatin = (s: string) => s.replace(/[٠-٩]/g, (d) => AR_DIGITS[d]);

// "40 ألفًا و850 جنيهًا", "40,850", "40850", "3900", "3,900"
const NUM = /(\d{1,2})\s*ألف[اًا]?\s*(?:و\s*(\d{1,3})\s*)?(?:جنيه|ج)|(\d{1,2}[,.٬]\d{3})(?!\d)|(?<![\d,.])(\d{4,5})(?![\d,.])/g;

function firstPrice(seg: string, lo: number, hi: number): number | null {
  for (const m of seg.matchAll(NUM)) {
    const v = m[1] ? Number(m[1]) * 1000 + Number(m[2] ?? 0) : Number((m[3] ?? m[4]).replace(/\D/g, ""));
    if (v >= lo && v <= hi) return v;
  }
  return null;
}

export function extract(text: string, specs: Record<string, Spec>) {
  const out: Record<string, number> = {};
  for (const [name, s] of Object.entries(specs)) {
    for (const a of s.aliases) {
      const found: number[] = [];
      let i = text.indexOf(a);
      while (i !== -1 && found.length < 6) {
        const v = firstPrice(text.slice(i + a.length, i + a.length + 110), s.lo, s.hi);
        if (v) found.push(v);
        i = text.indexOf(a, i + a.length);
      }
      if (found.length) { out[name] = found[0]; break; } // first mention = the headline (lengths) price
    }
  }
  return out;
}

/** Highest price confirmed by 2+ sources (±0.5%) among values near the median; never a lone outlier. */
export function choose(values: number[]): number | null {
  if (values.length < 2) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const median = sorted[Math.floor(sorted.length / 2)];
  const near = values.filter((v) => Math.abs(v - median) / median <= 0.05);
  const confirmed = near.filter((v) => near.filter((w) => Math.abs(w - v) / v <= 0.005).length >= 2);
  const pool = confirmed.length ? confirmed : near;
  return pool.length ? Math.max(...pool) : null;
}

async function get(url: string, init: RequestInit = {}) {
  const r = await fetch(url, { ...init, headers: { ...UA, ...(init.headers ?? {}) }, signal: AbortSignal.timeout(15000) });
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.text();
}

// Google News article links are opaque; this resolves them to the publisher URL.
async function resolveGoogleNews(link: string) {
  const id = link.split("/articles/")[1].split("?")[0];
  const page = await get(`https://news.google.com/rss/articles/${id}`);
  const sg = page.match(/data-n-a-sg="([^"]+)"/)?.[1], ts = page.match(/data-n-a-ts="([^"]+)"/)?.[1];
  if (!sg || !ts) throw new Error("no signature");
  const inner = JSON.stringify(["garturlreq", [["X", "X", ["X", "X"], null, null, 1, 1, "US:en", null, 1, null, null, null, null, null, 0, 1],
    "X", "X", 1, [1, 1, 1], 1, 1, null, 0, 0, null, 0], id, Number(ts), sg]);
  const body = new URLSearchParams({ "f.req": JSON.stringify([[["Fbv4je", inner, null, "generic"]]]) });
  const res = await get("https://news.google.com/_/DotsSplashUi/data/batchexecute", {
    method: "POST", body, headers: { "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8" } });
  return JSON.parse(JSON.parse(res.split("\n\n")[1])[0][2])[1] as string;
}

const articleText = (html: string) => toLatin(html
  .replace(/<(script|style|noscript)[^>]*>[\s\S]*?<\/\1>/gi, " ")
  .replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&#\d+;/g, " ")
  .replace(/\s+/g, " "));

async function todaysArticles(query: string) {
  const rss = await get(`https://news.google.com/rss/search?q=${encodeURIComponent(query + " when:1d")}&hl=ar&gl=EG&ceid=EG:ar`);
  return [...rss.matchAll(/<item>([\s\S]*?)<\/item>/g)].map((m) => ({
    title: m[1].match(/<title>([\s\S]*?)<\/title>/)?.[1] ?? "",
    link: m[1].match(/<link>([\s\S]*?)<\/link>/)?.[1] ?? "",
  }));
}

Deno.serve(async () => {
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Cairo" }).format(new Date());
  const log = async (row: Record<string, unknown>) => { await db.from("mat_price_runs").insert({ run_date: today, ...row }); };

  // cooldown: anyone can call this URL, so never scrape more than once every 20 minutes
  const { data: last } = await db.from("mat_price_runs").select("ran_at").order("ran_at", { ascending: false }).limit(1).maybeSingle();
  if (last && Date.now() - new Date(last.ran_at).getTime() < 20 * 60 * 1000) {
    return Response.json({ status: "cooldown" });
  }

  try {
    const items = [...await todaysArticles("أسعار الحديد اليوم"), ...await todaysArticles("أسعار الأسمنت اليوم")];
    const seen = new Set<string>();
    const picked = items.filter((it) => /الحديد|الأسمنت|الاسمنت|مواد البناء/.test(it.title) && it.link && !seen.has(it.link) && seen.add(it.link)).slice(0, MAX_ARTICLES);

    const sources: { site: string; url: string; steel: Record<string, number>; cement: Record<string, number> }[] = [];
    for (let i = 0; i < picked.length; i += 4) {
      await Promise.all(picked.slice(i, i + 4).map(async (it) => {
        try {
          const url = await resolveGoogleNews(it.link);
          const text = articleText(await get(url));
          const steel = extract(text, STEEL), cement = extract(text, CEMENT);
          if (Object.keys(steel).length || Object.keys(cement).length) sources.push({ site: new URL(url).hostname, url, steel, cement });
        } catch { /* one bad article never stops the run */ }
      }));
    }

    // one value per site (some sites publish several articles a day: keep their highest)
    const bySite = (kind: "steel" | "cement", name: string) => {
      const per: Record<string, number> = {};
      for (const s of sources) { const v = s[kind][name]; if (v) per[s.site] = Math.max(per[s.site] ?? 0, v); }
      return Object.values(per);
    };
    const steel: Record<string, number> = {}, cement: Record<string, number> = {};
    for (const name of Object.keys(STEEL)) { const v = choose(bySite("steel", name)); if (v) steel[name] = v; }
    for (const name of Object.keys(CEMENT)) { const v = choose(bySite("cement", name)); if (v) cement[name] = v; }

    const siteCount = new Set(sources.map((s) => s.site)).size;
    if (siteCount < 3 || !Object.keys(steel).length) {
      await log({ status: "skipped", sources, prices: { steel, cement }, message: `only ${siteCount} usable sources` });
      return Response.json({ status: "skipped", siteCount });
    }
    const { data: rows, error } = await db.rpc("mat_apply_scraped_prices", { p: { date: today, steel, cement } });
    if (error) throw error;
    await log({ status: "applied", sources, prices: { steel, cement }, message: `${rows} prices saved from ${siteCount} sites` });
    return Response.json({ status: "applied", steel, cement, siteCount, rows });
  } catch (e) {
    await log({ status: "error", message: String(e).slice(0, 500) });
    return Response.json({ status: "error", message: String(e) }, { status: 500 });
  }
});
