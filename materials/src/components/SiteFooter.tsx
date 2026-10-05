import Link from "next/link";
import { getTranslations } from "next-intl/server";

export async function SiteFooter() {
  const t = await getTranslations("footer");
  const n = await getTranslations("nav");
  return (
    <footer className="site">
      <div className="wrap ftop">
        <div>
          {/* eslint-disable-next-line @next/next/no-img-element -- the original logo file, served as-is */}
          <img src="/materials/jaguar-logo.png" alt="Jaguar Smart Construction" width={128} height={120} loading="lazy" />
          <p style={{ maxWidth: "34ch", margin: 0 }}>{t("about")}</p>
        </div>
        <div>
          <h4>{t("materials")}</h4>
          <ul>
            <li><Link href="/prices">{t("prices")}</Link></li>
            <li><Link href="/category/steel-rebar">Steel & rebar</Link></li>
            <li><Link href="/category/cement">Cement</Link></li>
            <li><Link href="/quote">{t("rfq")}</Link></li>
          </ul>
        </div>
        <div>
          <h4>{t("company")}</h4>
          <ul>
            <li><a href="/#sectors">{n("sectors")}</a></li>
            <li><a href="/#process">{n("process")}</a></li>
            <li><a href="/#projects">{n("projects")}</a></li>
            <li><a href="/#contact">{n("contact")}</a></li>
          </ul>
        </div>
        <div>
          <h4>{t("contact")}</h4>
          <ul>
            <li><a href="tel:+201111126938" dir="ltr">+20 111 112 6938</a></li>
            <li><a href="mailto:info@jaguarsmart.com">info@jaguarsmart.com</a></li>
            <li>57 Hassan El-Sherif St.,<br />Nasr City, Cairo</li>
          </ul>
        </div>
      </div>
      <div className="wrap fbot">
        <span>{t("rights")}</span>
        <span>{t("register")} · <Link href="/credits">Image credits</Link></span>
      </div>
    </footer>
  );
}
