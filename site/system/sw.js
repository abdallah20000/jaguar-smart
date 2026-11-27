// «نظام الشركة»: app-shell cache only. Never caches Supabase (/rest/, /auth/) or any cross-origin request.
const CACHE = 'sys-shell-v2';
const SHELL = ['/system/', '/system/index.html', '/system/manifest.webmanifest', '/system/icon.png', '/system/push.js'];
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
  if (!u.pathname.startsWith('/system/')) return;
  e.respondWith(fetch(req).then((r) => {
    if (r.ok && SHELL.includes(u.pathname)) { const copy = r.clone(); caches.open(CACHE).then((c) => c.put(req, copy)); }
    return r;
  }).catch(() => caches.match(req).then((r) => r || caches.match('/system/index.html'))));
});

// Web Push: payload is JSON {title, body, kind, url, id} (functions/api/sys-push.js). tag = kind so a burst of the same kind collapses.
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { try { d = { body: e.data.text() }; } catch (__) { d = {}; } }
  const kind = d.kind || 'general';
  e.waitUntil(self.registration.showNotification(d.title || 'نظام الشركة', {
    body: d.body || '',
    tag: kind,
    renotify: true,
    icon: '/system/icon.png',
    badge: '/system/icon.png',
    dir: 'rtl',
    lang: 'ar',
    data: { url: typeof d.url === 'string' && d.url.startsWith('/') ? d.url : '/system/', id: d.id || null },
  }));
});
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || '/system/', self.location.origin).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const c of list) {
      if (new URL(c.url).pathname.startsWith('/system/') && 'focus' in c) return c.focus();
    }
    return self.clients.openWindow(url);
  }));
});
