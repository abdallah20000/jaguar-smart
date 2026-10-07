import type { Metadata } from "next";
import credits from "@/lib/image-credits.json";

export const metadata: Metadata = { title: "Image credits", robots: { index: false } };

export default function Credits() {
  return (
    <div className="wrap max-w-3xl py-12">
      <h1 className="m-0 text-3xl font-semibold">Image credits</h1>
      <p className="text-muted">Photos used in the materials store, with their authors and licenses.</p>
      <ul className="m-0 list-none p-0">
        {credits.map((c) => (
          <li key={c.file} className="border-t border-line py-3 text-sm">
            <a href={c.source ?? "#"} target="_blank" rel="noopener" className="font-medium">{c.title || c.file}</a>
            {c.creator ? ` by ${c.creator}` : ""} · {c.license_url
              ? <a href={c.license_url} target="_blank" rel="noopener">{c.license}</a> : c.license}
          </li>
        ))}
      </ul>
    </div>
  );
}
