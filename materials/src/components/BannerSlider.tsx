"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import type { Banner } from "@/lib/types";

export function BannerSlider({ banners }: { banners: Banner[] }) {
  const [i, setI] = useState(0);
  const paused = useRef(false);
  useEffect(() => {
    if (banners.length < 2) return;
    const id = setInterval(() => { if (!paused.current) setI((x) => (x + 1) % banners.length); }, 6000);
    return () => clearInterval(id);
  }, [banners.length]);
  if (!banners.length) return null;
  return (
    <section className="bg-black text-white" onMouseEnter={() => (paused.current = true)} onMouseLeave={() => (paused.current = false)}
      aria-roledescription="carousel">
      <div className="relative overflow-hidden">
        <div className="flex transition-transform duration-500 ease-out rtl:flex-row-reverse" style={{ transform: `translateX(${-i * 100}%)` }}>
          {banners.map((b, n) => (
            <div key={b.id} className="relative w-full shrink-0 px-5 py-12 sm:px-10 sm:py-16" aria-hidden={n !== i} role="group" aria-roledescription="slide">
              {b.image_url && (
                // eslint-disable-next-line @next/next/no-img-element -- admin-uploaded banner image
                <img src={b.image_url} alt="" className="absolute inset-0 h-full w-full object-cover" />
              )}
              <span className="absolute inset-0 bg-gradient-to-r from-black/90 via-black/60 to-black/20 rtl:bg-gradient-to-l" aria-hidden="true" />
              <div className="relative max-w-xl py-6 sm:py-10">
                <span className="mb-3 inline-block rounded-full border border-gold/60 px-3 py-1 text-xs font-semibold uppercase tracking-[.18em] text-gold">Jaguar Smart Materials</span>
                {(() => { const H = n === 0 ? "h1" : "h2"; return <H className="m-0 text-[clamp(32px,6.5vw,56px)] font-semibold leading-[1.08] tracking-[-0.03em]">{b.title}</H>; })()}
                {b.subtitle && <p className="mb-7 mt-4 max-w-[42ch] text-[17px] text-white/80">{b.subtitle}</p>}
                {b.link_url && b.cta_label && (
                  <Link href={b.link_url} className="btn btn-ink" tabIndex={n === i ? 0 : -1}>{b.cta_label} →</Link>
                )}
              </div>
            </div>
          ))}
        </div>
        {banners.length > 1 && (
          <div className="absolute bottom-5 start-5 flex gap-2 sm:start-10">
            {banners.map((b, n) => (
              <button key={b.id} type="button" onClick={() => setI(n)} aria-label={`Slide ${n + 1}`} aria-current={n === i}
                className={`h-1.5 rounded-full transition-all ${n === i ? "w-8 bg-gold" : "w-4 bg-white/40"}`} />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
