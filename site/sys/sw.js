// «نظام الشركات» app shell (scope /sys/). Pages come fresh from the network; after 2.5 s without an answer the
// last saved copy is shown. Data (Supabase) is never cached here.
const CACHE = 'sys-v1';
const SHELL = ['/sys/', '/sys/app.js', '/sys/manifest.webmanifest', '/sys/icon-192.png', '/sys/icon-512.png'];
const LIB = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL).then(() => c.add(new Request(LIB, {mode: 'cors'})).catch(() => {}))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k.startsWith('sys-') && k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
const save = (req, res) => { if (res && res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {}); } return res; };
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  if (url.href === LIB) { e.respondWith(caches.match(LIB).then((r) => r || fetch(e.request).then((res) => save(LIB, res)))); return; }
  if (url.origin !== location.origin || !url.pathname.startsWith('/sys/')) return;
  const net = fetch(e.request).then((res) => save(e.request, res));
  net.catch(() => {});
  const cached = () => caches.match(e.request, {ignoreSearch: e.request.mode === 'navigate'}).then((r) => r || (e.request.mode === 'navigate' ? caches.match('/sys/') : undefined));
  const late = new Promise((r) => setTimeout(r, 2500));
  e.respondWith(Promise.race([net, late.then(cached)]).then((res) => res || net).catch(() => cached().then((r) => r || net)));
});
