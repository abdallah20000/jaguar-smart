// «نظام الشركة» Web Push sender (Cloudflare Pages Function, POST only).
// Called by Postgres (pg_net, see supabase/migrations/115) with the header x-sys-push-secret.
// Body: { notification: { title, body, kind, url, id }, subscriptions: [{ endpoint, p256dh, auth }] }
// Encryption: RFC 8291 (aes128gcm, RFC 8188 framing). Auth: RFC 8292 VAPID (ES256 JWT). WebCrypto only, no libraries.
// Env: SYS_PUSH_SECRET, VAPID_PUBLIC_KEY (base64url, 65-byte uncompressed point), VAPID_PRIVATE_KEY (base64url, 32-byte d), VAPID_SUBJECT.

const enc = new TextEncoder();
const MAX_SUBS = 50;
const MAX_BODY = 64 * 1024;
const MAX_PAYLOAD = 3500; // one 4096-byte record minus header (86) and padding/tag, with margin

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });

function b64uToBytes(s) {
  s = String(s || '').replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function bytesToB64u(b) {
  let s = '';
  for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function concat(...arrs) {
  const out = new Uint8Array(arrs.reduce((n, a) => n + a.length, 0));
  let o = 0;
  for (const a of arrs) { out.set(a, o); o += a.length; }
  return out;
}

// constant-time compare: hash both sides first so lengths never leak, then XOR the digests
async function safeEqual(a, b) {
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(String(a))),
    crypto.subtle.digest('SHA-256', enc.encode(String(b))),
  ]);
  const x = new Uint8Array(ha), y = new Uint8Array(hb);
  let d = 0;
  for (let i = 0; i < x.length; i++) d |= x[i] ^ y[i];
  return d === 0;
}

function allowedEndpoint(raw) {
  let u;
  try { u = new URL(raw); } catch { return null; }
  if (u.protocol !== 'https:' || u.username || u.password || (u.port && u.port !== '443')) return null;
  const h = u.hostname.toLowerCase();
  const ok =
    h === 'fcm.googleapis.com' ||
    h === 'updates.push.services.mozilla.com' ||
    h.endsWith('.push.apple.com') ||
    h.endsWith('.notify.windows.com');
  return ok ? u : null;
}

async function hkdf(ikm, salt, info, bytes) {
  const key = await crypto.subtle.importKey('raw', ikm, 'HKDF', false, ['deriveBits']);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: 'HKDF', hash: 'SHA-256', salt, info }, key, bytes * 8));
}

// RFC 8291 §3.4 + RFC 8188: returns the full aes128gcm request body (header + one record)
async function encryptPayload(plaintext, uaPublicB64u, authB64u) {
  const uaPublic = b64uToBytes(uaPublicB64u);
  const authSecret = b64uToBytes(authB64u);
  if (uaPublic.length !== 65 || uaPublic[0] !== 4) throw new Error('bad p256dh');
  if (authSecret.length !== 16) throw new Error('bad auth');
  if (plaintext.length > MAX_PAYLOAD) throw new Error('payload too large');

  const asKeys = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const asPublic = new Uint8Array(await crypto.subtle.exportKey('raw', asKeys.publicKey));
  const uaKey = await crypto.subtle.importKey('raw', uaPublic, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: 'ECDH', public: uaKey }, asKeys.privateKey, 256));

  const keyInfo = concat(enc.encode('WebPush: info\0'), uaPublic, asPublic);
  const ikm = await hkdf(ecdh, authSecret, keyInfo, 32);

  const salt = crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(ikm, salt, enc.encode('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdf(ikm, salt, enc.encode('Content-Encoding: nonce\0'), 12);

  const record = concat(plaintext, new Uint8Array([2])); // 0x02 = last record delimiter, no extra padding
  const aes = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, aes, record));

  const rs = new Uint8Array([0, 0, 0x10, 0]); // 4096, big-endian
  return concat(salt, rs, new Uint8Array([asPublic.length]), asPublic, ct);
}

// RFC 8292: ES256 JWT, 12h life; WebCrypto returns the raw r||s signature, which is what JWS wants
async function vapidHeader(audience, env, signKey) {
  const header = bytesToB64u(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const claims = bytesToB64u(enc.encode(JSON.stringify({
    aud: audience,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: env.VAPID_SUBJECT,
  })));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, signKey, enc.encode(header + '.' + claims)));
  return 'vapid t=' + header + '.' + claims + '.' + bytesToB64u(sig) + ', k=' + env.VAPID_PUBLIC_KEY;
}

async function importVapidKey(env) {
  const pub = b64uToBytes(env.VAPID_PUBLIC_KEY);
  const d = b64uToBytes(env.VAPID_PRIVATE_KEY);
  if (pub.length !== 65 || pub[0] !== 4 || d.length !== 32) throw new Error('bad vapid keys');
  return crypto.subtle.importKey(
    'jwk',
    { kty: 'EC', crv: 'P-256', x: bytesToB64u(pub.slice(1, 33)), y: bytesToB64u(pub.slice(33, 65)), d: bytesToB64u(d), ext: true },
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
}

export async function onRequest({ request, env }) {
  if (request.method !== 'POST') return json({ error: 'method not allowed' }, 405);
  if (!env.SYS_PUSH_SECRET) return json({ error: 'not configured' }, 500);
  if (!(await safeEqual(request.headers.get('x-sys-push-secret') || '', env.SYS_PUSH_SECRET))) {
    return json({ error: 'unauthorized' }, 401);
  }
  if (!env.VAPID_PUBLIC_KEY || !env.VAPID_PRIVATE_KEY || !env.VAPID_SUBJECT) return json({ error: 'vapid not configured' }, 500);

  const raw = await request.text();
  if (raw.length > MAX_BODY) return json({ error: 'too large' }, 413);
  let data;
  try { data = JSON.parse(raw); } catch { return json({ error: 'bad json' }, 400); }
  const n = data && data.notification;
  const subs = data && data.subscriptions;
  if (!n || typeof n !== 'object' || !Array.isArray(subs)) return json({ error: 'bad body' }, 400);

  let signKey;
  try { signKey = await importVapidKey(env); } catch { return json({ error: 'vapid keys invalid' }, 500); }

  const payload = enc.encode(JSON.stringify({
    title: String(n.title || '').slice(0, 200),
    body: String(n.body || '').slice(0, 600),
    kind: String(n.kind || 'general').slice(0, 60),
    url: typeof n.url === 'string' && n.url.startsWith('/') ? n.url : '/system/',
    id: n.id == null ? undefined : String(n.id),
  }));

  const gone = [];
  let sent = 0, failed = 0, rejected = 0;
  const list = subs.slice(0, MAX_SUBS);
  rejected += Math.max(0, subs.length - list.length);
  const vapidCache = new Map(); // one JWT per push-service origin

  await Promise.all(list.map(async (s) => {
    const u = s && typeof s.endpoint === 'string' ? allowedEndpoint(s.endpoint) : null;
    if (!u) { rejected++; return; }
    try {
      const body = await encryptPayload(payload, s.p256dh, s.auth);
      if (!vapidCache.has(u.origin)) vapidCache.set(u.origin, vapidHeader(u.origin, env, signKey));
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 8000);
      let res;
      try {
        res = await fetch(u.href, {
          method: 'POST',
          headers: {
            Authorization: await vapidCache.get(u.origin),
            'Content-Encoding': 'aes128gcm',
            'Content-Type': 'application/octet-stream',
            TTL: '86400',
            Urgency: 'normal',
          },
          body,
          signal: ctrl.signal,
        });
      } finally { clearTimeout(timer); }
      if (res.status >= 200 && res.status < 300) sent++;
      else { failed++; if (res.status === 404 || res.status === 410) gone.push(s.endpoint); }
    } catch {
      failed++;
    }
  }));

  return json({ sent, failed, rejected, gone });
}
