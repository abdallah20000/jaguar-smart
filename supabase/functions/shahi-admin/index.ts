// SHAHI team management (admins only): create accounts, reset passwords, activate / deactivate.
// Account creation needs the service role, so it runs here instead of in the browser.
import { createClient } from "jsr:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const ROLES = ["admin", "sales", "ops", "chef"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "method" });

  const auth = req.headers.get("Authorization") ?? "";
  const asUser = createClient(URL, ANON, { global: { headers: { Authorization: auth } } });
  const { data: { user } } = await asUser.auth.getUser();
  if (!user) return reply(401, { error: "not signed in" });

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  const { data: me } = await admin.from("shahi_staff").select("role,active,full_name").eq("user_id", user.id).maybeSingle();
  if (!me || !me.active || me.role !== "admin") return reply(403, { error: "admins only" });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "bad json" }); }
  const log = (action: string, entity_id: string, details: unknown) =>
    admin.from("shahi_activity_log").insert({ actor: user.id, actor_email: user.email, action, entity: "shahi_staff", entity_id, details });

  const password = String(body.password ?? "");
  const strong = password.length >= 8;

  switch (body.action) {
    case "create": {
      const email = String(body.email ?? "").trim().toLowerCase();
      const full_name = String(body.full_name ?? "").trim();
      const role = String(body.role ?? "");
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || !full_name || !ROLES.includes(role)) return reply(400, { error: "missing fields" });
      if (!strong) return reply(400, { error: "password must be at least 8 characters" });
      const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name } });
      if (error || !data.user) return reply(409, { error: error?.message ?? "could not create user" });
      const { error: e2 } = await admin.from("shahi_staff").insert({ user_id: data.user.id, email, full_name, role, active: true });
      if (e2) { await admin.auth.admin.deleteUser(data.user.id); return reply(500, { error: e2.message }); }
      await log("create account", data.user.id, { email, full_name, role });
      return reply(200, { ok: true, user_id: data.user.id });
    }
    case "set_password": {
      const id = String(body.user_id ?? "");
      if (!strong) return reply(400, { error: "password must be at least 8 characters" });
      const { data: target } = await admin.from("shahi_staff").select("user_id").eq("user_id", id).maybeSingle();
      if (!target) return reply(404, { error: "not a Shahi team member" });
      const { error } = await admin.auth.admin.updateUserById(id, { password });
      if (error) return reply(500, { error: error.message });
      await log("reset password", id, null);
      return reply(200, { ok: true });
    }
    case "set_active": {
      const id = String(body.user_id ?? "");
      const active = body.active === true;
      if (id === user.id && !active) return reply(400, { error: "you cannot deactivate yourself" });
      const { data: target } = await admin.from("shahi_staff").select("user_id").eq("user_id", id).maybeSingle();
      if (!target) return reply(404, { error: "not a Shahi team member" });
      const { error } = await admin.from("shahi_staff").update({ active }).eq("user_id", id);
      if (error) return reply(500, { error: error.message });
      // a deactivated member is also signed out everywhere and cannot sign in again
      await admin.auth.admin.updateUserById(id, { ban_duration: active ? "none" : "876000h" });
      await log(active ? "activate account" : "deactivate account", id, null);
      return reply(200, { ok: true });
    }
    default:
      return reply(400, { error: "unknown action" });
  }
});
