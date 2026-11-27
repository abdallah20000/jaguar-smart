// «نظام الشركة — AIX»: app-shell cache only. Never caches Supabase (/rest/, /auth/) or any cross-origin request.
const CACHE = 'aix-sys-shell-v1';
const SHELL = ['/aix-system/', '/aix-system/index.html', '/aix-system/manifest.webmanifest', '/aix-system/icon.png'];
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request, u = new URL(req.url);
  if (req.method !== 'GET' || u.origin !== location.origin) return;
  if (u.pathname.includes('/rest/') || u.pathname.includes('/auth/')) return;
  if (!u.pathname.startsWith('/aix-system/')) return;
  e.respondWith(fetch(req).then((r) => {
    if (r.ok && SHELL.includes(u.pathname)) { const copy = r.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
    return r;
  }).catch(() => caches.match(req).then((r) => r || caches.match('/aix-system/index.html'))));
});
