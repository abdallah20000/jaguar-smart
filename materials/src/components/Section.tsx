import Link from "next/link";

export function SectionHead({ title, href, linkLabel }: { title: string; href?: string; linkLabel?: string }) {
  return (
    <div className="mb-5 flex items-end justify-between gap-4">
      <h2 className="m-0 text-[clamp(22px,3vw,32px)] font-light tracking-[-0.02em]">{title}</h2>
      {href && <Link href={href} className="shrink-0 border-b border-current pb-0.5 text-sm font-medium no-underline">{linkLabel}</Link>}
    </div>
  );
}
