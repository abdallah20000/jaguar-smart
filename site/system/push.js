// «نظام الشركة» — Web Push client. Exposes window.SysPush = { supported(), status(), enable(sb), disable(sb) }.
// VAPID_PUBLIC_KEY stays empty until Abdallah generates the pair in /system/vapid.html and the coordinator pastes
// the PUBLIC key here. Empty = status() 'not-configured' and enable() does nothing.
(function () {
  'use strict';
  var VAPID_PUBLIC_KEY = '';
  var SW_URL = '/system/sw.js';
  var SCOPE = '/system/';
  var FLAG = 'sys-push-on';

  // demo / preview hosts (anything but production) never touch the network and never ask for permission
  function isProd() { return location.hostname === 'jaguarsmart.com' || location.hostname === 'www.jaguarsmart.com'; }

  function supported() {
    return typeof navigator !== 'undefined' && 'serviceWorker' in navigator &&
      typeof window !== 'undefined' && 'PushManager' in window && 'Notification' in window;
  }
  function flag(v) {
    try {
      if (v === undefined) return localStorage.getItem(FLAG) === '1';
      if (v) localStorage.setItem(FLAG, '1'); else localStorage.removeItem(FLAG);
    } catch (e) { /* storage blocked: status falls back to 'off' */ }
    return false;
  }
  // 'unsupported' | 'not-configured' | 'denied' | 'off' | 'on'   (synchronous; 'on' = this browser opted in and permission is granted)
  function status() {
    if (!supported()) return 'unsupported';
    if (!VAPID_PUBLIC_KEY) return 'not-configured';
    if (Notification.permission === 'denied') return 'denied';
    return Notification.permission === 'granted' && flag() ? 'on' : 'off';
  }
  function keyBytes(b64u) {
    var s = b64u.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4) s += '=';
    var bin = atob(s), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }
  function registration() {
    return navigator.serviceWorker.getRegistration(SCOPE).then(function (r) {
      return r || navigator.serviceWorker.register(SW_URL, { scope: SCOPE });
    }).then(function () { return navigator.serviceWorker.ready; });
  }
  function unwrap(res) { if (res && res.error) throw new Error(res.error.message || 'rpc failed'); return res; }

  function enable(sb) {
    var st = status();
    if (st === 'unsupported' || st === 'not-configured' || st === 'denied') return Promise.resolve(st);
    if (!isProd()) return Promise.resolve(st);   // demo: no permission prompt, no network
    return Notification.requestPermission().then(function (perm) {
      if (perm !== 'granted') { flag(false); return status(); }
      return registration().then(function (reg) {
        var opts = { userVisibleOnly: true, applicationServerKey: keyBytes(VAPID_PUBLIC_KEY) };
        return reg.pushManager.subscribe(opts).catch(function (e) {
          // an old subscription made with another key blocks subscribe(): drop it and retry once
          if (e && e.name === 'InvalidStateError') {
            return reg.pushManager.getSubscription().then(function (old) { return old && old.unsubscribe(); })
              .then(function () { return reg.pushManager.subscribe(opts); });
          }
          throw e;
        });
      }).then(function (sub) {
        var j = sub.toJSON(), k = j.keys || {};
        return Promise.resolve(sb.rpc('sys_push_subscribe', { p_endpoint: j.endpoint, p_p256dh: k.p256dh, p_auth: k.auth }))
          .then(unwrap)
          .then(function () { flag(true); return status(); })
          .catch(function (e) { return sub.unsubscribe().catch(function () {}).then(function () { flag(false); throw e; }); });
      });
    });
  }

  function disable(sb) {
    flag(false);
    if (!supported() || !isProd()) return Promise.resolve(status());
    return navigator.serviceWorker.getRegistration(SCOPE).then(function (reg) {
      return reg ? reg.pushManager.getSubscription() : null;
    }).then(function (sub) {
      if (!sub) return null;
      var endpoint = sub.endpoint;
      // always drop the browser subscription, even if the RPC fails (a dead endpoint just returns 404/410 later)
      return Promise.resolve(sb.rpc('sys_push_unsubscribe', { p_endpoint: endpoint })).then(unwrap)
        .catch(function () {})
        .then(function () { return sub.unsubscribe(); });
    }).then(function () { return status(); });
  }

  window.SysPush = { supported: supported, status: status, enable: enable, disable: disable };
})();
