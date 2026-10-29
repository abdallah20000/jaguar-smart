// SHAHI lead intake for outside systems (the n8n WhatsApp bot).
// POST JSON { phone, name?, area?, request?, notes?, source? }
// with the secret in the header:  x-shahi-token: <SHAHI_WEBHOOK_TOKEN>   (or Authorization: Bearer <token>)
import { createClient } from "jsr:@supabase/supabase-js@2";

const TOKEN = Deno.env.get("SHAHI_WEBHOOK_TOKEN") ?? "";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const SOURCES = ["website", "whatsapp", "ad", "facebook", "instagram", "tiktok", "phone", "other"];

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

// constant-time comparison so the token cannot be guessed byte by byte
function same(a: string, b: string) {
  const x = new TextEncoder().encode(a), y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "use POST" });
  const given = req.headers.get("x-shahi-token") ?? (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!TOKEN || !same(given, TOKEN)) return reply(401, { error: "invalid token" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad json" }); }
  const str = (k: string, max: number) => (typeof body[k] === "string" ? (body[k] as string).trim().slice(0, max) : "");
  const phone = str("phone", 30);
  if (!phone) return reply(400, { error: "phone is required" });
  const source = SOURCES.includes(str("source", 20).toLowerCase()) ? str("source", 20).toLowerCase() : "whatsapp";

  const { data, error } = await db.rpc("shahi_ingest_lead", {
    p: { phone, name: str("name", 120), area: str("area", 80), request: str("request", 2000), notes: str("notes", 2000), source },
  });
  if (error) return reply(error.message.includes("invalid phone") ? 400 : 500, { error: error.message });
  return reply(200, { ok: true, lead_id: data });
});
