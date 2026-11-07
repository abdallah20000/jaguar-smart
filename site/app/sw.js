// Control center app shell. Pages and data come fresh from the network, but a slow network never
// blocks opening: after 2.5 s the last saved copy is shown. The pinned Supabase library is kept offline.
const CACHE = 'cc-app-v18';
const SHELL = ['/app/', '/app/manifest.webmanifest', '/app/icon-192.png', '/app/icon-512.png', '/app/bg/room-tall.jpg', '/app/bg/room-wide.jpg'];
const LIB = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL).then(() => c.add(new Request(LIB, {mode: 'cors'})).catch(() => {}))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
const save = (req, res) => { if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {}); } return res; };
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  // versioned library: cache first
  if (url.href === LIB) {
    e.respondWith(caches.match(LIB).then((r) => r || fetch(e.request).then((res) => save(LIB, res))));
    return;
  }
  if (url.origin !== location.origin || !url.pathname.startsWith('/app/')) return;
  const net = fetch(e.request).then((res) => save(e.request, res));
  net.catch(() => {});
  const cached = () => caches.match(e.request, {ignoreSearch: e.request.mode === 'navigate'}).then((r) => r || (e.request.mode === 'navigate' ? caches.match('/app/') : undefined));
  const late = new Promise((r) => setTimeout(r, 2500));
  e.respondWith(
    Promise.race([net, late.then(cached)])
      .then((res) => res || net)
      .catch(() => cached().then((r) => r || net))
  );
});
