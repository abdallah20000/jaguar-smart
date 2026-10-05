export const egp = (n: number | null | undefined, digits = 0) =>
  n == null ? "—" : `EGP ${Number(n).toLocaleString("en-US", { minimumFractionDigits: digits, maximumFractionDigits: 2 })}`;

export const num = (n: number | null | undefined) =>
  n == null ? "—" : Number(n).toLocaleString("en-US", { maximumFractionDigits: 2 });

export const UNIT_LABEL: Record<string, string> = {
  ton: "ton", bag: "bag", m2: "m²", m3: "m³", piece: "piece", meter: "m", roll: "roll", liter: "L", kg: "kg",
};

export const pct = (n: number | null | undefined) =>
  n == null ? "—" : `${n > 0 ? "+" : ""}${Number(n).toFixed(2)}%`;

export const dateTime = (iso: string) =>
  new Date(iso).toLocaleString("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", timeZone: "Africa/Cairo" });
