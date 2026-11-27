// AIX Home — UI
// Look: Apple Home. Ease: Tuya (one-tap on/off, "all off" per room, simple add).
// Lines: Akubela — every line of a wall switch is its own accessory (name, icon, room, favourite).
(function () {
  const $ = s => document.querySelector(s);
  const view = $('#view'), sheet = $('#sheet'), back = $('#sheetBack');
  let lang = 'ar';
  try { lang = localStorage.getItem('aix-lang') || 'ar'; } catch (e) {}
  let tab = 'home', roomOpen = null, sheetId = null, roomFilter = 'all';
  try { roomFilter = localStorage.getItem('aix-room') || 'all'; } catch (e) {}

  // ---------- text ----------
  const T = {
    ar: { home: 'البيت', rooms: 'الغرف', automation: 'الأتمتة', settings: 'الإعدادات',
      climate: 'التكييف', lights: 'الإضاءة', security: 'الأمان', shades: 'الستاير', scenes: 'المشاهد', favorites: 'المفضلة',
      on: 'شغّال', off: 'مقفول', open: 'مفتوحة', closed: 'مقفولة', locked: 'مقفول', unlocked: 'مفتوح', ok: 'تمام', leak: 'فيه تسريب!', motion: 'فيه حركة', noMotion: 'مفيش حركة',
      doorOpen: 'مفتوح', doorClosed: 'مقفول', items: 'جهاز', nOn: 'شغّال', allOff: 'اقفل الكل', allOn: 'شغّل الكل', nothingOn: 'كله مقفول',
      brightness: 'الإضاءة', cool: 'تبريد', heat: 'تدفئة', fan: 'مروحة', dry: 'تجفيف', auto: 'أوتو', now: 'دلوقتي', setTo: 'مظبوط على',
      turnOn: 'شغّل', turnOff: 'اقفل', battery: 'البطارية', battLow: 'البطارية ضعيفة',
      lineName: 'الاسم', lineIcon: 'الأيقونة', lineRoom: 'الأوضة', lineFav: 'في المفضلة', lineOf: 'الخط', of: 'من',
      runDone: 'المشهد اشتغل', saved: 'اتحفظ', back: 'رجوع',
      addTitle: 'إضافة جهاز', addSub: 'في النسخة دي الجهاز بيتضاف من Smart Life وبيظهر في AIX لوحده.',
      s1: 'ضيف الجهاز من Smart Life', s1d: 'على الواي فاي أو البوابة زي العادي.', s2: 'ارجع لـ AIX', s2d: 'الجهاز هيظهر خلال ثواني.',
      s3: 'لو مفتاح فيه كذا خط', s3d: 'كل خط هيظهر جهاز لوحده. اضغط عليه وسمّيه واختار أيقونته وأوضته.',
      addSoon: 'الجاية: الإضافة من جوه AIX نفسه من غير Smart Life.',
      connection: 'الاتصال', demo: 'بيت تجريبي', live: 'متوصل بتويا', demoNote: 'التطبيق شغّال ببيت تجريبي لحد ما مفاتيح تويا تتحط على السيرفر.',
      family: 'العيلة', language: 'اللغة',
      nowHome: 'دلوقتي في البيت', thingsOn: 'حاجات شغّالة', oneOn: 'حاجة واحدة شغّالة', allQuiet: 'البيت كله مقفول', allQuietSub: 'مفيش حاجة بتسحب كهربا دلوقتي', approxKw: 'حوالي', kw: 'كيلووات', w: 'وات', biggest: 'أكتر حاجة', estNote: 'الاستهلاك تقديري', houseOff: 'اقفل كل حاجة', houseOffDone: 'اتقفل', devicesWord: 'أجهزة', allRooms: 'الكل', emptyRoom: 'مفيش أجهزة في الأوضة دي لسه', emptyRoomSub: 'ضيف جهاز من Smart Life أو انقل خط مفتاح هنا من إعداداته.', offlineDemo: 'مفيش نت · البيت التجريبي شغّال عادي', offlineLive: 'مفيش نت · الأوامر هتستنى لحد ما النت يرجع', backOnline: 'النت رجع', sceneDone: 'اشتغل', changed: 'اتغيّرت', reset: 'رجّع البيت التجريبي لأوله', resetDone: 'رجع لأوله', hint: 'دوس على الأيقونة تشغّل وتقفل، ودوس على الاسم يفتح التحكم.', billTitle: 'فاتورة الشهر', billEst: 'تقدير', kwhPrice: 'سعر الكيلووات (جنيه)', hoursDay: 'ساعات التشغيل في اليوم', billNeed: 'اكتب سعر الكيلووات', billNote: 'تقدير تقريبي: الحمل الحالي × الساعات × 30 يوم. مش الفاتورة الفعلية.', egp: 'جنيه', leaveTitle: 'الخروج هيقفل', leaveGo: 'نفّذ الخروج', cancel: 'إلغاء', undo: 'تراجع', undone: 'اتراجع', leaveNone: 'مفيش حاجة شغّالة تتقفل', leaveDone: 'اتقفل',
      limitLbl: 'الحد الشهري (جنيه)', limitOk: 'في الحدود', limitWarn: 'قربت من الحد', limitOver: 'عدّيت الحد', ofLimit: 'من الحد', byAmt: 'بزيادة',
      guestsName: 'ضيوف', guestsTodo: 'اضغط للتظبيط', guestsRow: 'مشهد ضيوف', guestsSet: 'اتظبط', guestsUnset: 'لسه ما اتظبطش', guestsCfg: 'ظبّط', guestsHint: 'اختار الأجهزة اللي تشتغل لما تشغّل مشهد «ضيوف». الجهاز اللي ليه مستوى تقدر تظبطه.', guestsSave: 'احفظ المشهد', guestsPick: 'اختار جهاز واحد على الأقل', guestsSaved: 'مشهد ضيوف اتحفظ', guestsClear: 'امسح التظبيط', guestsCleared: 'اتمسح', guestsPicked: 'مختار' },
    en: { home: 'Home', rooms: 'Rooms', automation: 'Automation', settings: 'Settings',
      climate: 'Climate', lights: 'Lights', security: 'Security', shades: 'Shades', scenes: 'Scenes', favorites: 'Favourites',
      on: 'On', off: 'Off', open: 'Open', closed: 'Closed', locked: 'Locked', unlocked: 'Unlocked', ok: 'OK', leak: 'Leak detected!', motion: 'Motion', noMotion: 'No motion',
      doorOpen: 'Open', doorClosed: 'Closed', items: 'accessories', nOn: 'on', allOff: 'All off', allOn: 'All on', nothingOn: 'All off',
      brightness: 'Brightness', cool: 'Cool', heat: 'Heat', fan: 'Fan', dry: 'Dry', auto: 'Auto', now: 'Now', setTo: 'Set to',
      turnOn: 'Turn on', turnOff: 'Turn off', battery: 'Battery', battLow: 'Battery low',
      lineName: 'Name', lineIcon: 'Icon', lineRoom: 'Room', lineFav: 'Show in Favourites', lineOf: 'Line', of: 'of',
      runDone: 'Scene ran', saved: 'Saved', back: 'Back',
      addTitle: 'Add accessory', addSub: 'In this version, accessories are added in Smart Life and appear in AIX automatically.',
      s1: 'Add it in Smart Life', s1d: 'Pair over Wi-Fi or the gateway as usual.', s2: 'Come back to AIX', s2d: 'It shows up within seconds.',
      s3: 'Switches with several lines', s3d: 'Every line becomes its own accessory. Tap it to name it, pick an icon and a room.',
      addSoon: 'Next: add accessories inside AIX itself, without Smart Life.',
      connection: 'Connection', demo: 'Demo home', live: 'Connected to Tuya', demoNote: 'Running on a demo home until the Tuya keys are on the server.',
      family: 'Family', language: 'Language',
      nowHome: 'Right now', thingsOn: 'things on', oneOn: 'One thing on', allQuiet: 'Everything is off', allQuietSub: 'Nothing is drawing power right now', approxKw: 'about', kw: 'kW', w: 'W', biggest: 'Biggest', estNote: 'Estimated draw', houseOff: 'Turn everything off', houseOffDone: 'Turned off', devicesWord: 'devices', allRooms: 'All', emptyRoom: 'No accessories here yet', emptyRoomSub: 'Add one in Smart Life, or move a switch line here from its settings.', offlineDemo: 'Offline · the demo home still works', offlineLive: 'Offline · commands will wait until you are back online', backOnline: 'Back online', sceneDone: 'ran', changed: 'changed', reset: 'Reset demo home', resetDone: 'Reset done', hint: 'Tap the icon to switch on/off, tap the name for controls.', billTitle: 'Monthly bill', billEst: 'estimate', kwhPrice: 'Price per kWh (EGP)', hoursDay: 'Hours on per day', billNeed: 'Enter the kWh price', billNote: 'Rough estimate: current load x hours x 30 days. Not your actual bill.', egp: 'EGP', leaveTitle: 'Leaving will turn off', leaveGo: 'Leave now', cancel: 'Cancel', undo: 'Undo', undone: 'Undone', leaveNone: 'Nothing is on', leaveDone: 'turned off',
      limitLbl: 'Monthly limit (EGP)', limitOk: 'Within limit', limitWarn: 'Close to the limit', limitOver: 'Over the limit', ofLimit: 'of limit', byAmt: 'by',
      guestsName: 'Guests', guestsTodo: 'Tap to set up', guestsRow: 'Guests scene', guestsSet: 'Set up', guestsUnset: 'Not set up yet', guestsCfg: 'Set up', guestsHint: 'Pick the accessories that turn on when you run the Guests scene. Accessories with a level can be tuned.', guestsSave: 'Save scene', guestsPick: 'Pick at least one accessory', guestsSaved: 'Guests scene saved', guestsClear: 'Clear setup', guestsCleared: 'Cleared', guestsPicked: 'picked' }
  };
  const t = k => (T[lang] && T[lang][k]) || k;
  const N = o => (o && (o[lang] || o.en || o.ar)) || '';

  // ---------- icons (SF-Symbols-like) ----------
  const P = {
    bulb: '<path class="f" d="M12 2.5a6.5 6.5 0 0 0-3.9 11.7c.6.5.9 1.1.9 1.8v.5h6V16c0-.7.3-1.3.9-1.8A6.5 6.5 0 0 0 12 2.5z"/><path d="M9.5 19h5M10.5 21.5h3"/>',
    spot: '<path class="f" d="M8 3h8l-1.6 6.5H9.6z"/><path d="M12 12.5v3M7.5 12l-2 2.5M16.5 12l2 2.5M12 18.5v2"/>',
    strip: '<rect class="f" x="2.5" y="10" width="19" height="4.5" rx="2.2"/><path d="M6 6.5v1.5M10 5.5v2M14 5.5v2M18 6.5v1.5"/>',
    lamp: '<path class="f" d="M7.5 3h9l3 8.5h-15z"/><path d="M12 11.5v8M8 21h8"/>',
    chand: '<path d="M12 2v4"/><path class="f" d="M5 11a7 4 0 0 0 14 0z"/><path d="M6 11v3M12 11v4M18 11v3"/><circle class="f" cx="6" cy="16" r="1.4"/><circle class="f" cx="12" cy="17" r="1.4"/><circle class="f" cx="18" cy="16" r="1.4"/>',
    fan: '<circle class="f" cx="12" cy="12" r="2.2"/><path d="M12 9.8c0-4 .8-7 3.8-7 2.3 0 2.2 3.2-.3 5.1M14.2 12c4 0 7 .8 7 3.8 0 2.3-3.2 2.2-5.1-.3M12 14.2c0 4-.8 7-3.8 7-2.3 0-2.2-3.2.3-5.1M9.8 12c-4 0-7-.8-7-3.8 0-2.3 3.2-2.2 5.1.3"/>',
    star: '<path class="f" d="M12 2.8l2.7 5.6 6.1.8-4.5 4.3 1.1 6.1L12 16.7l-5.4 2.9 1.1-6.1-4.5-4.3 6.1-.8z"/>',
    ac: '<path d="M12 2.5v19M3.8 7.2l16.4 9.6M3.8 16.8l16.4-9.6M9.5 4l2.5 2.3L14.5 4M9.5 20l2.5-2.3 2.5 2.3"/>',
    curtain: '<path d="M2.5 3.5h19"/><path class="f" d="M4 3.5h6v1c0 5-1.2 10.6-6 15.5zM20 3.5h-6v1c0 5 1.2 10.6 6 15.5z"/>',
    lock: '<rect class="f" x="4.5" y="10.5" width="15" height="11" rx="3"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
    unlock: '<rect class="f" x="4.5" y="10.5" width="15" height="11" rx="3"/><path d="M8 10.5V7.5a4 4 0 0 1 7.6-1.7"/>',
    drop: '<path class="f" d="M12 2.8s6.5 7 6.5 11.7a6.5 6.5 0 0 1-13 0C5.5 9.8 12 2.8 12 2.8z"/>',
    motion: '<circle class="f" cx="13.5" cy="4" r="2.2"/><path d="M9 21.5l2.2-6.5 3 3v3.5M6.5 12.5l3.2-4.3 4.3 2.1 3.5 3.2M10.4 8.6l-1.2 5.6"/>',
    door: '<path class="f" d="M6 21.5V3.8c0-.7.5-1.3 1.2-1.3h9.6c.7 0 1.2.6 1.2 1.3v17.7z"/><path d="M3.5 21.5h17"/><circle cx="14.5" cy="12" r=".9" stroke-width="1.8"/>',
    plug: '<path d="M9 2.5v5M15 2.5v5"/><path class="f" d="M5.5 7.5h13v3.3a6.5 6.5 0 0 1-13 0z"/><path d="M12 17.3v4.2"/>',
    thermo: '<path class="f" d="M14 14.3V5a2 2 0 0 0-4 0v9.3a4.2 4.2 0 1 0 4 0z"/>',
    shield: '<path class="f" d="M12 2.5l8 3v6.2c0 5-3.4 8.6-8 9.8-4.6-1.2-8-4.8-8-9.8V5.5z"/>',
    house: '<path class="f" d="M3 11.2L12 3.5l9 7.7V20a1.5 1.5 0 0 1-1.5 1.5h-4.2v-6H9.7v6H4.5A1.5 1.5 0 0 1 3 20z"/>',
    rooms: '<rect class="f" x="3" y="3" width="8" height="8" rx="2.2"/><rect class="f" x="13" y="3" width="8" height="8" rx="2.2"/><rect class="f" x="3" y="13" width="8" height="8" rx="2.2"/><rect class="f" x="13" y="13" width="8" height="8" rx="2.2"/>',
    clock: '<circle class="f" cx="12" cy="12" r="9.5"/><path d="M12 7v5l3.2 2" stroke="#2a2522"/>',
    gear: '<circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v2.6M12 18.9v2.6M21.5 12h-2.6M5.1 12H2.5M18.7 5.3l-1.8 1.8M7.1 16.9l-1.8 1.8M18.7 18.7l-1.8-1.8M7.1 7.1L5.3 5.3"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    dots: '<circle class="f" cx="5.5" cy="12" r="1.7"/><circle class="f" cx="12" cy="12" r="1.7"/><circle class="f" cx="18.5" cy="12" r="1.7"/>',
    chev: '<path d="M9 5.5l6.5 6.5L9 18.5"/>',
    x: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    power: '<path d="M12 3v8.5"/><path d="M6.6 6.6a7.5 7.5 0 1 0 10.8 0"/>',
    sun: '<circle class="f" cx="12" cy="12" r="4.2"/><path d="M12 1.8v2.4M12 19.8v2.4M1.8 12h2.4M19.8 12h2.4M4.8 4.8l1.7 1.7M17.5 17.5l1.7 1.7M4.8 19.2l1.7-1.7M17.5 6.5l1.7-1.7"/>',
    moon: '<path class="f" d="M20.5 14.6A8.5 8.5 0 1 1 9.4 3.5a7 7 0 0 0 11.1 11.1z"/>',
    film: '<rect class="f" x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M7.5 5v14M16.5 5v14M2.5 9.5h5M2.5 14.5h5M16.5 9.5h5M16.5 14.5h5" stroke="#2a2522" stroke-width="1.4"/>',
    leave: '<path d="M14 3.5h4.5A1.5 1.5 0 0 1 20 5v14a1.5 1.5 0 0 1-1.5 1.5H14M10 8l-4 4 4 4M6 12h10.5"/>',
    sofa: '<path class="f" d="M5 10.5V8a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v2.5z"/><path class="f" d="M2.5 12.5a2 2 0 0 1 4 0V15h11v-2.5a2 2 0 0 1 4 0V18h-19z"/><path d="M4.5 18v2M19.5 18v2"/>',
    bed: '<path d="M3 19V6.5M3 13.5h18V19M21 19v-4"/><path class="f" d="M3 13.5V11h18a0 0 0 0 1 0 0v2.5zM10 11V9.5a1.5 1.5 0 0 1 1.5-1.5h6A3.5 3.5 0 0 1 21 11.5"/><circle class="f" cx="6.5" cy="10" r="1.6"/>',
    pot: '<path class="f" d="M4 10h16v3a6.5 6.5 0 0 1-6.5 6.5h-3A6.5 6.5 0 0 1 4 13z"/><path d="M2 10h2M20 10h2M9 6.5c0-1 1-1 1-2.5M14 6.5c0-1 1-1 1-2.5"/>',
    tree: '<path class="f" d="M12 2.5l5 7h-2.5l3.5 5.5H6l3.5-5.5H7z"/><path d="M12 15v6.5"/>',
    kid: '<circle class="f" cx="12" cy="6.5" r="3.5"/><path class="f" d="M5.5 21.5v-2.5a6.5 6.5 0 0 1 13 0v2.5z"/>'
  };
  const ic = n => `<svg viewBox="0 0 24 24" aria-hidden="true">${P[n] || P.bulb}</svg>`;
  const LINE_ICONS = ['bulb', 'spot', 'chand', 'strip', 'lamp', 'star', 'fan', 'plug', 'ac', 'curtain', 'door', 'tree'];
  const roomIcon = id => ({ living: 'sofa', kitchen: 'pot', entrance: 'door', master: 'bed', kids: 'kid', garden: 'tree' }[id] || 'house');

  // ---------- accessories: real devices + every switch line as its own accessory ----------
  const S = () => AIX.state;
  function accessories() {
    const out = [];
    S().devices.forEach(d => {
      if (d.type === 'switch4') {
        d.gangs.forEach((g, i) => out.push({ id: d.id + '~' + g.code, kind: 'line', parent: d.id, code: g.code, index: i + 1, count: d.gangs.length,
          room: g.room || d.room, name: g.name, icon: g.icon, on: g.on, fav: !!g.fav, switchName: d.name }));
      } else out.push(Object.assign({ kind: d.type }, d));
    });
    return out;
  }
  const acc = id => accessories().find(a => a.id === id);
  const roomName = id => N((S().rooms.find(r => r.id === id) || {}).name);
  const iconOf = a => a.kind === 'line' ? a.icon : ({ light: 'bulb', ac: 'ac', curtain: 'curtain', lock: a.locked === false ? 'unlock' : 'lock', leak: 'drop', motion: 'motion', contact: 'door', plug: 'plug' }[a.kind] || 'bulb');
  const isOn = a => a.kind === 'curtain' ? a.pos > 0 : a.kind === 'lock' ? false : !!a.on;
  const isAlarm = a => (a.kind === 'leak' && a.alarm) || (a.kind === 'motion' && a.motion) || (a.kind === 'contact' && a.open);
  const canToggle = a => ['light', 'line', 'ac', 'plug', 'curtain'].includes(a.kind);
  const colorKind = a => a.kind === 'line' ? (['fan'].includes(a.icon) ? 'fan' : a.icon === 'plug' ? 'plug' : 'line') : a.kind;
  function status(a) {
    switch (a.kind) {
      case 'light': return a.on ? `${a.bright}%` : t('off');
      case 'line': return a.on ? t('on') : t('off');
      case 'ac': return a.on ? `${t(a.mode)} · ${a.temp}°` : `${t('off')} · ${a.current}°`;
      case 'curtain': return a.pos === 0 ? t('closed') : a.pos === 100 ? t('open') : `${a.pos}%`;
      case 'lock': return a.locked ? t('locked') : t('unlocked');
      case 'leak': return a.alarm ? t('leak') : t('ok');
      case 'motion': return a.motion ? t('motion') : t('noMotion');
      case 'contact': return a.open ? t('doorOpen') : t('doorClosed');
      case 'plug': return a.on ? `${a.power} W` : t('off');
    }
    return '';
  }

  // Rough draw per accessory (watts) until real power data comes from Tuya.
  function watts(a) {
    if (!isOn(a)) return 0;
    if (a.kind === 'ac') return 1400;              // 1.5 HP split, compressor running
    if (a.kind === 'plug') return a.power || 0;
    if (a.kind === 'light') return Math.round(45 * (a.bright || 100) / 100);
    if (a.kind === 'line') return a.icon === 'fan' ? 70 : 18;
    return 0;
  }
  const switchable = a => ['light', 'line', 'ac', 'plug'].includes(a.kind);
  const loadW = () => accessories().filter(a => switchable(a) && isOn(a)).reduce((s, a) => s + watts(a), 0);
  // Monthly bill estimate. The kWh price is typed by the user (no tariff guessed); hours/day is also theirs.
  function rd(k, def) { try { const v = localStorage.getItem(k); return v === null ? def : v; } catch (e) { return def; } }
  const num = v => { const n = parseFloat(String(v).replace(/[\u0660-\u0669]/g, c => c.charCodeAt(0) - 1632).replace(',', '.')); return isFinite(n) && n >= 0 ? n : NaN; };
  function billVal() {
    const price = num(rd('aix-kwh', '')), hours = Math.min(24, num(rd('aix-hours', '8')));
    if (isNaN(price) || isNaN(hours)) return NaN;
    return Math.round(loadW() / 1000 * hours * 30 * price);
  }
  function billText() {
    if (isNaN(num(rd('aix-kwh', '')))) return t('billNeed');
    const v = billVal();
    return isNaN(v) ? '–' : `${v.toLocaleString('en-US')} ${t('egp')}`;
  }
  // Monthly limit is typed by the user too. No limit or no price = no colouring, no guessing.
  function billState() {
    const est = billVal(), lim = num(rd('aix-limit', ''));
    if (isNaN(est) || isNaN(lim) || lim <= 0) return { lvl: '', text: '' };
    const pct = Math.floor(est / lim * 100);
    if (est > lim) return { lvl: 'over', text: `${t('limitOver')} · ${t('byAmt')} ${(est - lim).toLocaleString('en-US')} ${t('egp')}` };
    if (pct >= 80) return { lvl: 'warn', text: `${t('limitWarn')} · ${pct}% ${t('ofLimit')}` };
    return { lvl: 'ok', text: `${t('limitOk')} · ${pct}% ${t('ofLimit')}` };
  }
  function applyBill() {
    const o = $('#billOut'); if (o) { o.textContent = billText(); o.classList.toggle('need', isNaN(num(rd('aix-kwh', '')))); }
    const c = $('#billCard'), st = billState();
    if (c) { c.classList.remove('ok', 'warn', 'over'); if (st.lvl) c.classList.add(st.lvl); }
    const l = $('#billS'); if (l) { l.textContent = st.text; l.hidden = !st.text; }
  }
  const billCard = () => { const st = billState(); return `<section class="bill glass ${st.lvl}" id="billCard"><div class="bill-h"><div><small>${t('billTitle')} · ${t('billEst')}</small><b id="billOut" class="${isNaN(num(rd('aix-kwh', ''))) ? 'need' : ''}">${billText()}</b></div></div>
    <p class="bill-s" id="billS" ${st.text ? '' : 'hidden'}>${st.text}</p>
    <div class="bill-f"><label>${t('kwhPrice')}<input class="field" data-bill="aix-kwh" inputmode="decimal" autocomplete="off" value="${rd('aix-kwh', '')}"></label>
    <label>${t('hoursDay')}<input class="field" data-bill="aix-hours" inputmode="decimal" autocomplete="off" value="${rd('aix-hours', '8')}"></label>
    <label class="wide">${t('limitLbl')}<input class="field" data-bill="aix-limit" inputmode="decimal" autocomplete="off" value="${rd('aix-limit', '')}"></label></div>
    <p class="hw">${t('billNote')}</p></section>`; };
  function nowCard() {
    const on = accessories().filter(a => switchable(a) && isOn(a));
    const total = on.reduce((s, a) => s + watts(a), 0);
    if (!on.length) return `<section class="now glass quiet"><span class="now-dot"></span><div class="now-txt"><small>${t('nowHome')}</small><b>${t('allQuiet')}</b><span>${t('allQuietSub')}</span></div></section>`;
    const top = on.slice().sort((x, y) => watts(y) - watts(x))[0];
    const load = total >= 1000 ? `${(total / 1000).toFixed(1)} ${t('kw')}` : `${total} ${t('w')}`;
    const pct = Math.min(100, Math.round(total / 40));  // 4 kW = full bar
    return `<section class="now glass"><div class="now-txt"><small>${t('nowHome')}</small>
      <b><span class="num">${on.length}</span> ${on.length === 1 ? t('oneOn') : t('thingsOn')}</b>
      <span>${t('approxKw')} <em>${load}</em> · ${t('biggest')}: ${N(top.name)}</span>
      <i class="meter" aria-label="${t('estNote')}"><i style="width:${pct}%"></i></i></div>
      <button class="now-off" data-houseoff>${ic('power')}<span>${t('houseOff')}</span></button></section>`;
  }
  function roomBar() {
    const rooms = S().rooms.filter(r => accessories().some(a => a.room === r.id));
    const btn = (id, label) => `<button class="${roomFilter === id ? 'sel' : ''}" data-rf="${id}">${label}</button>`;
    return `<div class="rf" role="tablist">${btn('all', t('allRooms'))}${rooms.map(r => btn(r.id, N(r.name))).join('')}</div>`;
  }
  const emptyState = () => `<div class="empty glass"><span class="eg">${ic('plus')}</span><b>${t('emptyRoom')}</b><span>${t('emptyRoomSub')}</span><button class="pill glass" data-add>${t('addTitle')}</button></div>`;

  // ---------- leave scene: preview what closes, then undo for 5s ----------
  function leaveList(sc) {
    const ids = new Set();
    (sc.actions || []).forEach(([id, p]) => { if (p.on === false || p.all === false) ids.add(id); });
    return accessories().filter(a => switchable(a) && isOn(a) && ids.has(a.parent || a.id));
  }
  function leaveSheet(sc) {
    const list = leaveList(sc);
    return `<div class="grabber"></div><div class="sh-head"><span class="ig">${ic('leave')}</span><div><b>${t('leaveTitle')}</b><span>${list.length} ${t('devicesWord')}</span></div><button class="x" data-close aria-label="close">${ic('x')}</button></div>
      <div class="list glass" style="margin-top:12px">${list.map(a => `<div class="row"><span class="rg" style="background:rgba(255,255,255,.16)">${ic(iconOf(a))}</span><div class="grow"><b>${N(a.name)}</b><span>${roomName(a.room)}</span></div></div>`).join('')}</div>
      <button class="cta on" data-leavego="${sc.id}">${t('leaveGo')}</button><button class="cta" data-close>${t('cancel')}</button>`;
  }
  let undoSnap = null, undoT;
  function hideUndo() { clearTimeout(undoT); undoSnap = null; const u = $('#undo'); if (u) u.hidden = true; }
  function showUndo(msg, snap) {
    let u = $('#undo');
    if (!u) { u = document.createElement('div'); u.id = 'undo'; u.className = 'toast undo'; u.setAttribute('role', 'status'); document.body.appendChild(u); }
    undoSnap = snap; u.hidden = false;
    u.innerHTML = `<span></span><button data-undo>${t('undo')}</button>`; u.firstChild.textContent = msg;
    clearTimeout(undoT); undoT = setTimeout(hideUndo, 5000);
  }
  async function restore(snap) {
    for (const prev of snap) {
      const d = AIX.device(prev.id); if (!d) continue;
      if (prev.type === 'switch4') { for (const g of prev.gangs) await AIX.set(d.id, { gang: [g.code, g.on] }); }
      else { const p = {}; ['on', 'bright', 'temp', 'mode', 'pos'].forEach(k => { if (k in prev) p[k] = prev[k]; }); await AIX.set(d.id, p); }
    }
  }
  async function runLeave(sid) {
    const sc = S().scenes.find(x => x.id === sid), list = leaveList(sc);
    const touched = new Set(list.map(a => a.parent || a.id));
    const snap = JSON.parse(JSON.stringify(S().devices.filter(d => touched.has(d.id))));
    await AIX.runScene(sid);
    return { snap, n: list.length };
  }

  // ---------- guests scene: user picks devices (and level where a device has one), saved in this browser ----------
  const GKEY = 'aix-guests';
  const GLV = { light: { min: 10, max: 100, step: 5, key: 'bright', fmt: v => v + '%' }, ac: { min: 16, max: 30, step: 1, key: 'temp', fmt: v => v + '°' }, curtain: { min: 0, max: 100, step: 10, key: 'pos', fmt: v => v + '%' } };
  function guestsLoad() {
    try { const j = JSON.parse(localStorage.getItem(GKEY) || 'null'); if (j && Array.isArray(j.items) && j.items.length) return j.items; } catch (e) {}
    return null;
  }
  function guestsSave(items) { try { if (items) localStorage.setItem(GKEY, JSON.stringify({ v: 1, items })); else localStorage.removeItem(GKEY); } catch (e) {} }
  const guestable = a => ['light', 'line', 'ac', 'plug', 'curtain'].includes(a.kind);
  const sceneList = () => S().scenes.concat([{ id: 'guests', icon: 'sofa', name: { ar: T.ar.guestsName, en: T.en.guestsName }, custom: true }]);
  const gLevel = (a, c) => Math.max(c.min, Math.min(c.max, a[c.key] != null ? a[c.key] : c.max));
  function guestPatch(a, lv) {
    if (a.kind === 'line') return [a.parent, { gang: [a.code, true] }];
    if (a.kind === 'light') return [a.id, { on: true, bright: lv != null ? lv : (a.bright || 100) }];
    if (a.kind === 'ac') return [a.id, { on: true, temp: lv != null ? lv : a.temp }];
    if (a.kind === 'curtain') return [a.id, { pos: lv != null ? lv : 100 }];
    return [a.id, { on: true }];
  }
  async function runGuests() {
    for (const it of guestsLoad() || []) { const a = acc(it.id); if (a) { const [id, p] = guestPatch(a, it.lv); await AIX.set(id, p); } }
  }
  let gDraft = null;
  function guestsOpen() {
    const cur = guestsLoad() || [];
    gDraft = { sel: new Set(cur.map(i => i.id)), lv: {} };
    cur.forEach(i => { if (i.lv != null) gDraft.lv[i.id] = i.lv; });
    openSheet('__guests');
  }
  function guestsSheet() {
    const all = accessories().filter(guestable);
    const rooms = S().rooms.filter(r => all.some(a => a.room === r.id));
    const row = a => {
      const on = gDraft.sel.has(a.id), cfg = GLV[a.kind];
      let lvl = '';
      if (on && cfg) {
        const v = gDraft.lv[a.id] != null ? gDraft.lv[a.id] : gLevel(a, cfg);
        lvl = `<div class="g-lv"><input type="range" dir="ltr" min="${cfg.min}" max="${cfg.max}" step="${cfg.step}" value="${v}" data-glevel="${a.id}" aria-label="${N(a.name)}"><b class="g-v">${cfg.fmt(v)}</b></div>`;
      }
      return `<div class="g-item"><div class="row"><span class="rg" style="background:rgba(255,255,255,.16)">${ic(iconOf(a))}</span><div class="grow"><b>${N(a.name)}</b></div><button class="sw ${on ? 'on' : ''}" data-gsel="${a.id}" role="switch" aria-checked="${on}" aria-label="${N(a.name)}"></button></div>${lvl}</div>`;
    };
    return `<div class="grabber"></div><div class="sh-head"><span class="ig">${ic('sofa')}</span><div><b>${t('guestsRow')}</b><span id="gCount">${gDraft.sel.size} ${t('guestsPicked')}</span></div><button class="x" data-close aria-label="close">${ic('x')}</button></div>
      <p class="hw" style="margin-top:4px">${t('guestsHint')}</p>
      ${rooms.map(r => `<div class="grp"><h3>${N(r.name)}</h3><div class="list glass">${all.filter(a => a.room === r.id).map(row).join('')}</div></div>`).join('')}
      <button class="cta on" data-gsave>${t('guestsSave')}</button>${guestsLoad() ? `<button class="cta" data-gclear>${t('guestsClear')}</button>` : ''}`;
  }
  function guestsRefresh() { const y = sheet.scrollTop; sheet.innerHTML = guestsSheet(); sheet.scrollTop = y; }

  // ---------- writing ----------
  async function setAcc(a, patch) {
    if (a.kind === 'line') {
      if ('on' in patch) await AIX.set(a.parent, { gang: [a.code, patch.on] });
      const meta = {};
      ['name', 'icon', 'room', 'fav'].forEach(k => { if (k in patch) meta[k] = patch[k]; });
      if (Object.keys(meta).length) await AIX.set(a.parent, { gangMeta: [a.code, meta] });
    } else await AIX.set(a.id, patch);
  }
  async function toggle(a) {
    if (a.kind === 'curtain') return setAcc(a, { pos: a.pos > 0 ? 0 : 100 });
    return setAcc(a, { on: !a.on });
  }

  // ---------- pieces ----------
  function tile(a, showRoom) {
    const cls = ['tile', 'glass', 'k-' + colorKind(a)];
    if (isAlarm(a)) cls.push('alarm'); else if (isOn(a)) cls.push('on');
    const iconBtn = canToggle(a)
      ? `<button class="ig" data-toggle="${a.id}" aria-label="${t(isOn(a) ? 'turnOff' : 'turnOn')} ${N(a.name)}">${ic(iconOf(a))}</button>`
      : `<span class="ig">${ic(iconOf(a))}</span>`;
    return `<div class="${cls.join(' ')}">${iconBtn}
      <button class="lb" data-open="${a.id}"><span class="nm">${N(a.name)}</span>${showRoom ? `<span class="rm">${roomName(a.room)}</span>` : ''}<span class="st">${status(a)}</span></button></div>`;
  }
  const grid = (list, showRoom) => `<div class="grid">${list.map(a => tile(a, showRoom)).join('')}</div>`;
  function chips() {
    const all = accessories();
    const acs = all.filter(a => a.kind === 'ac');
    const avg = acs.length ? Math.round(acs.reduce((s, a) => s + a.current, 0) / acs.length) : '–';
    const lights = all.filter(a => a.kind === 'light' || a.kind === 'line'), lOn = lights.filter(isOn).length;
    const shades = all.filter(a => a.kind === 'curtain'), sOpen = shades.filter(isOn).length;
    const alarms = all.filter(isAlarm).length, lock = all.find(a => a.kind === 'lock');
    return `<div class="chips">
      <div class="chip glass c-climate"><span class="cg">${ic('thermo')}</span><div><b>${t('climate')}</b><span>${avg}°</span></div></div>
      <div class="chip glass c-light"><span class="cg">${ic('bulb')}</span><div><b>${t('lights')}</b><span>${lOn ? lOn + ' ' + t('nOn') : t('nothingOn')}</span></div></div>
      <div class="chip glass c-sec ${alarms ? 'alert' : ''}"><span class="cg">${ic('shield')}</span><div><b>${t('security')}</b><span>${alarms ? '⚠ ' + alarms : (lock && lock.locked ? t('locked') : t('ok'))}</span></div></div>
      <div class="chip glass c-shade"><span class="cg">${ic('curtain')}</span><div><b>${t('shades')}</b><span>${sOpen} ${t('open')}</span></div></div>
    </div>`;
  }
  const scenes = () => `<div class="scenes">${sceneList().map(s => `<button class="scene glass" data-scene="${s.id}"><span class="sg">${ic(s.icon === 'out' ? 'leave' : s.icon === 'home' ? 'house' : s.icon)}</span><span class="sn"><b>${N(s.name)}</b>${s.custom && !guestsLoad() ? `<small>${t('guestsTodo')}</small>` : ''}</span></button>`).join('')}</div>`;
  const secH = (title, roomId) => `<div class="sec-h"><h2>${title}</h2>${roomId ? `<button class="pill glass" data-alloff="${roomId}">${t('allOff')}</button>` : ''}</div>`;

  // ---------- views ----------
  function vHome() {
    const all = accessories();
    if (roomFilter !== 'all' && !S().rooms.some(r => r.id === roomFilter)) roomFilter = 'all';
    let html = nowCard() + billCard() + chips() + secH(t('scenes')) + scenes() + roomBar();
    if (roomFilter === 'all') {
      const favs = all.filter(a => a.fav);
      if (favs.length) html += secH(t('favorites')) + grid(favs, true);
      S().rooms.forEach(r => { const list = all.filter(a => a.room === r.id); if (list.length) html += secH(N(r.name), r.id) + grid(list, false); });
    } else {
      const r = S().rooms.find(x => x.id === roomFilter), list = all.filter(a => a.room === roomFilter);
      html += secH(N(r.name), list.length ? r.id : null) + (list.length ? grid(list, false) : emptyState());
    }
    return html;
  }
  function vRooms() {
    const all = accessories();
    if (roomOpen) {
      const r = S().rooms.find(x => x.id === roomOpen), list = all.filter(a => a.room === roomOpen);
      return `<button class="back" data-roomback>${ic('chev')} ${t('rooms')}</button>${secH(N(r.name), list.length ? r.id : null)}${list.length ? grid(list, false) : emptyState()}`;
    }
    return `<div class="rooms" style="margin-top:14px">${S().rooms.map(r => {
      const list = all.filter(a => a.room === r.id), on = list.filter(isOn).length;
      return `<button class="room-card glass" data-room="${r.id}"><span class="rg">${ic(roomIcon(r.id))}</span><div><b>${N(r.name)}</b><span>${list.length} ${t('items')}${on ? ' · ' + on + ' ' + t('nOn') : ''}</span></div></button>`;
    }).join('')}</div>`;
  }
  function vAutomation() {
    return secH(t('scenes')) + scenes() + secH(t('automation')) +
      `<div class="list glass">${S().automations.map(a => `<div class="row"><span class="rg">${ic('clock')}</span><div class="grow"><b>${N(a.name)}</b><span>${N(a.desc)}</span></div><button class="sw ${a.on ? 'on' : ''}" data-auto="${a.id}" aria-label="${N(a.name)}"></button></div>`).join('')}</div>`;
  }
  function vSettings() {
    const live = AIX.mode === 'live';
    return secH(t('connection')) + `<div class="list glass"><div class="row"><div class="grow"><b>${live ? t('live') : t('demo')}</b><span>${live ? 'Tuya Cloud' : t('demoNote')}</span></div></div></div>` +
      secH(t('family')) + `<div class="list glass">${S().members.map(m => `<div class="row"><span class="rg" style="background:#8e8e93">${ic('kid')}</span><div class="grow"><b>${m.name}</b><span>${N(m.role)}</span></div></div>`).join('')}</div>` +
      secH(t('guestsRow')) + `<div class="list glass"><div class="row"><span class="rg">${ic('sofa')}</span><div class="grow"><b>${t('guestsName')}</b><span>${guestsLoad() ? t('guestsSet') + ' · ' + guestsLoad().length + ' ' + t('devicesWord') : t('guestsUnset')}</span></div><button class="pill glass" data-gopen>${t('guestsCfg')}</button></div></div>` +
      secH(t('language')) + `<div class="seg"><button data-lang="ar" class="${lang === 'ar' ? 'sel' : ''}">العربية</button><button data-lang="en" class="${lang === 'en' ? 'sel' : ''}">English</button></div>` +
      (live ? '' : `<button class="cta" data-reset>${t('reset')}</button>`) + `<p class="hw">${t('hint')}</p>`;
  }
  function addSheet() {
    return `<div class="grabber"></div><div class="sh-head"><span class="ig">${ic('plus')}</span><div><b>${t('addTitle')}</b></div><button class="x" data-close aria-label="close">${ic('x')}</button></div>
      <p class="hw" style="margin-top:4px">${t('addSub')}</p>
      <div class="steps" style="margin-top:12px">
        <div class="step glass"><div><b>${t('s1')}</b><span>${t('s1d')}</span></div></div>
        <div class="step glass"><div><b>${t('s2')}</b><span>${t('s2d')}</span></div></div>
        <div class="step glass"><div><b>${t('s3')}</b><span>${t('s3d')}</span></div></div>
      </div><div class="note glass">${t('addSoon')}</div>`;
  }

  // ---------- controls sheet ----------
  function vslider(field, val, icon) {
    return `<div class="vs-wrap"><div class="vs-val" id="vsv">${val}%</div>
      <div class="vs" data-vs="${field}" role="slider" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${val}" tabindex="0"><div class="fill" style="height:${val}%"></div><span class="vs-ic">${ic(icon)}</span></div></div>`;
  }
  function sheetHtml(a) {
    let body = '';
    if (a.kind === 'light') {
      body = vslider('bright', a.on ? a.bright : 0, 'bulb') + `<button class="cta ${a.on ? 'on' : ''}" data-pw>${a.on ? t('turnOff') : t('turnOn')}</button>`;
    } else if (a.kind === 'curtain') {
      body = vslider('pos', a.pos, 'curtain') + `<div class="seg"><button data-setv='{"pos":100}'>${t('open')}</button><button data-setv='{"pos":50}'>50%</button><button data-setv='{"pos":0}'>${t('closed')}</button></div>`;
    } else if (a.kind === 'ac') {
      body = `<div class="temp"><button class="round" data-temp="-1" aria-label="-">−</button><div class="tv">${a.temp}<small>°</small></div><button class="round" data-temp="1" aria-label="+">+</button></div>
        <p class="big-state">${t('now')} ${a.current}° · ${a.on ? t('setTo') + ' ' + a.temp + '°' : t('off')}</p>
        <div class="seg">${['cool', 'heat', 'fan', 'dry', 'auto'].map(m => `<button data-mode="${m}" class="${a.mode === m ? 'sel' : ''}">${t(m)}</button>`).join('')}</div>
        <button class="cta ${a.on ? 'on' : ''}" data-pw>${a.on ? t('turnOff') : t('turnOn')}</button>`;
    } else if (a.kind === 'line' || a.kind === 'plug') {
      body = `<button class="power-pill ${a.on ? 'on' : ''} k-${colorKind(a)}" data-pw aria-label="${t(a.on ? 'turnOff' : 'turnOn')}">${ic(a.kind === 'plug' ? 'plug' : a.icon)}</button><p class="big-state">${status(a)}</p>`;
      if (a.kind === 'line') {
        body += `<div class="grp"><h3>${t('lineName')}</h3><input class="field" id="ln-${a.id}" data-lname value="${N(a.name).replace(/"/g, '&quot;')}"></div>
          <div class="grp"><h3>${t('lineIcon')}</h3><div class="icons">${LINE_ICONS.map(n => `<button class="${a.icon === n ? 'sel' : ''}" data-licon="${n}" aria-label="${n}">${ic(n)}</button>`).join('')}</div></div>
          <div class="grp"><h3>${t('lineRoom')}</h3><div class="room-chips">${S().rooms.map(r => `<button class="${a.room === r.id ? 'sel' : ''}" data-lroom="${r.id}">${N(r.name)}</button>`).join('')}</div></div>
          <div class="grp"><div class="list glass"><div class="row"><div class="grow"><b>${t('lineFav')}</b></div><button class="sw ${a.fav ? 'on' : ''}" data-lfav aria-label="${t('lineFav')}"></button></div></div></div>
          <p class="hw">${N(a.switchName)} · ${t('lineOf')} ${a.index} ${t('of')} ${a.count} · ${a.code}</p>`;
      }
    } else {
      body = `<div class="power-pill">${ic(iconOf(a))}</div><p class="big-state">${status(a)}${a.battery != null ? ` · ${t('battery')} ${a.battery}%${a.battery < 20 ? ' · ' + t('battLow') : ''}` : ''}</p>`;
    }
    const lit = isOn(a) && ['light', 'line'].includes(a.kind);
    return `<div class="grabber"></div><div class="sh-head"><span class="ig ${lit ? 'lit' : ''}">${ic(iconOf(a))}</span><div><b>${N(a.name)}</b><span>${roomName(a.room)}</span></div><button class="x" data-close aria-label="close">${ic('x')}</button></div>${body}`;
  }
  function openSheet(id) { sheetId = id; sheet.innerHTML = id === '__add' ? addSheet() : id === '__guests' ? guestsSheet() : id.startsWith('__leave:') ? leaveSheet(S().scenes.find(x => x.id === id.slice(8))) : sheetHtml(acc(id)); sheet.hidden = false; back.hidden = false; }
  function closeSheet() { sheet.hidden = true; back.hidden = true; sheetId = null; render(); }
  function refreshSheet() { if (sheetId && !sheetId.startsWith('__')) { const a = acc(sheetId); if (!a) return closeSheet(); const y = sheet.scrollTop; sheet.innerHTML = sheetHtml(a); sheet.scrollTop = y; } }

  // vertical slider drag
  let drag = null;
  function vsValue(el, clientY) { const r = el.getBoundingClientRect(); return Math.max(0, Math.min(100, Math.round((r.bottom - clientY) / r.height * 100))); }
  sheet.addEventListener('pointerdown', e => { const vs = e.target.closest('[data-vs]'); if (!vs) return; drag = vs; vs.setPointerCapture(e.pointerId); move(e); });
  sheet.addEventListener('pointermove', e => { if (drag) move(e); });
  sheet.addEventListener('pointerup', async e => { if (!drag) return; const v = vsValue(drag, e.clientY), f = drag.dataset.vs; drag = null; const a = acc(sheetId); await setAcc(a, f === 'bright' ? (v === 0 ? { on: false } : { on: true, bright: v }) : { pos: v }); refreshSheet(); });
  function move(e) { const v = vsValue(drag, e.clientY); drag.querySelector('.fill').style.height = v + '%'; const o = $('#vsv'); if (o) o.textContent = v + '%'; }
  sheet.addEventListener('keydown', async e => {
    const vs = e.target.closest('[data-vs]'); if (!vs || !['ArrowUp', 'ArrowDown'].includes(e.key)) return;
    e.preventDefault(); const a = acc(sheetId), f = vs.dataset.vs, cur = f === 'bright' ? (a.on ? a.bright : 0) : a.pos;
    const v = Math.max(0, Math.min(100, cur + (e.key === 'ArrowUp' ? 10 : -10)));
    await setAcc(a, f === 'bright' ? (v === 0 ? { on: false } : { on: true, bright: v }) : { pos: v }); refreshSheet(); sheet.querySelector('[data-vs]').focus();
  });

  // ---------- chrome ----------
  function header() {
    const live = AIX.mode === 'live';
    const title = tab === 'home' ? N(S().home.name) : tab === 'rooms' ? t('rooms') : tab === 'automation' ? t('automation') : t('settings');
    $('#top').innerHTML = `<span class="badge glass ${live ? 'live' : ''}">${live ? 'LIVE' : 'DEMO'}</span>
      <div class="top-actions"><button class="circle glass" data-langtoggle aria-label="language" style="font:600 13px var(--fe)">${lang === 'ar' ? 'EN' : 'ع'}</button><button class="circle glass" data-add aria-label="${t('addTitle')}">${ic('plus')}</button></div>`;
    const off = navigator.onLine === false ? `<div class="offline" role="status"><span></span>${t(live ? 'offlineLive' : 'offlineDemo')}</div>` : '';
    return `${off}<div class="title"><h1>${title}</h1>${tab === 'home' ? '<span class="brandmark">AIX</span>' : ''}</div>`;
  }
  function tabs() {
    const items = [['home', 'house'], ['rooms', 'rooms'], ['automation', 'clock'], ['settings', 'gear']];
    $('#tabs').innerHTML = items.map(([k, i]) => `<button class="tab ${tab === k ? 'active' : ''}" data-tab="${k}">${ic(i)}<span>${t(k)}</span></button>`).join('');
  }
  function render() {
    document.documentElement.lang = lang; document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    const h = header();
    view.innerHTML = h + { home: vHome, rooms: vRooms, automation: vAutomation, settings: vSettings }[tab]();
    tabs();
  }
  let toastT;
  function toast(m) { const el = $('#toast'); el.textContent = m; el.hidden = false; clearTimeout(toastT); toastT = setTimeout(() => el.hidden = true, 1500); }
  function setLang(l) { lang = l; try { localStorage.setItem('aix-lang', l); } catch (e) {} render(); refreshSheet(); }

  // ---------- events ----------
  document.addEventListener('click', async e => {
    const el = e.target.closest('[data-gopen],[data-gsel],[data-gsave],[data-gclear],[data-undo],[data-leavego],[data-houseoff],[data-rf],[data-toggle],[data-open],[data-scene],[data-alloff],[data-tab],[data-room],[data-roomback],[data-auto],[data-lang],[data-langtoggle],[data-reset],[data-add],[data-close],[data-pw],[data-setv],[data-temp],[data-mode],[data-licon],[data-lroom],[data-lfav]');
    if (!el) return;
    const d = el.dataset;
    if ('gopen' in d) { guestsOpen(); return; }
    if ('gsel' in d) { if (gDraft.sel.has(d.gsel)) gDraft.sel.delete(d.gsel); else gDraft.sel.add(d.gsel); guestsRefresh(); return; }
    if ('gsave' in d) {
      const items = accessories().filter(a => gDraft.sel.has(a.id)).map(a => { const it = { id: a.id }, c = GLV[a.kind]; if (c) it.lv = gDraft.lv[a.id] != null ? gDraft.lv[a.id] : gLevel(a, c); return it; });
      if (!items.length) { toast(t('guestsPick')); return; }
      guestsSave(items); closeSheet(); toast(t('guestsSaved')); return;
    }
    if ('gclear' in d) { guestsSave(null); closeSheet(); toast(t('guestsCleared')); return; }
    if ('undo' in d) { const s = undoSnap; hideUndo(); if (s) { await restore(s); render(); toast(t('undone')); } return; }
    if ('leavego' in d) { closeSheet(); const r = await runLeave(d.leavego); render(); if (r.n) showUndo(`${r.n} ${t('devicesWord')} ${t('leaveDone')}`, r.snap); return; }
    if ('houseoff' in d) { const list = accessories().filter(a => switchable(a) && isOn(a)); for (const a of list) await setAcc(a, { on: false }); render(); toast(`${t('houseOffDone')} ${list.length} ${t('devicesWord')}`); return; }
    if ('rf' in d) { roomFilter = d.rf; try { localStorage.setItem('aix-room', roomFilter); } catch (e) {} render(); const b = document.querySelector(`[data-rf="${d.rf}"]`); if (b && b.scrollIntoView) b.scrollIntoView({ block: 'nearest', inline: 'center' }); return; }
    if ('toggle' in d) { await toggle(acc(d.toggle)); render(); return; }
    if ('open' in d) { openSheet(d.open); return; }
    if ('scene' in d) {
      const sc0 = sceneList().find(x => x.id === d.scene);
      if (sc0 && sc0.custom && !guestsLoad()) { guestsOpen(); return; }
      if (sc0 && sc0.icon === 'out') { if (leaveList(sc0).length) openSheet('__leave:' + sc0.id); else toast(t('leaveNone')); return; } const before = JSON.stringify(S().devices); await (sc0 && sc0.custom ? runGuests() : AIX.runScene(d.scene)); const after = S().devices, prev = JSON.parse(before); const n = after.filter((x, i) => JSON.stringify(x) !== JSON.stringify(prev[i])).length; render(); const b = document.querySelector(`[data-scene="${d.scene}"]`); if (b) { b.classList.add('ran'); setTimeout(() => b.classList.remove('ran'), 1200); } const sc = sceneList().find(x => x.id === d.scene); toast(`${N(sc.name)} ${t('sceneDone')}${n ? ' · ' + n + ' ' + t('devicesWord') + ' ' + t('changed') : ''}`); return; }
    if ('alloff' in d) { for (const a of accessories().filter(x => x.room === d.alloff && canToggle(x) && isOn(x))) await (a.kind === 'curtain' ? setAcc(a, { pos: 0 }) : setAcc(a, { on: false })); render(); return; }
    if ('tab' in d) { tab = d.tab; roomOpen = null; render(); window.scrollTo(0, 0); return; }
    if ('room' in d) { roomOpen = d.room; render(); window.scrollTo(0, 0); return; }
    if ('roomback' in d) { roomOpen = null; render(); return; }
    if ('auto' in d) { AIX.toggleAutomation(d.auto); render(); return; }
    if ('lang' in d) { setLang(d.lang); return; }
    if ('langtoggle' in d) { setLang(lang === 'ar' ? 'en' : 'ar'); return; }
    if ('reset' in d) { AIX.reset(); render(); toast(t('resetDone')); return; }
    if ('add' in d) { openSheet('__add'); return; }
    if ('close' in d) { closeSheet(); return; }
    const a = sheetId && sheetId !== '__add' ? acc(sheetId) : null;
    if (!a) return;
    if ('pw' in d) { await toggle(a); refreshSheet(); return; }
    if ('setv' in d) { await setAcc(a, JSON.parse(d.setv)); refreshSheet(); return; }
    if ('temp' in d) { await setAcc(a, { temp: a.temp + Number(d.temp), on: true }); refreshSheet(); return; }
    if ('mode' in d) { await setAcc(a, { mode: d.mode, on: true }); refreshSheet(); return; }
    if ('licon' in d) { await setAcc(a, { icon: d.licon }); refreshSheet(); toast(t('saved')); return; }
    if ('lroom' in d) { await setAcc(a, { room: d.lroom }); refreshSheet(); toast(t('saved')); return; }
    if ('lfav' in d) { await setAcc(a, { fav: !a.fav }); refreshSheet(); return; }
  });
  document.addEventListener('input', e => {
    const g = e.target.closest('[data-glevel]');
    if (g && gDraft) { const a = acc(g.dataset.glevel); if (a && GLV[a.kind]) { gDraft.lv[a.id] = Number(g.value); const o = g.parentNode.querySelector('.g-v'); if (o) o.textContent = GLV[a.kind].fmt(g.value); } return; }
    const b = e.target.closest('[data-bill]'); if (!b) return;
    try { localStorage.setItem(b.dataset.bill, b.value.trim()); } catch (x) {}
    applyBill();
  });
  document.addEventListener('change', async e => {
    const n = e.target.closest('[data-lname]'); if (!n || !sheetId) return;
    const a = acc(sheetId); const name = Object.assign({}, a.name); name[lang] = n.value.trim() || N(a.name);
    await setAcc(a, { name }); toast(t('saved'));
  });
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && !sheet.hidden) closeSheet(); });
  back.addEventListener('click', closeSheet);
  window.addEventListener('offline', () => render());
  window.addEventListener('online', () => { render(); toast(t('backOnline')); });

  AIX.init().then(() => {
    // deep links for previews: #tab-rooms, #tab-automation, #open-<accessoryId>
    const h = location.hash.slice(1);
    if (h.startsWith('tab-')) tab = h.slice(4);
    if (h === 'lang-en') lang = 'en';
    render();
    if (h.startsWith('open-')) openSheet(decodeURIComponent(h.slice(5)));
  });
})();
