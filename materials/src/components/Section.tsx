import Link from "next/link";

export function SectionHead({ title, href, linkLabel }: { title: string; href?: string; linkLabel?: string }) {
  return (
    <div className="mb-5 flex items-end justify-between gap-4">
      <div><span className="mb-2 block h-1 w-10 rounded-full bg-gold" aria-hidden="true" /><h2 className="m-0 text-[clamp(22px,3vw,32px)] font-semibold tracking-[-0.02em]">{title}</h2></div>
      {href && <Link href={href} className="shrink-0 text-sm font-semibold text-gold-dark no-underline hover:underline">{linkLabel}</Link>}
    </div>
  );
}
