"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { useTranslations } from "next-intl";
import { useStore } from "./StoreProvider";

// Same header as jaguarsmart.com; links to the main page's sections, plus Materials.
export function SiteHeader() {
  const t = useTranslations("nav");
  const [open, setOpen] = useState(false);
  const { cart } = useStore();
  const path = usePathname();
  const items = cart.length;
  const main = [
    ["/#solutions", t("solutions")], ["/#sectors", t("sectors")], ["/#process", t("process")], ["/#projects", t("projects")],
  ] as const;
  return (
    <>
      <div className="util">
        <div className="wrap">
          <a href="tel:+201111126938" dir="ltr">+20 111 112 6938</a>
          <a href="mailto:info@jaguarsmart.com" className="hide-sm">info@jaguarsmart.com</a>
          <span className="hide-sm sp">Nasr City, Cairo</span>
        </div>
      </div>
      <header className="site">
        <div className="wrap">
          <a href="/" className="brand" aria-label={t("home")}>
            {/* eslint-disable-next-line @next/next/no-img-element -- the original logo file, served as-is */}
            <img src="/materials/jaguar-mark.png" alt="" width={63} height={44} />
            <span className="wm"><b>JAGUAR</b><small>SMART CONSTRUCTION</small></span>
          </a>
          <nav className={`main${open ? " open" : ""}`} id="nav" onClick={() => setOpen(false)}>
            {main.map(([href, label]) => <a key={href} href={href}>{label}</a>)}
            <Link href="/" aria-current={path === "/" ? "page" : undefined}>{t("materials")}</Link>
            <a href="/#contact">{t("contact")}</a>
          </nav>
          <Link href="/cart" className="icon-btn" aria-label={`${t("cart")} (${items})`}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h2l2.4 11.2a1 1 0 0 0 1 .8h9.2a1 1 0 0 0 1-.8L20 8H6.2" /><circle cx="9" cy="20" r="1.4" /><circle cx="17" cy="20" r="1.4" /></svg>
            {items > 0 && <span className="count">{items}</span>}
          </Link>
          <a className="btn btn-white" href="/#contact">{t("book")}</a>
          <button className="menu-btn" type="button" aria-expanded={open} aria-controls="nav" aria-label={t("menu")} onClick={() => setOpen(!open)}>
            <span /><span /><span />
          </button>
        </div>
      </header>
    </>
  );
}
