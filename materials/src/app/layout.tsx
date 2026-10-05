import type { Metadata, Viewport } from "next";
import { Cinzel, Manrope } from "next/font/google";
import { NextIntlClientProvider } from "next-intl";
import { getLocale, getMessages, getTranslations } from "next-intl/server";
import { AreaDialog } from "@/components/AreaPicker";
import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import { StoreProvider } from "@/components/StoreProvider";
import { WhatsAppFloat } from "@/components/WhatsAppFloat";
import { SITE_URL } from "@/lib/config";
import { getAreas } from "@/lib/data";
import { dirFor } from "@/i18n/locales";
import "./globals.css";

const manrope = Manrope({ subsets: ["latin"], weight: ["300", "400", "500", "600"], variable: "--font-manrope", display: "swap" });
const cinzel = Cinzel({ subsets: ["latin"], weight: ["500"], variable: "--font-cinzel", display: "swap" });

export async function generateMetadata(): Promise<Metadata> {
  const t = await getTranslations("meta");
  return {
    metadataBase: new URL(SITE_URL),
    title: { default: t("title"), template: "%s | Jaguar Smart Materials" },
    description: t("description"),
    icons: { icon: "/materials/jaguar-mark.png" },
    openGraph: { siteName: "Jaguar Smart Construction", type: "website", images: ["/materials/jaguar-logo.png"] },
  };
}

export const viewport: Viewport = { themeColor: "#000000", width: "device-width", initialScale: 1, viewportFit: "cover" };

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getLocale();
  const [messages, areas] = await Promise.all([getMessages(), getAreas()]);
  return (
    <html lang={locale} dir={dirFor(locale)} className={`${manrope.variable} ${cinzel.variable}`}>
      <body>
        <NextIntlClientProvider locale={locale} messages={messages}>
          <StoreProvider areas={areas}>
            <SiteHeader />
            <main id="top">{children}</main>
            <SiteFooter />
            <WhatsAppFloat />
            <AreaDialog />
          </StoreProvider>
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
