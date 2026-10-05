import { STOCK_LABEL } from "@/lib/pricing";
import type { AreaPrice } from "@/lib/types";

const DOT: Record<AreaPrice["stock_status"], string> = {
  in_stock: "bg-up", low_stock: "bg-[#b26a00]", out_of_stock: "bg-down", on_order: "bg-muted",
};
export function StockBadge({ status }: { status: AreaPrice["stock_status"] }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-xs text-muted">
      <span className={`h-1.5 w-1.5 rounded-full ${DOT[status]}`} aria-hidden="true" />{STOCK_LABEL[status]}
    </span>
  );
}
