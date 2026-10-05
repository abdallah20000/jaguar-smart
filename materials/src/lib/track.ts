// Analytics hook (Meta Pixel + GA4 are wired in step 7). Safe to call before they load.
type Params = Record<string, unknown>;
declare global {
  interface Window { gtag?: (...a: unknown[]) => void; fbq?: (...a: unknown[]) => void }
}
const META: Record<string, string> = {
  view_item: "ViewContent", add_to_cart: "AddToCart", begin_checkout: "InitiateCheckout",
  purchase: "Purchase", generate_lead: "Lead", sign_up: "CompleteRegistration",
};
export function track(event: string, params: Params = {}) {
  if (typeof window === "undefined") return;
  window.gtag?.("event", event, params);
  if (META[event]) window.fbq?.("track", META[event], params);
  else window.fbq?.("trackCustom", event, params);
}
