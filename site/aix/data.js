// Demo home used until the Tuya backend is connected.
// Each device keeps the Tuya data-point codes it will use for real (see `dp` notes).
window.AIX_DEMO = {
  home: { name: { ar: "بيت التجمع", en: "New Cairo Villa" } },
  floors: [
    { id: "g", name: { ar: "الدور الأرضي", en: "Ground floor" } },
    { id: "f1", name: { ar: "الدور الأول", en: "First floor" } },
    { id: "out", name: { ar: "برّه", en: "Outdoor" } }
  ],
  rooms: [
    { id: "living", floor: "g", name: { ar: "الريسبشن", en: "Living room" } },
    { id: "kitchen", floor: "g", name: { ar: "المطبخ", en: "Kitchen" } },
    { id: "entrance", floor: "g", name: { ar: "المدخل", en: "Entrance" } },
    { id: "master", floor: "f1", name: { ar: "أوضة النوم الرئيسية", en: "Master bedroom" } },
    { id: "kids", floor: "f1", name: { ar: "أوضة الأولاد", en: "Kids room" } },
    { id: "garden", floor: "out", name: { ar: "الجنينة", en: "Garden" } }
  ],
  devices: [
    // light: dp switch_led, bright_value_v2 (10-1000)
    { id: "d1", type: "light", room: "living", fav: true, name: { ar: "النجفة", en: "Chandelier" }, on: true, bright: 80 },
    // Wall switch with 4 lines (dp switch_1..switch_4). Like Akubela, every line is its own device in AIX:
    // its own name, icon, room and favourite. The customer never sees "4-gang switch".
    { id: "d2", type: "switch4", room: "living", name: { ar: "مفتاح الريسبشن", en: "Living wall switch" },
      gangs: [
        { code: "switch_1", on: true,  icon: "spot", fav: true, name: { ar: "سبوتات الريسبشن", en: "Living spots" } },
        { code: "switch_2", on: false, icon: "strip", fav: true, name: { ar: "إضاءة مخفية", en: "Cove light" } },
        { code: "switch_3", on: false, icon: "bulb", room: "entrance", name: { ar: "نور المدخل", en: "Entrance light" } },
        { code: "switch_4", on: true,  icon: "fan", name: { ar: "مروحة السقف", en: "Ceiling fan" } }
      ] },
    // AC (IR / thermostat): dp switch, temp_set, mode, fan_speed_enum
    { id: "d3", type: "ac", room: "living", fav: true, name: { ar: "تكييف الريسبشن", en: "Living AC" }, on: true, temp: 23, mode: "cool", current: 26 },
    // curtain: dp control (open/close/stop), percent_control 0-100
    { id: "d4", type: "curtain", room: "living", fav: true, name: { ar: "الستارة", en: "Main curtain" }, pos: 100 },
    { id: "d5", type: "light", room: "kitchen", name: { ar: "إضاءة المطبخ", en: "Kitchen pendant" }, on: false, bright: 100 },
    // water leak sensor: dp watersensor_state (normal/alarm), battery_percentage
    { id: "d6", type: "leak", room: "kitchen", name: { ar: "حساس التسريب", en: "Leak sensor" }, alarm: false, battery: 86 },
    // smart lock: dp lock_motor_state / unlock (read-only via cloud in v1)
    { id: "d7", type: "lock", room: "entrance", fav: true, name: { ar: "الباب الرئيسي", en: "Front door" }, locked: true, battery: 72 },
    // door contact: dp doorcontact_state
    { id: "d8", type: "contact", room: "entrance", name: { ar: "حساس الباب", en: "Door sensor" }, open: false, battery: 91 },
    { id: "d9", type: "light", room: "master", name: { ar: "أباجورة السرير", en: "Bedside lamp" }, on: false, bright: 40 },
    { id: "d10", type: "ac", room: "master", name: { ar: "تكييف النوم", en: "Bedroom AC" }, on: false, temp: 25, mode: "cool", current: 27 },
    { id: "d11", type: "curtain", room: "master", name: { ar: "ستارة بلاك أوت", en: "Blackout curtain" }, pos: 0 },
    { id: "d12", type: "switch4", room: "kids", name: { ar: "مفتاح الأولاد", en: "Kids wall switch" },
      gangs: [
        { code: "switch_1", on: false, icon: "bulb", name: { ar: "النور", en: "Main light" } },
        { code: "switch_2", on: true,  icon: "star", name: { ar: "نور السقف", en: "Star ceiling" } },
        { code: "switch_3", on: false, icon: "lamp", name: { ar: "مكتب", en: "Desk" } },
        { code: "switch_4", on: false, icon: "fan", name: { ar: "شفاط", en: "Exhaust" } }
      ] },
    // motion sensor: dp pir (pir/none)
    { id: "d13", type: "motion", room: "garden", name: { ar: "حساس الحركة", en: "Motion sensor" }, motion: false, battery: 64 },
    { id: "d14", type: "light", room: "garden", name: { ar: "إضاءة الجنينة", en: "Garden lights" }, on: false, bright: 100 },
    // smart plug: dp switch_1, cur_power
    { id: "d15", type: "plug", room: "kitchen", name: { ar: "الغلاية", en: "Kettle" }, on: false, power: 0 }
  ],
  scenes: [
    { id: "s1", icon: "sun", name: { ar: "صباح الخير", en: "Good morning" },
      actions: [["d4", { pos: 100 }], ["d11", { pos: 100 }], ["d5", { on: true }], ["d10", { on: false }]] },
    { id: "s2", icon: "out", name: { ar: "خروج", en: "Leaving" },
      actions: [["d1", { on: false }], ["d2", { all: false }], ["d3", { on: false }], ["d5", { on: false }], ["d9", { on: false }], ["d10", { on: false }], ["d12", { all: false }], ["d14", { on: false }], ["d15", { on: false }]] },
    // Coming home: entrance + living lights, living AC to 24, curtain half open.
    { id: "s5", icon: "home", name: { ar: "رجوع", en: "Coming home" },
      actions: [["d2", { gang: ["switch_3", true] }], ["d2", { gang: ["switch_1", true] }], ["d1", { on: true, bright: 70 }], ["d3", { on: true, temp: 24 }], ["d4", { pos: 50 }]] },
    { id: "s3", icon: "film", name: { ar: "فيلم", en: "Movie night" },
      actions: [["d1", { on: true, bright: 20 }], ["d2", { gang: ["switch_2", true] }], ["d2", { gang: ["switch_1", false] }], ["d4", { pos: 0 }], ["d3", { on: true, temp: 22 }]] },
    { id: "s4", icon: "moon", name: { ar: "نوم", en: "Bedtime" },
      actions: [["d1", { on: false }], ["d2", { all: false }], ["d11", { pos: 0 }], ["d10", { on: true, temp: 24 }], ["d14", { on: true }]] }
  ],
  automations: [
    { id: "a1", on: true, name: { ar: "الجنينة تنور مع المغرب", en: "Garden lights at sunset" }, desc: { ar: "كل يوم · وقت الغروب", en: "Every day · at sunset" } },
    { id: "a2", on: true, name: { ar: "تنبيه لو فيه تسريب مية", en: "Alert on water leak" }, desc: { ar: "حساس المطبخ ← إشعار للعيلة", en: "Kitchen sensor → notify family" } },
    { id: "a3", on: false, name: { ar: "نور المدخل مع فتح الباب", en: "Entrance light when door opens" }, desc: { ar: "بعد المغرب بس", en: "After sunset only" } }
  ],
  members: [
    { name: "Abdallah", role: { ar: "مالك البيت", en: "Owner" } },
    { name: "Family member", role: { ar: "فرد من العيلة", en: "Member" } }
  ]
};
