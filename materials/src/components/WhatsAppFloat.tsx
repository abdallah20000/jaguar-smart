"use client";

import { useTranslations } from "next-intl";
import { openWhatsApp } from "@/lib/whatsapp";
import { useStore } from "./StoreProvider";

export function WhatsAppFloat() {
  const t = useTranslations("store");
  const { area } = useStore();
  return (
    <button type="button" className="wa" aria-label={t("whatsapp")}
      onClick={() => openWhatsApp(`${t("waHello")}\n${t("deliverTo")}: ${area.name}`, "float")}>
      <svg viewBox="0 0 32 32" fill="#1c1a17" aria-hidden="true"><path d="M16 3a13 13 0 0 0-11.2 19.6L3 29l6.6-1.7A13 13 0 1 0 16 3zm0 23.7a10.7 10.7 0 0 1-5.5-1.5l-.4-.2-3.9 1 1-3.8-.3-.4A10.7 10.7 0 1 1 16 26.7zm5.9-8c-.3-.2-1.9-1-2.2-1-.3-.1-.5-.2-.7.2l-1 1.2c-.2.2-.4.3-.7.1a8.8 8.8 0 0 1-4.4-3.8c-.3-.6.3-.5 1-1.7.1-.2 0-.4 0-.6l-1-2.4c-.3-.6-.5-.5-.7-.5h-.6a1.2 1.2 0 0 0-.9.4 3.7 3.7 0 0 0-1.1 2.7 6.5 6.5 0 0 0 1.3 3.4 14.8 14.8 0 0 0 5.7 5c2.1.9 2.9 1 4 .8.6-.1 1.9-.8 2.2-1.5.3-.8.3-1.4.2-1.5l-.6-.3z" /></svg>
    </button>
  );
}
