// Tuya Suez partners dashboard: minimal service worker so the page installs as an app.
// Network-first for everything; only the shell is cached for offline open.
const CACHE = 'ts-dash-v2';
const SHELL = ['./', './index.html', './manifest.webmanifest', '/tuya-suez/icon.png'];
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith(fetch(req).catch(() => caches.match(req).then((r) => r || caches.match('./'))));
});
