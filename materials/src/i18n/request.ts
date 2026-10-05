import { getRequestConfig } from "next-intl/server";
import { DEFAULT_LOCALE } from "./locales";

// Static export: the locale is fixed at build time. Arabic is switched on later by adding
// locale-prefixed routes (/materials/ar/...) — components already read every string from messages.
export default getRequestConfig(async () => ({
  locale: DEFAULT_LOCALE,
  messages: (await import(`../../messages/${DEFAULT_LOCALE}.json`)).default,
  timeZone: "Africa/Cairo",
}));
