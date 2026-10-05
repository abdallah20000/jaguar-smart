export const LOCALES = ["en", "ar"] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = "en";
export const dirFor = (locale: string) => (locale === "ar" ? "rtl" : "ltr");
