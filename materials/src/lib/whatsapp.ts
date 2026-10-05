import { WHATSAPP_NUMBER } from "./config";
import { track } from "./track";

export const waLink = (text: string) => `https://wa.me/${WHATSAPP_NUMBER}?text=${encodeURIComponent(text)}`;

export function openWhatsApp(text: string, source: string) {
  track("whatsapp_click", { source });
  window.open(waLink(text), "_blank", "noopener");
}
