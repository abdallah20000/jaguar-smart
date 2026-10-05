export function Sparkline({ values, width = 96, height = 28, label }: { values: number[]; width?: number; height?: number; label?: string }) {
  if (values.length < 2) return <span className="text-muted">—</span>;
  const min = Math.min(...values), max = Math.max(...values), span = max - min || 1;
  const pts = values.map((v, i) => `${(i / (values.length - 1)) * width},${height - 2 - ((v - min) / span) * (height - 4)}`).join(" ");
  const up = values[values.length - 1] >= values[0];
  const last = pts.split(" ").pop()!.split(",");
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} role="img" aria-label={label} className="block">
      <polyline points={pts} fill="none" stroke={up ? "var(--color-up)" : "var(--color-down)"} strokeWidth="1.5" strokeLinejoin="round" />
      <circle cx={last[0]} cy={last[1]} r="2" fill={up ? "var(--color-up)" : "var(--color-down)"} />
    </svg>
  );
}
