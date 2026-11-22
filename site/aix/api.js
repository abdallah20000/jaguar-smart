// AIX data layer.
// Live mode: talks to our own backend (/api/*) which holds the Tuya keys server-side.
// Demo mode: the same calls run against a local copy of AIX_DEMO (saved in this browser).
(function () {
  const KEY = 'aix-demo-v2';
  const API = (window.AIX_API_BASE || '') + '/api';
  const H = () => (window.AIX_APP_KEY ? { 'x-aix-key': window.AIX_APP_KEY } : {});
  let mode = 'demo';
  let state;

  function loadDemo() {
    try { const s = localStorage.getItem(KEY); if (s) return JSON.parse(s); } catch (e) {}
    return JSON.parse(JSON.stringify(window.AIX_DEMO));
  }
  function saveDemo() { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) {} }

  async function detect() {
    if (!location.protocol.startsWith('http')) return 'demo';
    try {
      const r = await fetch(API + '/health', { cache: 'no-store' });
      if (!r.ok) return 'demo';
      const j = await r.json();
      return j && j.tuya === true ? 'live' : 'demo';
    } catch (e) { return 'demo'; }
  }

  // Apply a patch to a device in the local state (demo, and optimistic UI in live mode).
  function applyLocal(dev, patch) {
    if ('on' in patch) dev.on = patch.on;
    if ('bright' in patch) dev.bright = patch.bright;
    if ('temp' in patch) dev.temp = Math.max(16, Math.min(30, patch.temp));
    if ('mode' in patch) dev.mode = patch.mode;
    if ('pos' in patch) dev.pos = Math.max(0, Math.min(100, patch.pos));
    if ('locked' in patch) dev.locked = patch.locked;
    if ('all' in patch && dev.gangs) dev.gangs.forEach(g => g.on = patch.all);
    if ('gang' in patch && dev.gangs) { const g = dev.gangs.find(x => x.code === patch.gang[0]); if (g) g.on = patch.gang[1]; }
    if ('grouped' in patch) dev.grouped = patch.grouped;
    if ('gangMeta' in patch && dev.gangs) { const [code, meta] = patch.gangMeta; const g = dev.gangs.find(x => x.code === code); if (g) Object.assign(g, meta); }
    if (dev.type === 'plug') dev.power = dev.on ? 1850 : 0;
  }

  // Translate an AIX patch into Tuya data-point commands (used by the backend in live mode).
  function toTuya(dev, patch) {
    const c = [];
    if (dev.type === 'light') {
      if ('on' in patch) c.push({ code: 'switch_led', value: patch.on });
      if ('bright' in patch) c.push({ code: 'bright_value_v2', value: Math.round(10 + patch.bright * 9.9) });
    } else if (dev.type === 'switch4') {
      if ('all' in patch) dev.gangs.forEach(g => c.push({ code: g.code, value: patch.all }));
      if ('gang' in patch) c.push({ code: patch.gang[0], value: patch.gang[1] });
    } else if (dev.type === 'ac') {
      if ('on' in patch) c.push({ code: 'switch', value: patch.on });
      if ('temp' in patch) c.push({ code: 'temp_set', value: patch.temp });
      if ('mode' in patch) c.push({ code: 'mode', value: patch.mode });
    } else if (dev.type === 'curtain') {
      if ('pos' in patch) c.push({ code: 'percent_control', value: patch.pos });
    } else if (dev.type === 'plug') {
      if ('on' in patch) c.push({ code: 'switch_1', value: patch.on });
    }
    return c;
  }

  const AIX = {
    get mode() { return mode; },
    get state() { return state; },
    async init() {
      mode = await detect();
      if (mode === 'live') {
        try {
          const r = await fetch(API + '/home', { cache: 'no-store', headers: H() });
          state = await r.json();
          // keep names/icons the customer set in AIX (stored locally until accounts exist)
          const local = loadDemo();
          (state.devices || []).forEach(d => { const l = (local.devices || []).find(x => x.id === d.id); if (l && l.gangs && d.gangs) d.gangs.forEach((g, i) => { if (l.gangs[i]) { g.name = l.gangs[i].name; g.icon = l.gangs[i].icon; } }); });
        } catch (e) { mode = 'demo'; state = loadDemo(); }
      } else {
        state = loadDemo();
      }
      return state;
    },
    device(id) { return state.devices.find(d => d.id === id); },
    async set(id, patch) {
      const dev = this.device(id);
      if (!dev) return;
      applyLocal(dev, patch);
      saveDemo();
      if (mode === 'live') {
        const commands = toTuya(dev, patch);
        if (commands.length) {
          await fetch(API + '/command', { method: 'POST', headers: Object.assign({ 'content-type': 'application/json' }, H()), body: JSON.stringify({ id, commands }) });
        }
      }
    },
    async runScene(sceneId) {
      const sc = state.scenes.find(s => s.id === sceneId);
      if (!sc) return;
      if (mode === 'live' && sc.tuyaId) {
        await fetch(API + '/scene', { method: 'POST', headers: Object.assign({ 'content-type': 'application/json' }, H()), body: JSON.stringify({ id: sc.tuyaId }) });
      }
      for (const [id, patch] of sc.actions || []) await this.set(id, patch);
    },
    toggleAutomation(id) { const a = state.automations.find(x => x.id === id); if (a) { a.on = !a.on; saveDemo(); } },
    reset() { try { localStorage.removeItem(KEY); } catch (e) {} state = loadDemo(); }
  };
  window.AIX = AIX;
})();
