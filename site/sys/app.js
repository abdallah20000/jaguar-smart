/* «نظام الشركات» Phase 1 (/sys).
   Two data backends behind one small API:
   - DEMO: in-browser fake data in localStorage. On automatically on any host that is not jaguarsmart.com
     (for example *.pages.dev previews), or with ?demo=1. Never talks to Supabase.
   - REAL: Supabase (jaguar-smart project), same email + password auth as /app. Needs migration 110 first. */
(() => {
"use strict";

const $ = (s, r = document) => r.querySelector(s);
const h = (tag, attrs, ...kids) => {
  const el = document.createElement(tag);
  if (attrs) for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === "style" && typeof v === "object") for (const [p, x] of Object.entries(v)) el.style.setProperty(p, x);
    else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v);
    else if (k === "class") el.className = v;
    else el.setAttribute(k, v === true ? "" : v);
  }
  for (const c of kids.flat()) if (c != null && c !== false) el.append(c.nodeType ? c : String(c));
  return el;
};

/* ---------- mode ---------- */
const qs = new URLSearchParams(location.search);
const REAL_HOSTS = ["jaguarsmart.com", "www.jaguarsmart.com"];
const DEMO = qs.get("demo") === "1" || !REAL_HOSTS.includes(location.hostname);

/* ---------- fixed lists ---------- */
const ROLES = {owner: "مالك/شريك", ops: "مدير تشغيل", cash: "كاش/حسابات", sales: "مبيعات", field: "ميدان/فني", stock: "مخزن/مشتريات"};
const CATS = [["goods", "بضاعة"], ["shipping", "شحن"], ["salaries", "مرتبات"], ["commissions", "عمولات"], ["rent", "إيجار"], ["ads", "إعلانات"], ["transport", "مواصلات"], ["partner_draw", "سحب شريك"]];
const CAT = Object.fromEntries(CATS);
const FIELD_AR = {direction: "النوع", amount: "المبلغ", category: "البند", person_id: "الشخص", client: "العميل", note: "ملاحظة", receipt_path: "صورة الإيصال", entry_date: "التاريخ", status: "الحالة"};
const CAN_APPROVE = (r) => r === "owner" || r === "cash";

const fmt = new Intl.NumberFormat("en-US", {maximumFractionDigits: 2});
const money = (n) => fmt.format(Math.round((+n || 0) * 100) / 100) + " ج";
const cairoDay = (d = new Date()) => new Intl.DateTimeFormat("en-CA", {timeZone: "Africa/Cairo"}).format(d);
const dayLabel = (s) => { const t = cairoDay(); if (s === t) return "النهارده"; const y = cairoDay(new Date(Date.now() - 864e5)); if (s === y) return "امبارح"; return new Intl.DateTimeFormat("ar-EG", {day: "numeric", month: "short"}).format(new Date(s + "T12:00:00")); };
const timeLabel = (iso) => new Intl.DateTimeFormat("ar-EG", {timeZone: "Africa/Cairo", day: "numeric", month: "short", hour: "numeric", minute: "2-digit"}).format(new Date(iso));
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : "id-" + Date.now().toString(36) + Math.random().toString(36).slice(2));

function toast(t){ const el = h("div", {class: "toast", role: "status"}, t); document.body.append(el); setTimeout(() => el.remove(), 2200); }

/* =====================================================================
   DEMO backend: localStorage, fake people, fake amounts, hashed passwords
   ===================================================================== */
const DEMO_KEY = "sys.demo.v1", DEMO_SESSION = "sys.demo.session";
const DEMO_PW = "demo1234";  // shared by all demo accounts; only its salted SHA-256 is ever stored
const DEMO_COMPANIES = [
  {company_id: "aix", name: "AIX", color: "#2EC4E6"},
  {company_id: "tuya-suez", name: "Tuya Suez", color: "#FF6B35"},
  {company_id: "jaguar", name: "Jaguar", color: "#E9B44C"}
];
// one demo account per role; some hold different roles in different companies
const DEMO_USERS = [
  {email: "owner@demo.test", name: "مالك تجريبي", roles: {aix: "owner", "tuya-suez": "owner", jaguar: "owner"}},
  {email: "ops@demo.test", name: "مدير تشغيل تجريبي", roles: {jaguar: "ops", aix: "sales"}},
  {email: "cash@demo.test", name: "محاسب تجريبي", roles: {"tuya-suez": "cash", aix: "cash"}},
  {email: "sales@demo.test", name: "مبيعات تجريبي", roles: {jaguar: "sales", "tuya-suez": "sales"}},
  {email: "field@demo.test", name: "فني تجريبي", roles: {"tuya-suez": "field"}},
  {email: "stock@demo.test", name: "مخزن تجريبي", roles: {aix: "stock", jaguar: "field"}}
];

async function sha256(text){
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
const pwHash = (salt, pw) => sha256(salt + ":" + pw);

let DB = null;
function dbSave(){ try { localStorage.setItem(DEMO_KEY, JSON.stringify(DB)); return true; } catch { toast("مساحة التخزين في المتصفح خلصت"); return false; } }
async function dbLoad(){
  try { DB = JSON.parse(localStorage.getItem(DEMO_KEY) || "null"); } catch { DB = null; }
  if (DB && DB.v === 1) return;
  DB = {v: 1, users: [], memberships: [], people: [], pay: [], cash: [], audit: []};
  for (const u of DEMO_USERS){
    const id = uid(), salt = uid();
    DB.users.push({id, email: u.email, name: u.name, salt, hash: await pwHash(salt, DEMO_PW)});
    for (const [c, r] of Object.entries(u.roles)) DB.memberships.push({user_id: id, company_id: c, role: r});
  }
  // fake people per company (names are roles + numbers, salaries invented)
  const ppl = {
    aix: [["owner", "شريك تجريبي (أ)", null, null, 40], ["ops", "مدير تشغيل تجريبي ١", 9000, null, null], ["cash", "محاسب تجريبي ١", 7000, null, null], ["sales", "مبيعات تجريبي ١", 4000, 3, null], ["stock", "أمين مخزن تجريبي ١", 5000, null, null]],
    "tuya-suez": [["owner", "شريك تجريبي (ب)", null, null, 50], ["owner", "شريك تجريبي (ج)", null, null, 50], ["cash", "محاسب تجريبي ٢", 6500, null, null], ["sales", "مبيعات تجريبي ٢", 3500, 5, null], ["field", "فني تجريبي ١", 5500, null, null], ["field", "فني تجريبي ٢", 5000, null, null]],
    jaguar: [["owner", "شريك تجريبي (أ)", null, null, 100], ["ops", "مدير تشغيل تجريبي ٢", 8500, null, null], ["sales", "مبيعات تجريبي ٣", 4000, 4, null], ["field", "فني تجريبي ٣", 5200, null, null]]
  };
  for (const [c, list] of Object.entries(ppl)) for (const [role, full_name, sal, pct, share] of list){
    const id = uid();
    DB.people.push({id, company_id: c, full_name, role, active: true, created_at: new Date().toISOString()});
    DB.pay.push({person_id: id, company_id: c, monthly_salary: sal, commission_pct: pct, partner_share_pct: share});
  }
  // fake cash: a few days of movement per company
  const seeds = {
    aix: [["in", 18500, "goods", "عميل تجريبي ١"], ["out", 6200, "goods", null], ["out", 950, "shipping", null], ["out", 1200, "ads", null], ["in", 7400, "goods", "عميل تجريبي ٢"], ["out", 300, "transport", null], ["out", 9000, "salaries", null], ["in", 12000, "goods", "عميل تجريبي ٣"], ["out", 450, "transport", null], ["out", 2500, "partner_draw", null]],
    "tuya-suez": [["in", 22000, "goods", "عميل تجريبي ٤"], ["out", 8000, "rent", null], ["out", 650, "transport", null], ["in", 5300, "goods", "عميل تجريبي ٥"], ["out", 1750, "commissions", null], ["out", 400, "shipping", null], ["out", 220, "transport", null], ["in", 9800, "goods", "عميل تجريبي ٦"]],
    jaguar: [["in", 15000, "goods", "عميل تجريبي ٧"], ["out", 2000, "ads", null], ["out", 3800, "goods", null], ["out", 180, "transport", null], ["in", 4200, "goods", "عميل تجريبي ٨"], ["out", 1500, "partner_draw", null]]
  };
  const now = Date.now();
  for (const [c, list] of Object.entries(seeds)){
    const members = DB.memberships.filter((m) => m.company_id === c);
    const people = DB.people.filter((p) => p.company_id === c);
    list.forEach(([direction, amount, category, client], i) => {
      const back = list.length - 1 - i;                       // oldest first
      const at = new Date(now - back * 0.9 * 864e5 - (i % 3) * 36e5);
      const pending = back <= 2 && i % 2 === 0;               // a few recent ones wait for approval
      const by = members[i % members.length];
      const person = category === "salaries" || category === "commissions" || category === "transport" ? people[(i % (people.length - 1)) + 1] : null;
      DB.cash.push({id: uid(), company_id: c, direction, amount, category, person_id: person ? person.id : null, client,
        note: null, receipt_path: null, entry_date: cairoDay(at), status: pending ? "pending" : "approved",
        created_by: by.user_id, created_at: at.toISOString(), approved_by: pending ? null : by.user_id, approved_at: pending ? null : at.toISOString()});
    });
  }
  dbSave();
}
const demoMe = () => { try { const id = localStorage.getItem(DEMO_SESSION); return DB.users.find((u) => u.id === id) || null; } catch { return null; } };
const demoRole = (c) => { const me = demoMe(); const m = me && DB.memberships.find((x) => x.user_id === me.id && x.company_id === c); return m ? m.role : null; };
const deny = () => { const e = new Error("not allowed"); e.code = "42501"; throw e; };
const AUDITED = ["direction", "amount", "category", "person_id", "client", "note", "receipt_path", "entry_date", "status"];

const demoApi = {
  async session(){ await dbLoad(); const u = demoMe(); return u ? {id: u.id, email: u.email, name: u.name} : null; },
  async signIn(email, pw){
    await dbLoad();
    const u = DB.users.find((x) => x.email.toLowerCase() === String(email).trim().toLowerCase());
    if (!u || (await pwHash(u.salt, pw)) !== u.hash) throw new Error("الإيميل أو الباسورد غلط");
    localStorage.setItem(DEMO_SESSION, u.id);
    return {id: u.id, email: u.email, name: u.name};
  },
  async signOut(){ try { localStorage.removeItem(DEMO_SESSION); } catch {} },
  async myCompanies(){
    const me = demoMe(); if (!me) return [];
    return DEMO_COMPANIES.map((c) => ({...c, role: demoRole(c.company_id)})).filter((c) => c.role);
  },
  async cash(c){ if (!demoRole(c)) deny(); return DB.cash.filter((e) => e.company_id === c).map((e) => ({...e})); },
  async people(c){ if (!demoRole(c)) deny(); return DB.people.filter((p) => p.company_id === c).map((p) => ({...p})); },
  // mirrors the people_pay RLS: owner of that company only, everyone else gets nothing
  async pay(c){ if (demoRole(c) !== "owner") return []; return DB.pay.filter((p) => p.company_id === c).map((p) => ({...p})); },
  async addCash(c, entry, photo){
    if (!demoRole(c)) deny();
    const me = demoMe();
    const row = {id: uid(), company_id: c, direction: entry.direction, amount: +entry.amount, category: entry.category,
      person_id: entry.person_id || null, client: entry.client || null, note: entry.note || null,
      receipt_path: photo || null, entry_date: cairoDay(), status: "pending",
      created_by: me.id, created_at: new Date().toISOString(), approved_by: null, approved_at: null};
    if (!CAT[row.category] || !(row.amount > 0) || !["in", "out"].includes(row.direction)) throw new Error("بيانات ناقصة");
    DB.cash.push(row);
    if (!dbSave()){ DB.cash.pop(); throw new Error("مقدرناش نحفظ (الصورة كبيرة؟)"); }
    return row;
  },
  async updateCash(id, changes){
    const row = DB.cash.find((e) => e.id === id); if (!row) throw new Error("مش موجود");
    if (!CAN_APPROVE(demoRole(row.company_id))) deny();
    const me = demoMe(), old = {...row}, next = {...row, ...changes};
    if (changes.category && !CAT[changes.category]) throw new Error("بند غلط");
    if ("amount" in changes && !(+changes.amount > 0)) throw new Error("المبلغ لازم يكون أكبر من صفر");
    if (next.status !== old.status && next.status === "approved"){ next.approved_by = me.id; next.approved_at = new Date().toISOString(); }
    const fields = AUDITED.filter((f) => String(old[f] ?? "") !== String(next[f] ?? ""));
    if (!fields.length) return row;
    Object.assign(row, next);
    const slim = (r) => ({...r, receipt_path: r.receipt_path ? "[صورة]" : null});  // keep the photo once, not in every audit row
    DB.audit.push({id: DB.audit.length + 1, entry_id: id, company_id: row.company_id, changed_by: me.id, changed_at: new Date().toISOString(), fields, old_row: slim(old), new_row: slim(row)});
    if (!dbSave()) throw new Error("مقدرناش نحفظ");
    return row;
  },
  async audit(id){
    const row = DB.cash.find((e) => e.id === id); if (!row) return [];
    if (!["owner", "ops", "cash"].includes(demoRole(row.company_id))) return [];
    return DB.audit.filter((a) => a.entry_id === id).sort((a, b) => b.changed_at.localeCompare(a.changed_at));
  },
  async receiptUrl(path){ return path || null; },  // demo keeps a small data: URL
  userName(id){ const u = DB.users.find((x) => x.id === id); return u ? u.name : "عضو"; },
  reset(){ try { localStorage.removeItem(DEMO_KEY); localStorage.removeItem(DEMO_SESSION); } catch {} }
};

/* =====================================================================
   REAL backend: Supabase (needs supabase/migrations/110_companies_core.sql)
   ===================================================================== */
const SB_URL = "https://snrsfpprlynixotjipmo.supabase.co";
const SB_KEY = "sb_publishable_Q9zcnd6bo1cM4VDRysyjbA_XBr6lhds";
let sb = null;
const need = (r) => { if (r.error) throw r.error; return r.data; };
const nameOfUser = (u) => { const m = (u && u.user_metadata) || {}; return String(m.full_name || m.name || "").trim() || String(u.email || "").split("@")[0]; };
const realNames = new Map();

const realApi = {
  async session(){
    if (!sb) return null;
    const r = await sb.auth.getSession(); const u = r.data && r.data.session && r.data.session.user;
    return u ? {id: u.id, email: u.email, name: nameOfUser(u)} : null;
  },
  async signIn(email, pw){
    const r = await sb.auth.signInWithPassword({email: String(email).trim(), password: pw});
    if (r.error) throw new Error(/invalid/i.test(r.error.message) ? "الإيميل أو الباسورد غلط" : "مقدرناش ندخلك دلوقتي");
    return {id: r.data.user.id, email: r.data.user.email, name: nameOfUser(r.data.user)};
  },
  async signOut(){ try { await sb.auth.signOut(); } catch {} },
  async myCompanies(){ return need(await sb.rpc("sys_my_companies")) || []; },
  async cash(c){ return need(await sb.from("cash_entries").select("*").eq("company_id", c).order("created_at", {ascending: false}).limit(1000)) || []; },
  async people(c){
    const rows = need(await sb.from("people").select("*").eq("company_id", c).order("full_name")) || [];
    rows.forEach((p) => { if (p.user_id) realNames.set(p.user_id, p.full_name); });
    return rows;
  },
  // RLS on people_pay returns rows to the company's owner only
  async pay(c){ const r = await sb.from("people_pay").select("*").eq("company_id", c); return r.error ? [] : r.data || []; },
  async addCash(c, entry, photoBlob){
    let receipt_path = null;
    if (photoBlob){
      receipt_path = c + "/" + uid() + ".jpg";
      need(await sb.storage.from("sys-receipts").upload(receipt_path, photoBlob, {contentType: "image/jpeg", upsert: false}));
    }
    return need(await sb.from("cash_entries").insert({company_id: c, direction: entry.direction, amount: +entry.amount, category: entry.category,
      person_id: entry.person_id || null, client: entry.client || null, note: entry.note || null, receipt_path}).select().single());
  },
  async updateCash(id, changes){ return need(await sb.from("cash_entries").update(changes).eq("id", id).select().single()); },
  async audit(id){ const r = await sb.from("cash_audit").select("*").eq("entry_id", id).order("changed_at", {ascending: false}); return r.error ? [] : r.data || []; },
  async receiptUrl(path){ if (!path) return null; const r = await sb.storage.from("sys-receipts").createSignedUrl(path, 600); return r.error ? null : r.data.signedUrl; },
  userName(id){ return realNames.get(id) || (S.user && id === S.user.id ? S.user.name : "عضو"); }
};

const API = DEMO ? demoApi : realApi;
if (!DEMO){ try { sb = window.supabase.createClient(SB_URL, SB_KEY, {auth: {persistSession: true, autoRefreshToken: true}}); } catch {} }

/* =====================================================================
   UI
   ===================================================================== */
const S = {user: null, companies: [], co: null, tab: "home", cash: [], people: [], pay: [], filter: "all"};
const role = () => (S.companies.find((c) => c.company_id === S.co) || {}).role || null;
const coInfo = () => S.companies.find((c) => c.company_id === S.co) || {};
const personName = (id) => { const p = S.people.find((x) => x.id === id); return p ? p.full_name : ""; };

function showGate(id){ ["g-install", "g-login", "g-none"].forEach((g) => { $("#" + g).hidden = g !== id; }); $("#app").hidden = !!id; $("#fab").hidden = !!id; }

async function enter(user){
  S.user = user;
  try { S.companies = await API.myCompanies(); }
  catch { $("#l-err").textContent = DEMO ? "حصلت مشكلة" : "السيستم لسه مش متجهز (migration 110 ما اتشغلش) أو مفيش اتصال."; showGate("g-login"); return; }
  if (!S.companies.length){ showGate("g-none"); return; }
  let last = null; try { last = localStorage.getItem("sys.co." + user.id); } catch {}
  S.co = S.companies.some((c) => c.company_id === last) ? last : S.companies[0].company_id;
  showGate(null);
  $("#me-name").textContent = "أهلاً، " + user.name + (DEMO ? " " : "");
  if (DEMO) $("#me-name").append(h("span", {class: "tag demo"}, "تجريبي"));
  await loadCompany();
  if (qs.get("add") === "1") openAdd();
}

async function loadCompany(){
  const c = coInfo();
  document.documentElement.style.setProperty("--co", c.color || "#F59A4A");
  $("meta[name=theme-color]").setAttribute("content", "#17130F");
  try { localStorage.setItem("sys.co." + S.user.id, S.co); } catch {}
  $("#me-role").textContent = (ROLES[c.role] || "") + " في " + (c.name || "");
  renderCos();
  $("#view").replaceChildren(h("div", {class: "empty"}, "بيحمّل…"));
  try {
    const [cash, people, pay] = await Promise.all([API.cash(S.co), API.people(S.co), API.pay(S.co)]);
    S.cash = cash; S.people = people; S.pay = pay;
  } catch { S.cash = []; S.people = []; S.pay = []; toast("مقدرناش نجيب الداتا"); }
  render();
}

function renderCos(){
  $("#cos").replaceChildren(...S.companies.map((c) => h("button", {class: "co", type: "button", style: {"--c": c.color}, "aria-pressed": String(c.company_id === S.co),
    onclick: () => { if (c.company_id !== S.co){ S.co = c.company_id; S.filter = "all"; loadCompany(); } }},
    h("i"), c.name, h("small", null, ROLES[c.role]))));
}

function setTab(t){ S.tab = t; document.querySelectorAll("#tabs button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.tab === t))); render(); }
$("#tabs").addEventListener("click", (e) => { const b = e.target.closest("button[data-tab]"); if (b) setTab(b.dataset.tab); });

// running balance: oldest to newest, every entry counts (pending ones are marked)
function withRunning(){
  const asc = [...S.cash].sort((a, b) => (a.entry_date + a.created_at).localeCompare(b.entry_date + b.created_at));
  let run = 0, ok = 0;
  for (const e of asc){ const d = e.direction === "in" ? +e.amount : -e.amount; run += d; if (e.status === "approved") ok += d; e._run = run; }
  return {rows: asc.reverse(), balance: run, approved: ok};
}

function render(){
  const v = $("#view");
  if (S.tab === "home") v.replaceChildren(...homeView());
  else if (S.tab === "cash") v.replaceChildren(...cashView());
  else v.replaceChildren(...peopleView());
}

function balanceCard(){
  const {balance, approved} = withRunning();
  const pend = S.cash.filter((e) => e.status === "pending").length;
  return h("section", {class: "card glass bal"},
    h("div", {class: "eyebrow"}, "الرصيد في " + coInfo().name),
    h("div", {class: "big num" + (balance < 0 ? " neg" : "")}, money(balance)),
    h("div", {class: "row"}, h("span", null, "المعتمد: ", h("b", {class: "num"}, money(approved))), pend ? h("span", null, "فيه ", h("b", null, pend), " قيد مستني موافقة") : h("span", null, "كله متراجع ✓")));
}

function homeView(){
  const r = role(), today = cairoDay();
  const pending = S.cash.filter((e) => e.status === "pending");
  const todays = S.cash.filter((e) => e.entry_date === today);
  const mine = todays.filter((e) => e.created_by === S.user.id);
  const items = [];
  if (CAN_APPROVE(r)){
    items.push(h("li", null, h("button", {type: "button", onclick: () => { S.filter = "pending"; setTab("cash"); }},
      h("span", {class: "n" + (pending.length ? "" : " ok")}, pending.length || "✓"),
      h("span", null, h("b", null, pending.length ? "قيود كاش مستنية موافقتك" : "مفيش قيود مستنية موافقة"), h("small", null, pending.length ? "دوس علشان تراجعها وتعتمدها" : "كله متراجع")),
      h("span", {class: "go"}, "‹"))));
  } else {
    const myPend = pending.filter((e) => e.created_by === S.user.id).length;
    if (myPend) items.push(h("li", null, h("div", null, h("span", {class: "n"}, myPend), h("span", null, h("b", null, "قيود سجلتها ولسه مستنية موافقة"), h("small", null, "الحسابات أو المالك هيعتمدوها")))));
  }
  items.push(h("li", null, h("button", {type: "button", onclick: () => { S.filter = "today"; setTab("cash"); }},
    h("span", {class: "n"}, todays.length),
    h("span", null, h("b", null, "قيود اتسجلت النهارده"), h("small", null, "منهم " + mine.length + " سجلتهم إنت")),
    h("span", {class: "go"}, "‹"))));
  items.push(h("li", null, h("button", {type: "button", onclick: () => openAdd()},
    h("span", {class: "n"}, "+"),
    h("span", null, h("b", null, "صرفت أو استلمت فلوس؟"), h("small", null, "سجّلها من زرار + تحت، أقل من دقيقة")))));
  return [
    h("section", {class: "card glass"}, h("h2", null, "المطلوب منك النهارده"), h("ul", {class: "todo"}, items)),
    balanceCard()
  ];
}

function entryRow(e){
  const who = e.person_id ? personName(e.person_id) : "";
  const sub = [dayLabel(e.entry_date), who, e.client].filter(Boolean).join(" · ");
  return h("button", {class: "ent glass", type: "button", onclick: () => openEntry(e.id)},
    h("span", {class: "dir " + e.direction}, e.direction === "in" ? "↓" : "↑"),
    h("span", {class: "mid"}, h("b", null, CAT[e.category] || e.category, e.status === "pending" ? h("span", {class: "tag"}, "مستني موافقة") : null), h("small", null, sub)),
    h("span", {class: "amt"}, h("b", {class: "num", style: {color: e.direction === "in" ? "var(--up)" : "var(--down)"}}, (e.direction === "in" ? "+" : "−") + money(e.amount)),
      h("small", {class: "num"}, "الرصيد " + money(e._run))));
}

function cashView(){
  const {rows} = withRunning();
  const today = cairoDay();
  const list = rows.filter((e) => S.filter === "pending" ? e.status === "pending" : S.filter === "today" ? e.entry_date === today : true);
  const seg = h("div", {class: "tabs glass", style: {"margin-bottom": "10px"}},
    ...[["all", "الكل"], ["pending", "مستني موافقة"], ["today", "النهارده"]].map(([k, t]) => h("button", {type: "button", "aria-pressed": String(S.filter === k), onclick: () => { S.filter = k; render(); }}, t)));
  return [balanceCard(), seg, list.length ? h("div", {class: "list"}, list.map(entryRow)) : h("div", {class: "empty"}, "مفيش قيود هنا")];
}

function peopleView(){
  const owner = role() === "owner";
  const pay = new Map(S.pay.map((p) => [p.person_id, p]));
  const payCell = (p) => {
    const x = pay.get(p.id); if (!x) return "—";
    const bits = [];
    if (x.monthly_salary != null) bits.push(h("span", {class: "num"}, money(x.monthly_salary) + " / شهر"));
    if (x.commission_pct != null) bits.push(h("small", null, "عمولة " + x.commission_pct + "%"));
    if (x.partner_share_pct != null) bits.push(h("span", null, "نصيب الشريك " + x.partner_share_pct + "%"));
    return bits.length ? bits : "—";
  };
  const table = h("table", {class: "ptable"},
    h("thead", null, h("tr", null, h("th", null, "الاسم"), h("th", null, "الدور"), owner ? h("th", null, "المرتب / النسبة") : null)),
    h("tbody", null, S.people.map((p) => h("tr", null,
      h("td", null, p.full_name, h("small", null, coInfo().name)),
      h("td", null, ROLES[p.role] || p.role),
      owner ? h("td", null, payCell(p)) : null))));
  return [h("section", {class: "card glass"}, h("h2", null, "جدول الناس · " + coInfo().name),
    S.people.length ? table : h("div", {class: "empty"}, "مفيش ناس متسجلين"),
    h("div", {class: "lock"}, owner ? "🔒 المرتبات والنسب ظاهرة ليك علشان إنت المالك. محدش غيرك يشوفها." : "🔒 المرتبات والنسب للمالك بس."))];
}

/* ---------- sheets ---------- */
function sheet(title, ...body){
  const bg = h("div", {class: "sheet-bg", onclick: (e) => { if (e.target === bg) bg.remove(); }});
  const box = h("div", {class: "sheet", role: "dialog", "aria-modal": "true"}, h("div", {class: "grab"}),
    h("h3", null, title, h("button", {class: "x", type: "button", "aria-label": "اقفل", onclick: () => bg.remove()}, "×")), ...body);
  bg.append(box); document.body.append(bg);
  return bg;
}

// shrink a photo to a small JPEG (≤ 1000 px) before keeping or uploading it
function shrink(file, max = DEMO ? 700 : 1000, q = 0.7){
  return new Promise((ok, bad) => {
    const img = new Image(), url = URL.createObjectURL(file);
    img.onload = () => {
      const k = Math.min(1, max / Math.max(img.width, img.height));
      const cv = document.createElement("canvas"); cv.width = Math.round(img.width * k); cv.height = Math.round(img.height * k);
      cv.getContext("2d").drawImage(img, 0, 0, cv.width, cv.height); URL.revokeObjectURL(url);
      cv.toBlob((b) => b ? ok({blob: b, dataUrl: cv.toDataURL("image/jpeg", DEMO ? 0.5 : q)}) : bad(new Error("photo")), "image/jpeg", q);
    };
    img.onerror = () => { URL.revokeObjectURL(url); bad(new Error("photo")); };
    img.src = url;
  });
}

// add (or edit) a cash entry: amount keypad first, then category chips, then save
function openAdd(edit){
  const st = {direction: edit ? edit.direction : "out", amount: edit ? String(edit.amount) : "", category: edit ? edit.category : null,
    person_id: edit ? edit.person_id || "" : "", client: edit ? edit.client || "" : "", note: edit ? edit.note || "" : "", photo: null};
  const amt = h("div", {class: "amount num"});
  const paint = () => {
    amt.replaceChildren(st.amount || "0", " ", h("small", null, "ج"));
    dirs.querySelectorAll("button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.d === st.direction)));
    chips.querySelectorAll("button").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.c === st.category)));
    save.disabled = !(+st.amount > 0 && st.category);
  };
  const dirs = h("div", {class: "dirsw"},
    h("button", {type: "button", class: "out", "data-d": "out", onclick: () => { st.direction = "out"; paint(); }}, "↑ خارج"),
    h("button", {type: "button", class: "in", "data-d": "in", onclick: () => { st.direction = "in"; paint(); }}, "↓ داخل"));
  const key = (k) => {
    if (k === "⌫") st.amount = st.amount.slice(0, -1);
    else if (k === "."){ if (!st.amount.includes(".")) st.amount = (st.amount || "0") + "."; }
    else if (st.amount.replace(".", "").length < 9){ st.amount = st.amount === "0" ? k : st.amount + k; }
    paint();
  };
  const pad = h("div", {class: "pad"}, ..."123456789.0⌫".split("").map((k) => h("button", {type: "button", onclick: () => key(k)}, k)));
  const chips = h("div", {class: "chips"}, ...CATS.map(([k, t]) => h("button", {type: "button", "data-c": k, onclick: () => { st.category = k; paint(); }}, t)));
  const personSel = h("select", {id: "f-person", onchange: (e) => { st.person_id = e.target.value; }},
    h("option", {value: ""}, "— مفيش —"), ...S.people.map((p) => h("option", {value: p.id, selected: p.id === st.person_id}, p.full_name + " · " + (ROLES[p.role] || ""))));
  const client = h("input", {id: "f-client", value: st.client, placeholder: "اختياري", maxlength: "120", oninput: (e) => { st.client = e.target.value; }});
  const note = h("input", {id: "f-note", value: st.note, placeholder: "اختياري", maxlength: "500", oninput: (e) => { st.note = e.target.value; }});
  const thumb = h("img", {alt: "", hidden: true});
  const file = h("input", {type: "file", accept: "image/*", capture: "environment", id: "f-photo", hidden: true, onchange: async (e) => {
    const f = e.target.files && e.target.files[0]; if (!f) return;
    try { st.photo = await shrink(f); thumb.src = st.photo.dataUrl; thumb.hidden = false; } catch { toast("مقدرناش نقرا الصورة"); }
  }});
  const err = h("div", {class: "gerr", role: "alert"});
  const save = h("button", {class: "btn wide", type: "button", onclick: async () => {
    save.disabled = true; err.textContent = "";
    try {
      const entry = {direction: st.direction, amount: +st.amount, category: st.category, person_id: st.person_id || null, client: st.client.trim() || null, note: st.note.trim() || null};
      if (edit){
        const ch = {};
        for (const k of Object.keys(entry)) if (String(entry[k] ?? "") !== String(edit[k] ?? "")) ch[k] = entry[k];
        if (st.photo){
          if (DEMO) ch.receipt_path = st.photo.dataUrl;
          else { const p = S.co + "/" + uid() + ".jpg"; const r = await sb.storage.from("sys-receipts").upload(p, st.photo.blob, {contentType: "image/jpeg"}); if (r.error) throw r.error; ch.receipt_path = p; }
        }
        if (Object.keys(ch).length) await API.updateCash(edit.id, ch);
        toast(Object.keys(ch).length ? "اتعدّل واتسجل في سجل التعديلات" : "مفيش تغيير");
      } else {
        await API.addCash(S.co, entry, st.photo ? (DEMO ? st.photo.dataUrl : st.photo.blob) : null);
        toast(CAN_APPROVE(role()) ? "اتسجل ✓ (مستني اعتماد)" : "اتسجل ✓ ومستني موافقة الحسابات");
      }
      bg.remove(); await loadCompany();
    } catch (x) { err.textContent = (x && x.message) || "مقدرناش نحفظ"; save.disabled = false; }
  }}, edit ? "احفظ التعديل" : "حفظ");
  const bg = sheet(edit ? "تعديل قيد" : "قيد جديد · " + coInfo().name,
    dirs, amt, pad,
    h("div", {class: "lbl"}, "البند"), chips,
    h("div", {class: "more"},
      h("div", {class: "fld"}, h("label", {for: "f-person"}, "الشخص (اختياري)"), personSel),
      h("div", {class: "fld"}, h("label", {for: "f-client"}, "العميل (اختياري)"), client),
      edit ? h("div", {class: "fld"}, h("label", {for: "f-note"}, "ملاحظة (اختياري)"), note) : null,
      h("div", {class: "photo"}, h("label", {for: "f-photo"}, edit && edit.receipt_path ? "📷 غيّر صورة الإيصال" : "📷 صورة الإيصال (اختياري)"), file, thumb)),
    err, save);
  paint();
}

async function openEntry(id){
  const e = S.cash.find((x) => x.id === id); if (!e) return;
  const r = role();
  const kv = h("dl", {class: "kv"},
    h("dt", null, "النوع"), h("dd", null, e.direction === "in" ? "داخل" : "خارج"),
    h("dt", null, "المبلغ"), h("dd", {class: "num"}, money(e.amount)),
    h("dt", null, "البند"), h("dd", null, CAT[e.category] || e.category),
    h("dt", null, "التاريخ"), h("dd", null, dayLabel(e.entry_date)),
    e.person_id ? [h("dt", null, "الشخص"), h("dd", null, personName(e.person_id))] : null,
    e.client ? [h("dt", null, "العميل"), h("dd", null, e.client)] : null,
    e.note ? [h("dt", null, "ملاحظة"), h("dd", null, e.note)] : null,
    h("dt", null, "سجّله"), h("dd", null, API.userName(e.created_by) + " · " + timeLabel(e.created_at)),
    h("dt", null, "الحالة"), h("dd", null, e.status === "approved" ? h("span", {class: "tag ok"}, "معتمد" + (e.approved_by ? " · " + API.userName(e.approved_by) : "")) : h("span", {class: "tag"}, "مستني موافقة")));
  const pic = h("div");
  const hist = h("div");
  const btns = h("div", {class: "row-btns"});
  if (CAN_APPROVE(r)){
    if (e.status === "pending") btns.append(h("button", {class: "btn", type: "button", onclick: async (ev) => {
      ev.currentTarget.disabled = true;
      try { await API.updateCash(e.id, {status: "approved"}); toast("اتعتمد ✓"); bg.remove(); await loadCompany(); } catch (x) { toast((x && x.message) || "مقدرناش"); ev.currentTarget.disabled = false; }
    }}, "اعتمد"));
    btns.append(h("button", {class: "btn ghost", type: "button", onclick: () => { bg.remove(); openAdd(e); }}, "عدّل"));
  }
  const bg = sheet((e.direction === "in" ? "داخل · " : "خارج · ") + (CAT[e.category] || ""), kv, pic, hist, btns,
    h("p", {class: "hint", style: {"margin-top": "10px"}}, "القيود مبتتمسحش. أي تعديل بيتسجل: مين غيّر إيه وإمتى."));
  if (e.receipt_path){ const u = await API.receiptUrl(e.receipt_path); if (u) pic.append(h("img", {class: "receipt", src: u, alt: "صورة الإيصال"})); }
  const rows = await API.audit(e.id);
  if (rows.length){
    hist.append(h("div", {class: "lbl"}, "سجل التعديلات"), h("ul", {class: "audit"}, rows.map((a) => h("li", null,
      h("small", null, API.userName(a.changed_by) + " · " + timeLabel(a.changed_at)), h("br"),
      (a.fields || []).map((f) => h("div", null, (FIELD_AR[f] || f) + ": ", h("s", null, show(f, a.old_row[f])), " ← ", h("b", null, show(f, a.new_row[f]))))))));
  }
}
function show(f, v){
  if (v == null || v === "") return "—";
  if (f === "amount") return money(v);
  if (f === "category") return CAT[v] || v;
  if (f === "direction") return v === "in" ? "داخل" : "خارج";
  if (f === "status") return v === "approved" ? "معتمد" : "مستني";
  if (f === "person_id") return personName(v) || "—";
  if (f === "receipt_path") return "صورة";
  return String(v);
}

/* ---------- login ---------- */
$("#login-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const btn = $("#l-btn"), err = $("#l-err"); err.textContent = ""; btn.disabled = true;
  try { const u = await API.signIn($("#l-email").value, $("#l-pw").value); $("#l-pw").value = ""; await enter(u); }
  catch (x) { err.textContent = (x && x.message) || "مقدرناش ندخلك"; }
  finally { btn.disabled = false; }
});
async function logout(){ await API.signOut(); S.user = null; S.companies = []; document.querySelectorAll(".sheet-bg").forEach((x) => x.remove()); showGate("g-login"); }
$("#btn-out").onclick = logout;
$("#none-out").onclick = logout;
$("#fab").onclick = () => openAdd();

/* ---------- install (same idea as /app) ---------- */
let deferred = null;
const standalone = matchMedia("(display-mode: standalone)").matches || matchMedia("(display-mode: fullscreen)").matches || navigator.standalone;
addEventListener("beforeinstallprompt", (e) => { e.preventDefault(); deferred = e; $("#g-install-btn").hidden = false; $("#btn-install").hidden = false; });
addEventListener("appinstalled", () => { deferred = null; $("#btn-install").hidden = true; });
const promptInstall = async () => { if (!deferred) return; deferred.prompt(); await deferred.userChoice.catch(() => {}); deferred = null; $("#btn-install").hidden = true; };
$("#g-install-btn").onclick = promptInstall;
$("#btn-install").onclick = promptInstall;
if ("serviceWorker" in navigator) addEventListener("load", () => navigator.serviceWorker.register("/sys/sw.js", {scope: "/sys/"}).catch(() => {}));

/* ---------- boot ---------- */
(async () => {
  if (DEMO){
    $("#demo-bar").hidden = false;
    $("#demo-login").hidden = false;
    $("#l-sub").textContent = "دي نسخة تجريبية: الحسابات والأرقام كلها وهمية.";
    $("#demo-users").replaceChildren(...DEMO_USERS.map((u) => h("button", {type: "button", onclick: async () => {
      $("#l-err").textContent = "";
      try { await enter(await API.signIn(u.email, DEMO_PW)); } catch (x) { $("#l-err").textContent = x.message; }
    }}, h("b", null, u.name), h("small", null, [...new Set(Object.values(u.roles))].map((r) => ROLES[r] + ": " + Object.keys(u.roles).filter((c) => u.roles[c] === r).map((c) => (DEMO_COMPANIES.find((x) => x.company_id === c) || {}).name).join("، ")).join(" · ")))));
    $("#login-form").append(h("button", {type: "button", class: "btn ghost wide", style: {"margin-top": "4px", "font-size": "13px"}, onclick: async () => { demoApi.reset(); await dbLoad(); toast("الداتا التجريبية رجعت زي الأول"); }}, "رجّع الداتا التجريبية زي الأول"));
    if (!crypto.subtle){ $("#l-err").textContent = "المتصفح ده مش بيدعم التشفير (لازم https)."; showGate("g-login"); return; }
  } else if (!standalone){
    // real system opened in a browser: show the install page only, same as /app
    showGate("g-install");
    const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
    const steps = ios ? ["افتح الصفحة دي في Safari.", "دوس زرار المشاركة (المربع اللي فيه سهم).", "اختار «Add to Home Screen» وبعدين «Add».", "افتح «الشركات» من الشاشة الرئيسية وادخل بإيميلك."]
      : ["افتح الصفحة دي في Chrome.", "دوس «سطّب التطبيق»، أو من القايمة ⋮ اختار «Install app».", "افتح «الشركات» من قايمة التطبيقات وادخل بإيميلك."];
    $("#g-steps").replaceChildren(...steps.map((t) => h("li", null, t)));
    return;
  }
  try { const u = await API.session(); if (u) await enter(u); else showGate("g-login"); }
  catch { showGate("g-login"); }
})();

})();
