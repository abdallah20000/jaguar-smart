const P: Record<string, string> = {
  steel: "M4 7h16M4 12h16M4 17h16M7 5v14M17 5v14",
  cement: "M7 3h10l2 5v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V8zM5 8h14M9 13h6",
  bricks: "M3 6h18v12H3zM3 10h18M3 14h18M9 6v4M15 10v4M9 14v4",
  sand: "M3 19h18M5 19l4-8 3 4 2-3 5 7M9 7a1 1 0 1 0 0-.1",
  tiles: "M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z",
  paint: "M4 4h12v5H4zM16 6h3v5h-7v3M11 14h2v7h-2z",
  plumbing: "M4 8h7a3 3 0 0 1 3 3v9M14 14h6M4 5v6M20 11v6",
  electrical: "M13 2 5 13h6l-1 9 8-11h-6z",
  gypsum: "M3 5h18v14H3zM9 5v14M15 5v14",
  insulation: "M3 18c3-6 6-6 9 0s6 6 9 0M3 12c3-6 6-6 9 0s6 6 9 0M3 6h18",
};
export function CategoryIcon({ name, className = "h-7 w-7" }: { name: string | null; className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={P[name ?? ""] ?? P.tiles} />
    </svg>
  );
}
