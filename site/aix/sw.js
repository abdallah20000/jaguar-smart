// Offline shell for the AIX PWA. API calls always go to the network.
const CACHE = 'aix-shell-v4';
const SHELL = ['./', 'index.html', 'styles.css', 'app.js', 'api.js', 'data.js', 'icon.svg', 'wallpaper.jpg', 'manifest.webmanifest'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (url.pathname.includes('/api/') || e.request.method !== 'GET') return;
  // Stale-while-revalidate: paint instantly from cache, refresh the copy in the background.
  e.respondWith(caches.open(CACHE).then(c => c.match(e.request).then(hit => {
    const net = fetch(e.request).then(r => { if (r && (r.ok || r.type === 'opaque')) c.put(e.request, r.clone()); return r; }).catch(() => hit);
    return hit || net;
  })));
});
