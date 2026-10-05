// Mirrors public.mat_normalize_phone(): Egyptian mobiles only (010/011/012/015), stored as +20XXXXXXXXXX.
export function normalizeEgPhone(input: string): string | null {
  const n = input.replace(/\D/g, "");
  if (/^01[0125]\d{8}$/.test(n)) return "+2" + n;
  if (/^201[0125]\d{8}$/.test(n)) return "+" + n;
  if (/^00201[0125]\d{8}$/.test(n)) return "+" + n.slice(2);
  if (/^1[0125]\d{8}$/.test(n)) return "+20" + n;
  return null;
}
