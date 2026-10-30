// SHAHI team sign-up: a single-use code from an admin creates the account, with the name and role set on the code.
// The visitor has no session yet, so deploy with JWT verification off. The code is the only gate.
import { createClient } from "jsr:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const sha256 = async (text: string) =>
  [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)))]
    .map((b) => b.toString(16).padStart(2, "0")).join("");

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad json" }); }
  const email = String(body.email ?? "").trim().toLowerCase();
  const code = String(body.code ?? "").trim().toUpperCase();
  const password = String(body.password ?? "");
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return reply(400, { error: "اكتب إيميل صحيح" });
  if (!code) return reply(400, { error: "اكتب كود التسجيل" });
  if (password.length < 8) return reply(400, { error: "الباسورد لازم تكون 8 حروف على الأقل" });

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });

  // claiming in one update means two people can never use the same code
  const { data: invite } = await admin.from("shahi_invites").update({ used_at: new Date().toISOString() })
    .eq("code_hash", await sha256(code)).is("used_at", null).gt("expires_at", new Date().toISOString())
    .select("id,full_name,role").maybeSingle();
  if (!invite) return reply(400, { error: "الكود غلط أو اتستخدم قبل كده أو انتهى" });
  const release = () => admin.from("shahi_invites").update({ used_at: null }).eq("id", invite.id);

  const { data, error } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { full_name: invite.full_name },
  });
  if (error || !data.user) {
    await release();
    return error?.code === "email_exists"
      ? reply(409, { error: "الإيميل ده متسجل قبل كده. استخدم إيميل تاني أو كلّم الأدمن" })
      : reply(500, { error: "مقدرناش نعمل الحساب. جرّب تاني" });
  }

  const { error: e2 } = await admin.from("shahi_staff")
    .insert({ user_id: data.user.id, email, full_name: invite.full_name, role: invite.role, active: true });
  if (e2) {
    await admin.auth.admin.deleteUser(data.user.id);
    await release();
    return reply(500, { error: "مقدرناش نعمل الحساب. جرّب تاني" });
  }

  await admin.from("shahi_invites").update({ used_by: data.user.id }).eq("id", invite.id);
  await admin.from("shahi_activity_log").insert({
    actor: data.user.id, actor_email: email, action: "join with code", entity: "shahi_invites", entity_id: invite.id, details: { role: invite.role },
  });
  return reply(200, { ok: true });
});
